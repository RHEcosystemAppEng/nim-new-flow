# NIM Integration - Dashboard Interface Specification

**Jira:** [NVPE-397](https://issues.redhat.com/browse/NVPE-397) (implementation), [NVPE-387](https://issues.redhat.com/browse/NVPE-387) (investigation - completed)

## Overview

This document specifies the interface contracts and requirements for the NIM integration in the Dashboard. With this redesign, the Dashboard becomes the primary orchestrator for NIM deployments, eliminating the need for backend controller involvement.

---

## Input Resources

### 1. NIM Model ConfigMap

The backend ships a ConfigMap containing NIM model metadata. The Dashboard reads this ConfigMap to populate the model selection dropdown.

**Location:** `<main-namespace>/nvidia-nim-models-data` (e.g., `redhat-ods-applications/nvidia-nim-models-data`)

**Schema (based on existing):**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nvidia-nim-models-data
  namespace: redhat-ods-applications
data:
  # Each key is a model name, value is JSON
  meta/llama3-8b-instruct: |
    {
      "name": "meta/llama3-8b-instruct",
      "displayName": "Llama 3 8B Instruct",
      "shortDescription": "Meta's Llama 3 8B instruction-tuned model",
      "namespace": "nim/meta",
      "tags": ["1.0.3", "1.0.2", "1.0.1"],
      "latestTag": "1.0.3",
      "updatedDate": "2026-02-05T12:00:00Z",
      "euRestricted": false
    }
  nvidia/nemo-megatron-gpt-20b: |
    {
      "name": "nvidia/nemo-megatron-gpt-20b",
      "displayName": "NeMo Megatron GPT 20B",
      "shortDescription": "NVIDIA's NeMo Megatron GPT model",
      "namespace": "nim/nvidia",
      "tags": ["1.0.0"],
      "latestTag": "1.0.0",
      "updatedDate": "2026-02-05T12:00:00Z",
      "euRestricted": false
    }
```

**Model JSON Fields:**
| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Model identifier (used as ConfigMap key) |
| `displayName` | string | Human-readable display name |
| `shortDescription` | string | Brief model description |
| `namespace` | string | NGC namespace (e.g., `nim/meta`) |
| `tags` | array | Available version tags |
| `latestTag` | string | Recommended/default tag |
| `updatedDate` | string | Last update timestamp |
| `euRestricted` | boolean | `true` if model is not available in EU due to regulations |

> **Note:** Container image is derived from namespace + name + tag: `nvcr.io/{namespace}/{name}:{tag}`. In disconnected environments, admins configure an [ImageTagMirrorSet](https://docs.redhat.com/en/documentation/openshift_container_platform/4.21/html/config_apis/imagetagmirrorset-config-openshift-io-v1) to transparently redirect `nvcr.io` to their internal registry.

---

### 2. OdhDashboardConfig

The OdhDashboardConfig CRD will have a new `nimConfig` section:

**Schema Addition:**
```yaml
apiVersion: opendatahub.io/v1alpha
kind: OdhDashboardConfig
metadata:
  name: odh-dashboard-config
spec:
  # ... existing fields ...
  
  nimConfig:
    # Optional: Override the default shipped ConfigMap
    customConfigMap:
      name: "custom-nim-models"
      namespace: "redhat-ods-applications"
    
    # Disconnected (air-gapped) environment settings
    disconnected:
      # Skip API key collection and validation in the Wizard
      disableKeyCollection: true
```

**Behavior:**
- If `customConfigMap` is specified, use it instead of the default shipped ConfigMap
- If `disconnected.disableKeyCollection` is true, skip API key collection and validation entirely (no Opaque Secret or Pull Secret created)

---

### 3. ServingRuntime Template

The backend ships a Template CR containing the ServingRuntime definition.

**Location:** `<main-namespace>/nvidia-nim-runtime-http`

**Actual ServingRuntime (from `odh-model-controller`):**
```yaml
apiVersion: serving.kserve.io/v1alpha1
kind: ServingRuntime
metadata:
  name: nvidia-nim-runtime-http
  annotations:
    opendatahub.io/recommended-accelerators: '["nvidia.com/gpu"]'
    openshift.io/display-name: NVIDIA NIM
    opendatahub.io/nim-runtime: "true"
  labels:
    opendatahub.io/dashboard: "true"
spec:
  multiModel: false
  protocolVersions:
    - grpc-v2
    - v2
  supportedModelFormats:
    - name: replace-me  # Replaced at deployment time
  containers:
    - name: kserve-container
      image: ""  # Set at deployment time
      ports:
        - containerPort: 8000
          protocol: TCP
      env:
        - name: NIM_CACHE_PATH
          value: /mnt/models/cache
      resources:
        limits:
          cpu: "2"
          memory: 8Gi
          nvidia.com/gpu: "2"
        requests:
          cpu: "1"
          memory: 4Gi
          nvidia.com/gpu: "2"
      volumeMounts:
        - name: shm
          mountPath: /dev/shm
        - name: nim-pvc
          mountPath: /mnt/models/cache
        - name: nim-workspace
          mountPath: /opt/nim/workspace
        - name: nim-cache
          mountPath: /.cache
  volumes:
    - name: nim-pvc
      persistentVolumeClaim:
        claimName: nim-pvc
    - name: nim-workspace
      emptyDir: {}
    - name: nim-cache
      emptyDir: {}
    - name: shm
      emptyDir:
        medium: Memory
```

> **Important:** The ServingRuntime **template** ships without secrets — no `NGC_API_KEY` env var, no `imagePullSecrets`. When the Dashboard creates the ServingRuntime in the user's namespace, it adds the secret references alongside the other customizations (image, model format, PVC name). The resulting ServingRuntime in the namespace looks the same as it does today — secrets on the container env and `imagePullSecrets` at spec level. The InferenceService is unchanged.

---

## NVIDIA API Endpoints

### Key Validation Endpoint

The Dashboard should validate the user's API key directly with NVIDIA.

**Endpoint:** `POST https://api.ngc.nvidia.com/v3/keys/get-caller-info`

**Headers:**
```
Content-Type: application/x-www-form-urlencoded
Authorization: Bearer <api_key>
```

**Body:**
```
credentials=<api_key>
```

**Response:**
- `200` = Key validated successfully
- Any other status = Key not validated

---

## Dashboard Responsibilities

### Wizard Flow

When a user deploys a NIM model through the Wizard:

1. **Collect API Key** (skipped if `disconnected.disableKeyCollection` is true)
   - Display secure input for user's NVIDIA API key (**personal keys only**, legacy keys are not supported)
   - Store temporarily in memory (not persisted until deployment)

2. **Validate Key** (skipped if `disconnected.disableKeyCollection` is true)
   - Call NVIDIA validation endpoint (see [ADR Open Question #4](01_ADR_NIM_Integration_Redesign.md#open-questions) for implementation options — backend proxy vs. webhook)
   - If validation fails, show error and do not proceed
   - If validation succeeds, proceed to next step

3. **Display Model Selection**
   - Read ConfigMap (default or custom per OdhDashboardConfig)
   - Parse model entries (each key is a model name, value is JSON)
   - Handle EU-restricted models (see [EU Region Handling](#eu-region-handling) below)
   - Populate dropdown with models

4. **Collect User Input**
   - Model selection (from dropdown)
   - Version/tag selection (from model's tags array)
   - PVC size
   - GPU/resource requirements

5. **Create Resources (in user's project namespace)**

   > **Disconnected mode:** When `disconnected.disableKeyCollection` is true, steps 5.1 and 5.2 are skipped entirely. No secrets are created. Image pulling relies on the cluster's [global pull secret](https://docs.redhat.com/en/documentation/openshift_container_platform/4.21/html/postinstallation_configuration/post-install-image-config) and optional [ImageTagMirrorSet](https://docs.redhat.com/en/documentation/openshift_container_platform/4.21/html/config_apis/imagetagmirrorset-config-openshift-io-v1) configuration.

   **5.1 Opaque Secret (API Key)**
   ```yaml
   apiVersion: v1
   kind: Secret
   metadata:
     name: nvidia-nim-secrets-${DEPLOYMENT_NAME}
     namespace: ${USER_PROJECT}
     labels:
       opendatahub.io/managed: "true"
   type: Opaque
   data:
     api_key: <base64-encoded-api-key>
   ```

   **5.2 Pull Secret (Image Pull)**
   ```yaml
   apiVersion: v1
   kind: Secret
   metadata:
     name: nvidia-nim-image-pull-${DEPLOYMENT_NAME}
     namespace: ${USER_PROJECT}
     labels:
       opendatahub.io/managed: "true"
   type: kubernetes.io/dockerconfigjson
   data:
     .dockerconfigjson: <base64-encoded-docker-config>
   ```
   
   Docker config format (matches current account controller):
   ```json
   {
     "auths": {
       "nvcr.io": {
         "username": "$oauthtoken",
         "password": "<api_key>"
       }
     }
   }
   ```

   **5.3 PVC**
   
   > **Note:** PVC creation remains unchanged from current Dashboard implementation. The Dashboard already handles PVC creation for model deployments.

   **5.4 ServingRuntime**
   - Process the Template with parameters (image, model format, PVC name)
   - Add deployment-specific secret references: `NGC_API_KEY` env var via `secretKeyRef` pointing to `nvidia-nim-secrets-{deployment-name}`, and `imagePullSecrets` referencing `nvidia-nim-image-pull-{deployment-name}`
   - Create ServingRuntime in user's project
   
   > The resulting ServingRuntime looks the same as the current integration — secrets live on the ServingRuntime, not the InferenceService. The only difference is that the **template** ships without secrets and the Dashboard adds them during deployment.
   >
   > **Disconnected mode:** When `disconnected.disableKeyCollection` is true, the Dashboard skips adding `NGC_API_KEY` and `imagePullSecrets` to the ServingRuntime. Image pulling relies on the cluster's global pull secret.

   **5.5 InferenceService**
   
   > **Note:** InferenceService creation remains unchanged from current Dashboard implementation. The Dashboard already handles InferenceService creation for model deployments. No secrets are placed on the InferenceService.

---

## EU Region Handling

EU-restricted models are marked with `euRestricted: true` in the ConfigMap. This is determined at build time by running the `detect-eu` script from an EU location.

**Dashboard behavior:** When a user selects an EU-restricted model (`euRestricted: true`), show a warning tooltip (e.g., "This model may not be available in the EU due to regulatory restrictions"). Users can still proceed with deployment.

See [EU Regulation Investigation](04_NIM_EU_Regulation_Investigation.md) for details.

---

## Error Handling

### API Key Validation Errors

- `200` = Validation successful
- Any other response = Validation failed, show generic error message

---

## Testing Scenarios

### Required Test Cases

1. **Happy Path**
   - Valid key, standard model, successful deployment

2. **Invalid Key**
   - Verify validation catches invalid key before resource creation

3. **Custom ConfigMap**
   - Verify OdhDashboardConfig override works correctly

4. **Disconnected (Air-Gap) Mode**
   - Verify deployment works when `disconnected.disableKeyCollection` is true
   - Verify key collection UI is hidden
   - Verify no secrets are created in user namespace
   - Verify ImageTagMirrorSet-based registry mirroring works

5. **EU Filtering** (if applicable)
   - Verify restricted models are filtered appropriately

6. **Rollback on Failure**
   - Verify partial deployments are cleaned up

