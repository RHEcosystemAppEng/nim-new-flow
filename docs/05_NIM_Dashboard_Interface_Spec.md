# NIM Integration - Dashboard Interface Specification

## Overview

This document specifies the interface contracts and requirements for the Dashboard team to implement the new NIM integration flow. With this redesign, the Dashboard becomes the primary orchestrator for NIM deployments, eliminating the need for backend controller involvement.

---

## Input Resources

### 1. NIM Model ConfigMap

The backend will ship a ConfigMap containing all NIM model metadata. The Dashboard reads this ConfigMap to populate the model selection dropdown.

**Location:** `<main-namespace>/nim-model-metadata` (e.g., `opendatahub/nim-model-metadata` or `redhat-ods-applications/nim-model-metadata`)

**Schema:**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nim-model-metadata
  namespace: redhat-ods-applications
  labels:
    app.kubernetes.io/part-of: nim-integration
data:
  models.json: |
    {
      "schemaVersion": "1.0.0",
      "generatedAt": "2026-02-05T12:00:00Z",
      "models": [
        {
          "id": "nvidia/llama-3.1-8b-instruct",
          "name": "Llama 3.1 8B Instruct",
          "description": "Meta's Llama 3.1 8B instruction-tuned model",
          "containerImage": "nvcr.io/nim/meta/llama-3.1-8b-instruct:1.1.2",
          "tags": ["1.1.2", "1.1.1", "1.1.0"],
          "latestTag": "1.1.2",
          "minGPUMemoryGB": 16,
          "recommendedGPUMemoryGB": 24,
          "supportedGPUs": ["A100", "H100", "L40S"],
          "euRestricted": false
        },
        {
          "id": "nvidia/nemo-megatron-gpt-20b",
          "name": "NeMo Megatron GPT 20B",
          "description": "NVIDIA's NeMo Megatron GPT model",
          "containerImage": "nvcr.io/nim/nvidia/nemo-megatron-gpt-20b:1.0.0",
          "tags": ["1.0.0"],
          "latestTag": "1.0.0",
          "minGPUMemoryGB": 48,
          "recommendedGPUMemoryGB": 80,
          "supportedGPUs": ["A100", "H100"],
          "euRestricted": true
        }
      ]
    }
```

**Key Fields:**
| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Unique model identifier (used for API calls) |
| `name` | string | Human-readable display name |
| `containerImage` | string | Full container image path with latest tag |
| `tags` | array | Available version tags |
| `latestTag` | string | Recommended/default tag |
| `minGPUMemoryGB` | number | Minimum GPU memory required |
| `euRestricted` | boolean | If true, model is restricted in EU regions |

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

**Location:** `<main-namespace>/nim-serving-runtime-template`

**Example:**
```yaml
apiVersion: template.openshift.io/v1
kind: Template
metadata:
  name: nim-serving-runtime-template
  namespace: redhat-ods-applications
  labels:
    app.kubernetes.io/part-of: nim-integration
objects:
  - apiVersion: serving.kserve.io/v1alpha1
    kind: ServingRuntime
    metadata:
      name: nim-runtime-${MODEL_NAME}
      labels:
        opendatahub.io/dashboard: "true"
    spec:
      supportedModelFormats:
        - name: nim
          autoSelect: true
      containers:
        - name: kserve-container
          image: ${CONTAINER_IMAGE}
          ports:
            - containerPort: 8000
              protocol: TCP
          env:
            - name: NIM_CACHE_PATH
              value: /mnt/models/cache
            - name: NGC_API_KEY
              valueFrom:
                secretKeyRef:
                  name: ${API_SECRET_NAME}
                  key: api_key
          volumeMounts:
            - name: nim-cache
              mountPath: /mnt/models/cache
      volumes:
        - name: nim-cache
          persistentVolumeClaim:
            claimName: ${PVC_NAME}
parameters:
  - name: MODEL_NAME
    required: true
  - name: CONTAINER_IMAGE
    required: true
  - name: API_SECRET_NAME
    required: true
  - name: PVC_NAME
    required: true
```

---

## NVIDIA API Endpoints

### Key Validation Endpoint

The Dashboard should validate the user's API key directly with NVIDIA.

**Endpoint:** `https://api.ngc.nvidia.com/v2/org/nim/team/meta/repos/llama-3.1-8b-instruct`

**Headers:**
```
Authorization: Bearer <api_key>
Content-Type: application/json
```

**Expected Responses:**
| Status | Meaning |
|--------|---------|
| 200 | Key is valid |
| 401 | Key is invalid |
| 403 | Key valid but lacks permissions |
| 451 | Unavailable for legal reasons (EU restriction) |

**Notes:**
- Any model endpoint can be used for validation; we just need to confirm the key works
- The 451 response is used to detect EU-restricted models

