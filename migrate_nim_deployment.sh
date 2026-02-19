#!/bin/bash
#
# Migrate a NIM deployment from shared secrets to per-deployment secrets.
# See docs/07_NIM_Deployment_Migration_Guide.md for details.
#
# WARNING: This script restarts the deployment as a final step. The default
# rolling update strategy will NOT terminate the old pod until the new one is
# running, which requires temporarily DOUBLE the resources (GPU, CPU, memory).
# If resources are unavailable, the new pod stays Pending and the old pod
# continues serving. Plan accordingly — consider running during low-usage windows.
#
# Usage:
#   ./migrate_nim_deployment.sh -n <namespace> -d <deployment-name> -k <api-key>
#   ./migrate_nim_deployment.sh -n <namespace> -d <deployment-name> --reuse-key
#   ./migrate_nim_deployment.sh -n <namespace> --cleanup

set -euo pipefail

usage() {
  cat <<EOF
Usage:
  $0 -n NAMESPACE -d DEPLOYMENT -k API_KEY   Migrate using a new personal API key
  $0 -n NAMESPACE -d DEPLOYMENT --reuse-key  Migrate reusing the existing key from nvidia-nim-secrets
  $0 -n NAMESPACE --cleanup                  Delete shared secrets (after all deployments are migrated)

Options:
  -n, --namespace    Target namespace
  -d, --deployment   Deployment (ServingRuntime) name
  -k, --api-key      Personal NVIDIA API key (nvapi-...)
  --reuse-key        Reuse the existing key from the shared nvidia-nim-secrets secret
  --cleanup          Delete old shared secrets (nvidia-nim-secrets, ngc-secret)
  --dry-run          Print what would be done without making changes
  -h, --help         Show this help
EOF
  exit 1
}

NAMESPACE=""
DEPLOYMENT=""
API_KEY=""
REUSE_KEY=false
CLEANUP=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case $1 in
    -n|--namespace)  NAMESPACE="$2"; shift 2 ;;
    -d|--deployment) DEPLOYMENT="$2"; shift 2 ;;
    -k|--api-key)    API_KEY="$2"; shift 2 ;;
    --reuse-key)     REUSE_KEY=true; shift ;;
    --cleanup)       CLEANUP=true; shift ;;
    --dry-run)       DRY_RUN=true; shift ;;
    -h|--help)       usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

[[ -z "$NAMESPACE" ]] && { echo "Error: --namespace is required"; usage; }

run() {
  if $DRY_RUN; then
    echo "[dry-run] $*"
  else
    echo "+ $*"
    "$@"
  fi
}

# --- Cleanup mode ---
if $CLEANUP; then
  echo "=== Checking for remaining deployments using shared secrets in ${NAMESPACE} ==="
  remaining=$(oc get servingruntime -n "$NAMESPACE" -o json | \
    jq -r '.items[] | select(.spec.imagePullSecrets[]?.name == "ngc-secret") | .metadata.name' 2>/dev/null || true)

  if [[ -n "$remaining" ]]; then
    echo "Error: The following deployments still reference shared secrets:"
    echo "$remaining"
    echo "Migrate them first before running cleanup."
    exit 1
  fi

  echo "No deployments reference shared secrets. Deleting..."
  run oc delete secret nvidia-nim-secrets -n "$NAMESPACE" --ignore-not-found
  run oc delete secret ngc-secret -n "$NAMESPACE" --ignore-not-found
  echo "=== Cleanup complete ==="
  exit 0
fi

# --- Migration mode ---
[[ -z "$DEPLOYMENT" ]] && { echo "Error: --deployment is required"; usage; }

if $REUSE_KEY && [[ -n "$API_KEY" ]]; then
  echo "Error: Cannot use both --api-key and --reuse-key"
  exit 1
fi

if $REUSE_KEY; then
  echo "=== Extracting existing key from nvidia-nim-secrets ==="
  API_KEY=$(oc get secret nvidia-nim-secrets -n "$NAMESPACE" -o jsonpath='{.data.NGC_API_KEY}' | base64 -d)
  if [[ -z "$API_KEY" ]]; then
    echo "Error: Could not extract key from nvidia-nim-secrets in ${NAMESPACE}"
    exit 1
  fi
  if [[ ! "$API_KEY" == nvapi-* ]]; then
    echo "Error: Existing key is not a personal key (nvapi-...). Legacy keys are not supported."
    echo "Please provide a personal API key with --api-key instead."
    exit 1
  fi
  echo "Extracted personal key from shared secret."
fi

if [[ -z "$API_KEY" ]]; then
  echo "Error: --api-key or --reuse-key is required"
  usage
fi

if [[ ! "$API_KEY" == nvapi-* ]]; then
  echo "Error: API key must be a personal key starting with 'nvapi-'. Legacy keys are not supported."
  exit 1
fi

OPAQUE_SECRET="nim-api-key-${DEPLOYMENT}"
PULL_SECRET="nim-image-pull-${DEPLOYMENT}"

