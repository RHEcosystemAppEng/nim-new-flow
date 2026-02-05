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

## Model Serving Changes (odh-model-controller)

### Remove Account CRD and Controller

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
- Account CRD definition
- Account controller and reconciliation logic
- NIM utility functions
- Related tests

### Add Build-Time Metadata Generation

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

### EU Regulation Handling (Build-Time) - TBD

> **Note:** It is not yet confirmed whether EU-restricted models can be identified at build time. The NVIDIA API does not expose structured region data. Further investigation is needed. See [EU Regulation Investigation](06_NIM_EU_Regulation_Investigation.md).

**Tasks:**
- [ ] Investigate whether models can be identified as EU-restricted at build time
- [ ] If feasible, modify metadata generation script to mark restricted models
- [ ] Document the approach for EU model restrictions

---

## Backend Changes (opendatahub-operator)

### Remove NIM Component from DataScienceCluster

**Tasks:**
- [ ] Remove NIM-specific enablement flag from DataScienceCluster CRD
- [ ] Update Kserve component configuration
- [ ] Update documentation

**Files to Modify:**
- CRD definition for DataScienceCluster
- Kserve component handling code
- Related tests

### Include NIM Resources in Component Image

**Tasks:**
- [ ] Ensure NIM ConfigMap is deployed with component
- [ ] Ensure ServingRuntime Template is deployed with component
- [ ] Update kustomization to include NIM resources

---

## Dashboard Enhancements (odh-dashboard)

### OdhDashboardConfig CRD Updates

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

### Wizard Integration

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

### EU Regulation Handling (Runtime) - TBD

> **Note:** Depends on whether EU-restricted models can be identified. See [EU Regulation Investigation](06_NIM_EU_Regulation_Investigation.md).

**Tasks:**
- [ ] Determine how to detect if filtering is needed (cluster region, config flag, etc.)
- [ ] If models are marked, filter dropdown accordingly
- [ ] Display appropriate message for restricted models

### Application Screen Updates

**Tasks:**
- [ ] Keep application screen enablement requirement (optional)
- [ ] Remove API key collection from application screen
- [ ] Update status indicators

---

## Documentation and Air-Gap Support

### Admin Documentation

**Tasks:**
- [ ] Document how to create custom ConfigMap for restricted environments
- [ ] Document OdhDashboardConfig options
- [ ] Document air-gap deployment process

### User Documentation

**Tasks:**
- [ ] Update user guides for new Wizard flow
- [ ] Document API key requirements and validation

---

## Testing and Validation

### Unit Tests

**Tasks:**
- [ ] Update/remove tests for removed Account controller
- [ ] Add tests for new ConfigMap loading logic
- [ ] Add tests for OdhDashboardConfig handling

### Integration Tests

**Tasks:**
- [ ] Test end-to-end NIM deployment flow
- [ ] Test custom ConfigMap override
- [ ] Test air-gap mode (disabled validation)
- [ ] Test EU restriction filtering

### Upgrade Testing

**Tasks:**
- [ ] Test upgrade from current architecture to new architecture
- [ ] Verify cleanup of obsolete resources (Account CR, etc.)

---

## Coordination and Risks

See [Coordination Matrix](04_NIM_Coordination_Matrix.md) for:
- Cross-team dependencies and communication
- Risk register and mitigation strategies
- Contact list and Jira structure

---

## Migration/Upgrade Considerations

### Cleanup Required

When upgrading from the old architecture:
- Account CRs will become orphaned (no controller)
- Old ConfigMaps created by controller need cleanup
- Old Templates created by controller need cleanup
- Old Pull Secrets (prototypes) need cleanup

### Cleanup Implementation

The opendatahub-operator already has cleanup logic that runs during upgrades. We will extend this existing mechanism to handle NIM resource cleanup:

- [ ] Add cleanup logic to opendatahub-operator for obsolete NIM resources
- [ ] Document what gets cleaned up automatically vs. manually

---

## Future Enhancements (Out of Scope)

See [Future Enhancements](07_NIM_Future_Enhancements.md) for features enabled by this redesign (key rotation, dual-protocol, enhanced air-gap).