---

## Dashboard Responsibilities

### Wizard Flow

When a user deploys a NIM model through the Wizard:

1. **Collect API Key**
   - Display secure input for user's NVIDIA API key
   - Store temporarily in memory (not persisted until deployment)

2. **Validate Key (if enabled)**
   ```
   If OdhDashboardConfig.nimConfig.disableKeyValidation == false:
     Call NVIDIA validation endpoint with user's key
     If 401/403: Show error, do not proceed
     If 200: Proceed to next step
   ```

3. **Display Model Selection**
   - Read ConfigMap (default or custom per OdhDashboardConfig)
   - Parse models.json
   - Filter out `euRestricted: true` models if in EU (see EU Detection below)
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
     name: nim-api-key-${DEPLOYMENT_NAME}
     namespace: ${USER_PROJECT}
   type: Opaque
   data:
     api_key: <base64-encoded-api-key>
   ```

   **5.2 Pull Secret (Image Pull)**
   ```yaml
   apiVersion: v1
   kind: Secret
   metadata:
     name: nim-pull-secret-${DEPLOYMENT_NAME}
     namespace: ${USER_PROJECT}
   type: kubernetes.io/dockerconfigjson
   data:
     .dockerconfigjson: <base64-encoded-docker-config>
   ```
   
   Docker config format:
   ```json
   {
     "auths": {
       "nvcr.io": {
         "username": "$oauthtoken",
         "password": "<api_key>",
         "auth": "<base64(username:password)>"
       }
     }
   }
   ```

   **5.3 PVC**
   ```yaml
   apiVersion: v1
   kind: PersistentVolumeClaim
   metadata:
     name: nim-cache-${DEPLOYMENT_NAME}
     namespace: ${USER_PROJECT}
   spec:
     accessModes:
       - ReadWriteOnce
     resources:
       requests:
         storage: ${USER_REQUESTED_SIZE}  # e.g., "50Gi"
   ```

   **5.4 ServingRuntime**
   - Process the Template with parameters
   - Create ServingRuntime in user's project

   **5.5 InferenceService**
   ```yaml
   apiVersion: serving.kserve.io/v1beta1
   kind: InferenceService
   metadata:
     name: ${DEPLOYMENT_NAME}
     namespace: ${USER_PROJECT}
   spec:
     predictor:
       model:
         modelFormat:
           name: nim
         runtime: nim-runtime-${MODEL_NAME}
         storageUri: "pvc://${PVC_NAME}/cache"
   ```

---

## EU Region Handling

### Detection Approaches

The Dashboard needs to determine if it should filter EU-restricted models. Options:

**Option A: Cluster Configuration (Recommended)**
- Add field to OdhDashboardConfig: `nimConfig.region: "EU"` or `"US"` etc.
- Admin sets this during installation
- Simple, explicit, reliable

**Option B: Runtime Detection**
- Dashboard makes API call to determine region
- Could use cloud provider metadata or geolocation service
- More complex, may have edge cases

**Option C: Probe NVIDIA API**
- At Wizard load, probe a known EU-restricted model
- If 451, assume EU and filter
- Adds latency, not ideal for UX

### Filtering Logic

```
When populating model dropdown:
  For each model in ConfigMap:
    If model.euRestricted == true AND cluster is in EU:
      Skip this model
    Else:
      Add to dropdown
```

---

## Error Handling

### API Key Validation Errors

| Error | User Message |
|-------|--------------|
| 401 Unauthorized | "The API key is invalid. Please check and try again." |
| 403 Forbidden | "This API key does not have permission to access NIM models." |
| Network Error | "Unable to validate API key. Check network connectivity." |

### ConfigMap Errors

| Error | Behavior |
|-------|----------|
| ConfigMap not found | Show error, disable NIM in Wizard |
| Invalid JSON | Show error, disable NIM in Wizard |
| Schema version mismatch | Log warning, attempt parsing with fallback |

### Deployment Errors

- If any resource creation fails, rollback previously created resources
- Display specific error with affected resource

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

5. **EU Filtering**
   - Verify restricted models are hidden in EU clusters

6. **Rollback on Failure**
   - Verify partial deployments are cleaned up

---

## Migration Considerations

### Handling Existing Deployments

- Existing NIM deployments (from old flow) will continue to work
- No migration needed for running InferenceServices
- Old Account CRs will become orphaned but are harmless

### Cleanup Recommendations

Admins may want to clean up old resources:
- Old Account CRs in main namespace
- Old ConfigMaps created by controller
- Old prototype secrets in main namespace

---

## Questions for Dashboard Team

1. What's the preferred approach for EU region detection?
2. Should we support multiple API keys per project?
3. Do we need to support updating/rotating API keys for existing deployments?
4. What's the UX for model version upgrades?
