# NIM Integration Redesign - Implementation Plan

## Overview

This document outlines the implementation plan for redesigning the NVIDIA NIM integration in OpenDataHub (ODH) and Red Hat OpenShift AI (RHOAI). The redesign addresses three critical pain points: high latency, security concerns, and Wizard compatibility.

## Projects Involved

| Project | Repository | Role |
|---------|-----------|------|
| opendatahub-operator | https://github.com/opendatahub-io/opendatahub-operator | Main operator, deploys components via DataScienceCluster CRD |
| odh-model-controller | https://github.com/opendatahub-io/odh-model-controller | Model Serving code, currently hosts Account CRD/Controller |
| odh-dashboard | https://github.com/opendatahub-io/odh-dashboard | Frontend UI, hosts OdhDashboardConfig CRD |

---

## Phase 1: Model Serving Changes (odh-model-controller)

### 1.1 Remove Account CRD and Controller

**Tasks:**
- [ ] Remove Account CRD definition
- [ ] Remove Account controller reconciliation logic
- [ ] Remove all supporting code:
  - API key validation against NVIDIA endpoint
  - Model metadata fetching logic
  - Tags resolution per-model logic
  - ConfigMap reconciliation for model data
  - Template reconciliation for ServingRuntime
  - Pull Secret reconciliation
- [ ] Remove related status conditions handling
- [ ] Remove related tests
- [ ] Update documentation

**Files to Modify/Remove:**
- `api/v1beta1/account_types.go` (or similar)
- `controllers/account_controller.go`
- `config/crd/bases/` (Account CRD YAML)
- Related tests in `controllers/`

### 1.2 Add Build-Time Metadata Generation

**Tasks:**
- [ ] Create script to fetch NIM model metadata during CI/CD
- [ ] Configure Red Hat-managed API key for CI/CD (secret management)
- [ ] Generate immutable ConfigMap with model data
- [ ] Include ConfigMap in kustomization manifests
- [ ] Create ServingRuntime Template as static resource
- [ ] Include Template in kustomization manifests

**New Files:**
- `scripts/generate_nim_metadata.sh` (or Python equivalent)
- `config/nim/configmap.yaml` (generated during build)
- `config/nim/servingruntime-template.yaml`
- `config/nim/kustomization.yaml`

### 1.3 EU Regulation Handling (Build-Time)

**Tasks:**
- [ ] Investigate which models return 451 for EU
- [ ] Modify metadata generation script to:
  - Test each model endpoint from EU perspective
  - Mark models with `euRestricted: true` flag in ConfigMap
- [ ] Document the approach for EU model restrictions

---

## Phase 2: Backend Changes (opendatahub-operator)

### 2.1 Remove NIM Component from DataScienceCluster

**Tasks:**
- [ ] Remove NIM-specific enablement flag from DataScienceCluster CRD
- [ ] Update Kserve component configuration
- [ ] Update documentation

**Files to Modify:**
- CRD definition for DataScienceCluster
- Kserve component handling code
- Related tests

### 2.2 Include NIM Resources in Component Image

**Tasks:**
- [ ] Ensure NIM ConfigMap is deployed with component
- [ ] Ensure ServingRuntime Template is deployed with component
- [ ] Update kustomization to include NIM resources

---

## Phase 3: Dashboard Enhancements (odh-dashboard)

### 3.1 OdhDashboardConfig CRD Updates

**Tasks:**
- [ ] Add `nimConfig` section to OdhDashboardConfig spec:
  ```yaml
  nimConfig:
    customConfigMap:
      name: "custom-nim-models"
      namespace: "redhat-ods-applications"
    disableKeyValidation: false
  ```
- [ ] Implement logic to read custom ConfigMap when specified
- [ ] Implement toggle for key validation (for air-gap)

### 3.2 Wizard Integration