echo "=== Migrating deployment '${DEPLOYMENT}' in namespace '${NAMESPACE}' ==="
echo "  Opaque Secret: ${OPAQUE_SECRET}"
echo "  Pull Secret:   ${PULL_SECRET}"
echo ""

# Step 1: Verify ServingRuntime exists
echo "--- Step 1: Verify ServingRuntime ---"
if ! oc get servingruntime "$DEPLOYMENT" -n "$NAMESPACE" &>/dev/null; then
  echo "Error: ServingRuntime '${DEPLOYMENT}' not found in namespace '${NAMESPACE}'"
  exit 1
fi

# Find the env index for NGC_API_KEY
ENV_INDEX=$(oc get servingruntime "$DEPLOYMENT" -n "$NAMESPACE" -o json | \
  jq '.spec.containers[0].env | to_entries[] | select(.value.name == "NGC_API_KEY") | .key')

if [[ -z "$ENV_INDEX" ]]; then
  echo "Error: NGC_API_KEY env var not found in ServingRuntime '${DEPLOYMENT}'"
  exit 1
fi
echo "  NGC_API_KEY is at env index: ${ENV_INDEX}"

current_secret=$(oc get servingruntime "$DEPLOYMENT" -n "$NAMESPACE" -o json | \
  jq -r ".spec.containers[0].env[${ENV_INDEX}].valueFrom.secretKeyRef.name")
current_pull=$(oc get servingruntime "$DEPLOYMENT" -n "$NAMESPACE" -o json | \
  jq -r '.spec.imagePullSecrets[0].name')
echo "  Current opaque secret: ${current_secret}"
echo "  Current pull secret:   ${current_pull}"

if [[ "$current_secret" == "$OPAQUE_SECRET" && "$current_pull" == "$PULL_SECRET" ]]; then
  echo "ServingRuntime already references per-deployment secrets. Nothing to do."
  exit 0
fi
echo ""

# Step 2: Create deployment-specific secrets
echo "--- Step 2: Create deployment-specific secrets ---"
if oc get secret "$OPAQUE_SECRET" -n "$NAMESPACE" &>/dev/null; then
  echo "  Opaque secret '${OPAQUE_SECRET}' already exists, skipping."
else
  run oc create secret generic "$OPAQUE_SECRET" \
    --namespace="$NAMESPACE" \
    --from-literal=NGC_API_KEY="$API_KEY"
fi

if oc get secret "$PULL_SECRET" -n "$NAMESPACE" &>/dev/null; then
  echo "  Pull secret '${PULL_SECRET}' already exists, skipping."
else
  run oc create secret docker-registry "$PULL_SECRET" \
    --namespace="$NAMESPACE" \
    --docker-server=nvcr.io \
    --docker-username='$oauthtoken' \
    --docker-password="$API_KEY"
fi
echo ""

# Step 3: Patch ServingRuntime
echo "--- Step 3: Patch ServingRuntime ---"
run oc patch servingruntime "$DEPLOYMENT" \
  --namespace="$NAMESPACE" \
  --type='json' \
  -p='[
    {"op": "replace", "path": "/spec/containers/0/env/'"${ENV_INDEX}"'/valueFrom/secretKeyRef/name", "value": "'"${OPAQUE_SECRET}"'"},
    {"op": "replace", "path": "/spec/imagePullSecrets/0/name", "value": "'"${PULL_SECRET}"'"}
  ]'
echo ""

# Step 4: Restart deployment
echo "--- Step 4: Restart deployment ---"
echo "WARNING: Rolling restart requires double the resources (GPU, CPU, memory)."
echo "         The old pod will not terminate until the new one is running."
run oc rollout restart deployment/"${DEPLOYMENT}-predictor" -n "$NAMESPACE"
echo ""

# Step 5: Verify
if ! $DRY_RUN; then
  echo "--- Step 5: Verify ---"
  new_secret=$(oc get servingruntime "$DEPLOYMENT" -n "$NAMESPACE" -o json | \
    jq -r ".spec.containers[0].env[${ENV_INDEX}].valueFrom.secretKeyRef.name")
  new_pull=$(oc get servingruntime "$DEPLOYMENT" -n "$NAMESPACE" -o json | \
    jq -r '.spec.imagePullSecrets[0].name')
  echo "  Opaque secret: ${new_secret}"
  echo "  Pull secret:   ${new_pull}"

  if [[ "$new_secret" == "$OPAQUE_SECRET" && "$new_pull" == "$PULL_SECRET" ]]; then
    echo "  ✓ ServingRuntime updated successfully."
  else
    echo "  ✗ Unexpected secret references — check manually."
    exit 1
  fi

  echo ""
  echo "Waiting for new pod to start..."
  oc rollout status deployment/"${DEPLOYMENT}-predictor" -n "$NAMESPACE" --timeout=120s || {
    echo "Warning: Rollout did not complete within 120s. Check pod status:"
    echo "  oc get pods -n ${NAMESPACE} -l serving.kserve.io/inferenceservice=${DEPLOYMENT}"
  }
fi

echo ""
echo "=== Migration complete ==="
echo "To clean up shared secrets after all deployments are migrated:"
echo "  $0 -n ${NAMESPACE} --cleanup"
