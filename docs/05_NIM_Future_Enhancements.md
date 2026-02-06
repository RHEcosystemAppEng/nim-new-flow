# NIM Future Enhancements

## Overview

The NIM integration redesign enables several future enhancements that are not part of the initial implementation. This document captures these opportunities for future planning.

---

## 1. API Key Rotation

### Current Limitation

With the existing architecture, API keys are scattered across multiple namespaces (copied from the main namespace to each user project). This makes key rotation extremely difficult - there's no central management or tracking of where keys are used.

### Enabled by Redesign

With per-project key management in the new architecture:
- Each project has its own API key stored locally
- Keys are not shared between projects
- Clear ownership and lifecycle per deployment

### Proposed Implementation

1. **Dashboard Key Management UI**
   - Update key for a specific deployment
   - Validate new key before applying

2. **Key Update Flow**
   - User provides new API key
   - Dashboard validates against NVIDIA API
   - Dashboard updates the Opaque Secret and Pull Secret in the project
   - Pod restart triggers new key usage

3. **Considerations**
   - Should key update trigger automatic pod restart?
   - How to handle validation failures during update?
   - If the container image is already pulled and exists on the cluster, should the new pod force a fresh pull?

---

## 2. Dual-Protocol Support (HTTP/gRPC)

### Current State

The current ServingRuntime template only supports one protocol configuration. Users cannot choose between HTTP and gRPC serving.

### Enabled by Redesign

With build-time template shipping:
- Multiple templates can be included in the product
- Templates are static and well-tested
- No runtime generation complexity

### Proposed Implementation

1. **Add gRPC ServingRuntime Template**
   - `nvidia-nim-runtime-http` already ships with the initial redesign
   - Add `nvidia-nim-runtime-grpc` for gRPC protocol

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

Air-gap support requires manual configuration and custom ConfigMaps. No tooling exists to simplify the process.

### Enabled by Redesign

With externalized metadata and configuration:
- `disableKeyValidation` flag for offline environments
- Custom ConfigMap override mechanism

### Proposed Implementation

1. **Air-Gap Preparation**
   - Customer provides a list of required models
   - Script to mirror images to internal registry (based on that list)
   - Script to pre-load models into PVCs
   - Script to generate custom ConfigMap

2. **Documentation**
   - Step-by-step air-gap setup guide
   - Troubleshooting common issues
   - Upgrade procedures for air-gap environments

---

## Priority Assessment

| Enhancement | Value | Complexity | Suggested Priority |
|-------------|-------|------------|-------------------|
| Enhanced Air-Gap | High | High | P1 - Next iteration |
| API Key Rotation | High | Medium | P2 - Follow-up |
| Dual-Protocol Support | Medium | Low | P2 - Follow-up |

---

## Next Steps

1. Gather feedback on priorities from stakeholders
2. Create Jira epics for P1 items after current redesign completes
3. Include in roadmap planning for next quarter