**Tasks:**
- [ ] Move API key collection from Application screen to Wizard
- [ ] Implement direct NVIDIA API key validation in Wizard
- [ ] Populate model dropdown from shipped ConfigMap
- [ ] Support custom ConfigMap from OdhDashboardConfig
- [ ] Create resources directly in user's project:
  - Opaque Secret (API key for model download)
  - Pull Secret (for container image pull)
  - PVC (based on user input)
  - ServingRuntime (from cluster-level template)
  - InferenceService (with model container image)

### 3.3 EU Regulation Handling (Runtime)

**Tasks:**
- [ ] Detect user's geographic location or cluster region
- [ ] Filter dropdown to exclude `euRestricted: true` models when in EU
- [ ] Display appropriate message for restricted models

### 3.4 Application Screen Updates

**Tasks:**
- [ ] Keep application screen enablement requirement (optional)
- [ ] Remove API key collection from application screen
- [ ] Update status indicators

---

## Phase 4: Documentation and Air-Gap Support

### 4.1 Admin Documentation

**Tasks:**
- [ ] Document how to create custom ConfigMap for restricted environments
- [ ] Document OdhDashboardConfig options
- [ ] Document air-gap deployment process

### 4.2 User Documentation

**Tasks:**
- [ ] Update user guides for new Wizard flow
- [ ] Document API key requirements and validation

---

## Phase 5: Testing and Validation

### 5.1 Unit Tests

**Tasks:**
- [ ] Update/remove tests for removed Account controller
- [ ] Add tests for new ConfigMap loading logic
- [ ] Add tests for OdhDashboardConfig handling

### 5.2 Integration Tests

**Tasks:**
- [ ] Test end-to-end NIM deployment flow
- [ ] Test custom ConfigMap override
- [ ] Test air-gap mode (disabled validation)
- [ ] Test EU restriction filtering

### 5.3 Upgrade Testing

**Tasks:**
- [ ] Test upgrade from current architecture to new architecture
- [ ] Verify cleanup of obsolete resources (Account CR, etc.)

---

## Dependencies and Coordination

### Cross-Team Dependencies

| Task | Team | Dependency |
|------|------|------------|
| Model Serving changes | Model Serving (you) | None |
| Backend changes | Backend | Phase 1 complete |
| Dashboard changes | Frontend team | Phases 1-2 complete |
| Documentation | Docs team | Phases 1-3 complete |

### External Dependencies

| Dependency | Owner | Notes |
|------------|-------|-------|
| Red Hat API key for CI/CD | NVIDIA partnership | Approved |
| EU regulation model list | NVIDIA | Need official list or testing approach |

---

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| NVIDIA API changes | High | Version the ConfigMap schema, monitor NVIDIA announcements |
| EU regulation complexity | Medium | Conservative approach - exclude uncertain models |
| Upgrade path issues | Medium | Thorough testing, cleanup scripts |
| Air-gap deployment complexity | Low | Clear documentation, custom ConfigMap support |

---

## Migration/Upgrade Considerations

### Cleanup Required

When upgrading from the old architecture:
- Account CRs will become orphaned (no controller)
- Old ConfigMaps created by controller need cleanup
- Old Templates created by controller need cleanup
- Old Pull Secrets (prototypes) need cleanup

### Migration Script Tasks

- [ ] Create migration script to clean up obsolete resources
- [ ] Document manual cleanup steps if needed

---

## Future Enhancements (Out of Scope)

The following items are enabled by this redesign but not part of the initial implementation. See [Future Enhancements](07_NIM_Future_Enhancements.md) for details.

1. **Dual ServingRuntime Templates** - Support for both HTTP and gRPC servings
2. **API Key Update Mechanism** - Per-project key management makes this feasible
3. **Enhanced Air-Gap Support** - Full offline deployment with custom registries

---

## Timeline Coordination Notes

This document intentionally does not include time estimates. Coordinate with stakeholders and teams to determine scheduling based on:
- Team availability
- Sprint planning
- Dependencies between phases
- Testing resource availability
