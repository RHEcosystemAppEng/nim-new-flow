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

> **Note:** Container image is derived from namespace + name + tag: `nvcr.io/{namespace}/{name}:{tag}`. This may need to change to support air-gapped environments with mirrored registries - currently under investigation.

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
    
    # Toggle for key validation (for air-gap environments)
    # Set to 'true' to disable outbound validation calls
    disableKeyValidation: false
```

**Behavior:**
- If `customConfigMap` is specified, use it instead of the default shipped ConfigMap
- If `disableKeyValidation` is true, skip the NVIDIA API key validation step

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
        - name: NGC_API_KEY
          valueFrom:
            secretKeyRef:
              name: nvidia-nim-secrets
              key: NGC_API_KEY
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
  imagePullSecrets:
    - name: ngc-secret
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

> **Note:** The Template wraps this ServingRuntime. At deployment, the Dashboard processes the template and customizes fields like `image`, `supportedModelFormats`, secret names, and PVC name based on user input.

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

1. **Collect API Key**
   - Display secure input for user's NVIDIA API key (**personal keys only**, legacy keys are not supported)
   - Store temporarily in memory (not persisted until deployment)

2. **Validate Key (if enabled)**
   - If `OdhDashboardConfig.nimConfig.disableKeyValidation` is false, call NVIDIA validation endpoint
   - If validation fails, show error and do not proceed
   - If validation succeeds, proceed to next step

3. **Display Model Selection**
   - Read ConfigMap (default or custom per OdhDashboardConfig)
   - Parse model entries (each key is a model name, value is JSON)
   - Filter EU-restricted models if applicable (out of scope - see [EU Regulation Investigation](04_NIM_EU_Regulation_Investigation.md))
   - Populate dropdown with remaining models

4. **Collect User Input**
   - Model selection (from dropdown)
   - Version/tag selection (from model's tags array)
   - PVC size
   - GPU/resource requirements

5. **Create Resources (in user's project namespace)**

   **5.1 Opaque Secret (API Key)**
   ```yaml
   apiVersion: v1
   kind: Secret
   metadata:
     name: nvidia-nim-secrets
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
     name: nvidia-nim-image-pull
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
   - Process the Template with parameters
   - Create ServingRuntime in user's project

   **5.5 InferenceService**
   
   > **Note:** InferenceService creation remains unchanged from current Dashboard implementation. The Dashboard already handles InferenceService creation for model deployments.

---

## EU Region Handling

EU-restricted models are marked with `euRestricted: true` in the ConfigMap. This is determined at build time by running the `detect-eu` script from an EU location.

**Dashboard behavior:** When displaying a model with `euRestricted: true`, show a warning tooltip (e.g., "This model may not be available in the EU due to regulatory restrictions"). Do not block selection - let the user decide.

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

4. **Air-Gap Mode**
   - Verify deployment works when validation is disabled

5. **EU Filtering** (if applicable)
   - Verify restricted models are filtered appropriately

6. **Rollback on Failure**
   - Verify partial deployments are cleaned up

---

## Open Questions

1. What's the preferred approach for EU region detection?
