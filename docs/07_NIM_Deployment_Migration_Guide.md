# NIM Integration - Per-Deployment Migration Guide

## Overview

Existing NIM deployments continue to work after the platform upgrade — no action is required. However, future Dashboard features such as **API key rotation** and **per-deployment key management** require the new naming convention for secrets.

This guide provides optional steps for admins who want to migrate a specific existing deployment to the new design. A script (`migrate_nim_deployment.sh`) automates these steps.

---

## Why Migrate?

Existing deployments use **shared secrets** — all NIM deployments in a namespace reference the same `nvidia-nim-secrets` (Opaque) and `ngc-secret` (Pull Secret). These are the admin's API key, copied from the main namespace during the deployment process.

The new design uses **per-deployment secrets**: `nim-api-key-{deployment-name}` and `nim-image-pull-{deployment-name}`. Each deployment gets its own key, enabling:

- **API key rotation** per deployment without affecting others
- **Per-deployment key management** in the Dashboard UI
- **Personal API keys** instead of shared admin keys

---

## Before and After

| | Before (shared) | After (per-deployment) |
|--|-----------------|----------------------|
| Opaque Secret | `nvidia-nim-secrets` | `nim-api-key-{deployment-name}` |
| Pull Secret | `ngc-secret` | `nim-image-pull-{deployment-name}` |
| ServingRuntime | References shared names | References deployment-specific names |
| InferenceService | No changes | No changes |
| PVC | No changes | No changes |

---

## Migration Script

The `migrate_nim_deployment.sh` script automates the migration steps below.

```bash
# Migrate with a new personal API key
./migrate_nim_deployment.sh -n <namespace> -d <deployment-name> -k <api-key>

# Migrate reusing the existing key (must be a personal key)
./migrate_nim_deployment.sh -n <namespace> -d <deployment-name> --reuse-key

# Dry-run (preview without making changes)
./migrate_nim_deployment.sh -n <namespace> -d <deployment-name> --reuse-key --dry-run

# Clean up shared secrets (after all deployments in the namespace are migrated)
./migrate_nim_deployment.sh -n <namespace> --cleanup
```

---

## Manual Migration Steps

### Step 1: Create Deployment-Specific Secrets

The user should provide their **personal** API key (`nvapi-...`). If not available, the existing key from the shared secret can be reused — but only if it is a personal key (`nvapi-...`). Legacy (org-level) keys are not supported by the new design.

```bash
NAMESPACE="<user-namespace>"
DEPLOYMENT="<deployment-name>"
API_KEY="nvapi-..."

# Opaque Secret
oc create secret generic "nim-api-key-${DEPLOYMENT}" \
  --namespace="${NAMESPACE}" \
  --from-literal=NGC_API_KEY="${API_KEY}"

# Pull Secret
oc create secret docker-registry "nim-image-pull-${DEPLOYMENT}" \
  --namespace="${NAMESPACE}" \
  --docker-server=nvcr.io \
  --docker-username='$oauthtoken' \
  --docker-password="${API_KEY}"
```

### Step 2: Update ServingRuntime

Patch the ServingRuntime to reference the new secrets:

```bash
# Verify NGC_API_KEY env index (typically 1)
oc get servingruntime "${DEPLOYMENT}" -n "${NAMESPACE}" \
  -o jsonpath='{.spec.containers[0].env}'

# Patch (adjust env index if needed)
oc patch servingruntime "${DEPLOYMENT}" \
  --namespace="${NAMESPACE}" \
  --type='json' \
  -p='[
    {"op": "replace", "path": "/spec/containers/0/env/1/valueFrom/secretKeyRef/name", "value": "nim-api-key-'"${DEPLOYMENT}"'"},
    {"op": "replace", "path": "/spec/imagePullSecrets/0/name", "value": "nim-image-pull-'"${DEPLOYMENT}"'"}
  ]'
```

### Step 3: Restart the Deployment

Patching the ServingRuntime does not automatically restart the running pods. A rollout restart is needed to pick up the new secret references.

> **Warning: Restarting the deployment requires temporarily double the resources.** The default rolling update strategy will not terminate the old pod until the new one is running. For NIM deployments this means the cluster must have enough GPU, CPU, and memory to run two instances simultaneously. If resources are not available, the new pod will remain `Pending` and the old pod will continue serving — but the rollout will block until resources free up. Plan accordingly and consider migrating during low-usage windows.

```bash
oc rollout restart deployment/"${DEPLOYMENT}-predictor" -n "${NAMESPACE}"
```

### Step 4: Verify

```bash
# Confirm new secret references on the ServingRuntime
oc get servingruntime "${DEPLOYMENT}" -n "${NAMESPACE}" \
  -o jsonpath='{.spec.containers[0].env[?(@.name=="NGC_API_KEY")].valueFrom.secretKeyRef.name}'

oc get servingruntime "${DEPLOYMENT}" -n "${NAMESPACE}" \
  -o jsonpath='{.spec.imagePullSecrets[0].name}'

# Confirm new pod is running
oc get pods -n "${NAMESPACE}" -l serving.kserve.io/inferenceservice="${DEPLOYMENT}" -w
```

### Step 5: Clean Up Shared Secrets (Optional)

If **all** NIM deployments in the namespace have been migrated, the old shared secrets can be deleted:

```bash
# Verify no deployments still reference the old secrets
oc get servingruntime -n "${NAMESPACE}" -o json | \
  jq -r '.items[] | select(.spec.imagePullSecrets[]?.name == "ngc-secret") | .metadata.name'

# If empty, safe to delete
oc delete secret nvidia-nim-secrets -n "${NAMESPACE}"
oc delete secret ngc-secret -n "${NAMESPACE}"
```
