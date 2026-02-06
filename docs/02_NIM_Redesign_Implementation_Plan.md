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
- [ ] Remove Account controller and all supporting code (API validation, metadata fetching, ConfigMap/Template/Pull Secret reconciliation)
- [ ] Remove related tests
- [ ] Update documentation

**Files to Modify/Remove:**
- Account CRD definition
- Account controller and reconciliation logic
- NIM utility functions
- Related tests

### Add Build-Time Metadata Generation

**Tasks:**
- [ ] Create CI/CD script to fetch NIM model metadata and generate immutable ConfigMap (using Red Hat-managed API key)
- [ ] Include ConfigMap in kustomization manifests
- [ ] Create ServingRuntime Template as static resource
- [ ] Include Template in kustomization manifests

**New Files:**
- `scripts/generate_nim_metadata.sh` (can be adapted to another language if needed)
- `config/runtimes/nim-template.yaml` (alongside existing runtime templates)
- ConfigMap YAML (generated during build, location TBD)

### EU Regulation Handling (Build-Time) - TBD

> **Note:** It is not yet confirmed whether EU-restricted models can be identified at build time. The NVIDIA API does not expose structured region data. Further investigation is needed. See [EU Regulation Investigation](04_NIM_EU_Regulation_Investigation.md).

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

### Cleanup Obsolete NIM Resources

**Tasks:**
- [ ] Add cleanup logic to the operator's existing upgrade package for obsolete NIM resources (Account CRs, old ConfigMaps, Templates, Pull Secrets)
- [ ] Document what gets cleaned up automatically

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

> **Note:** Depends on whether EU-restricted models can be identified. See [EU Regulation Investigation](04_NIM_EU_Regulation_Investigation.md).

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

## Future Enhancements (Out of Scope)

See [Future Enhancements](05_NIM_Future_Enhancements.md) for features enabled by this redesign (key rotation, dual-protocol, enhanced air-gap).
