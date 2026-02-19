# NIM Future Enhancements

## Overview

The NIM integration redesign enables several future enhancements that are not part of the initial implementation. This document captures these opportunities for future planning.

---

## 1. API Key Rotation

### Current Limitation

With the existing architecture, API keys are scattered across multiple namespaces (copied from the main namespace to each user project). This makes key rotation extremely difficult - there's no central management or tracking of where keys are used.

### Enabled by Redesign

With per-deployment key management in the new architecture:
- Each deployment has its own API key (`nvidia-nim-secrets-{deployment-name}`)
- Keys are not shared between deployments, even within the same project
- Clear ownership and lifecycle per deployment

### Prerequisites

Existing deployments must use per-deployment secret naming (`nvidia-nim-secrets-{deployment-name}`, `nvidia-nim-image-pull-{deployment-name}`). See [Deployment Migration Guide](07_NIM_Deployment_Migration_Guide.md) for migrating older deployments.

### Proposed Implementation

1. **Dashboard Key Management UI**
   - Update key for a specific deployment
   - Validate new key before applying

2. **Key Update Flow**
   - User provides new API key
   - Dashboard validates against NVIDIA API
   - Dashboard updates the deployment's Opaque Secret and Pull Secret
   - Pod restart triggers new key usage

3. **Considerations**
   - Should key update trigger automatic pod restart?
   - How to handle validation failures during update?
   - If the container image is already pulled and exists on the cluster, should the new pod force a fresh pull?

---

## 2. Dual-Protocol Support (HTTP/gRPC)

### Current State

The current Template CR contains a single ServingRuntime configured for one protocol. Users cannot choose between HTTP and gRPC serving.

### Enabled by Redesign

With build-time Template CR shipping:
- Multiple Template CRs can be included in the product (one per protocol)
- Templates are static and well-tested
- No runtime generation complexity

### Proposed Implementation

1. **Add gRPC Template CR**
   - `nvidia-nim-http-template` already ships with the initial redesign (HTTP)
   - Add `nvidia-nim-grpc-template` for gRPC protocol

2. **Wizard Protocol Selection**
   - Add protocol dropdown to deployment wizard
   - Show appropriate template based on selection
   - Document use cases for each protocol

3. **Considerations**
   - Default protocol selection?
   - Can users switch protocol after deployment?
   - Performance implications documentation?

---

## 3. Enhanced Air-Gap Support

### Current State

Basic disconnected support is provided via `OdhDashboardConfig.spec.nimConfig` (see [Dashboard Interface Spec](03_NIM_Dashboard_Interface_Spec.md)):
- `disconnected.disableKeyCollection: true` skips API key collection and validation
- `customConfigMap` allows admins to provide their own model metadata

### Proposed Implementation

1. **Air-Gap Preparation (Admin Prerequisites)**
   - **Mirror NIM images** to internal registry using `skopeo copy` or `oc mirror`
   - **Configure [ImageTagMirrorSet](https://docs.redhat.com/en/documentation/openshift_container_platform/4.21/html/config_apis/imagetagmirrorset-config-openshift-io-v1)** to redirect `nvcr.io` to the internal registry:
     ```yaml
     apiVersion: config.openshift.io/v1
     kind: ImageTagMirrorSet
     metadata:
       name: nim-registry-mirror
     spec:
       imageTagMirrors:
         - source: nvcr.io
           mirrors:
             - internal-registry.company.com
     ```
   - **Update the [global pull secret](https://docs.redhat.com/en/documentation/openshift_container_platform/4.21/html/postinstallation_configuration/post-install-image-config)** with internal registry credentials (if not already configured for the disconnected cluster)
   - **Set `disconnected` config** in OdhDashboardConfig:
     ```yaml
     nimConfig:
       disconnected:
         disableKeyCollection: true
     ```
     > **Note:** No `registry` override is needed in the Dashboard config. The ImageTagMirrorSet transparently redirects `nvcr.io` requests to the mirror at the cluster level.

2. **Automation Scripts** (future)
   - Script to mirror NIM images to internal registry (based on a provided model list)
   - Script to pre-load models into PVCs
   - Script to generate custom ConfigMap from mirrored registry

3. **Documentation**
   - Step-by-step air-gap setup guide
   - Troubleshooting common issues
   - Upgrade procedures for air-gap environments

---

## 4. CI Automation for Metadata Generation

### Current State

The NIM models ConfigMap is generated manually by maintainers prior to each release. This allows the process to be validated with QE and enables generation of model diff reports for testing.

### Future Implementation

Once the manual process is stable:
1. **CI Integration**
   - Add GitHub Action or Tekton task to run metadata generation script
   - Trigger on release branches or via manual dispatch
   - Auto-commit updated ConfigMap or create PR for review

2. **QE Reporting**
   - Generate diff report showing added/removed/updated models
   - Attach report to release artifacts for QE validation

3. **Considerations**
   - Secure storage of Red Hat API key in CI secrets
   - Failure handling if NVIDIA API is unavailable
   - Review gate vs auto-merge for ConfigMap updates

---

## Priority Assessment

| Enhancement | Value | Complexity | Suggested Priority |
|-------------|-------|------------|-------------------|
| Enhanced Air-Gap | High | High | P1 - Next iteration |
| API Key Rotation | High | Medium | P2 - Follow-up |
| Dual-Protocol Support | Medium | Low | P2 - Follow-up |
| CI Metadata Automation | Medium | Low | P3 - Post-stabilization |

---

## Next Steps

1. Gather feedback on priorities from stakeholders
2. Create Jira epics for P1 items after current redesign completes
3. Include in roadmap planning for next quarter
