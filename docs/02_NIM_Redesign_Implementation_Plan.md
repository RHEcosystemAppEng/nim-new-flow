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

## Resource Names

| Resource | Name | Namespace |
|----------|------|-----------|
| ConfigMap (model metadata) | `nvidia-nim-models-data` | Main namespace |
| ServingRuntime Template | `nvidia-nim-runtime-http` | Main namespace |
| Opaque Secret (per deployment) | `nvidia-nim-secrets` | User project |
| Pull Secret (per deployment) | `nvidia-nim-image-pull` | User project |

---

## Model Serving Changes (odh-model-controller)

### Remove Account CRD and Controller

**Jira:** [NVPE-410](https://issues.redhat.com/browse/NVPE-410)

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

**Jira:** [NVPE-411](https://issues.redhat.com/browse/NVPE-411) (metadata script), [NVPE-412](https://issues.redhat.com/browse/NVPE-412) (ServingRuntime template)

**Tasks:**
- [ ] Create CI/CD script to fetch NIM model metadata and generate immutable ConfigMap (using Red Hat-managed API key)
- [ ] Include ConfigMap in kustomization manifests
- [ ] Create ServingRuntime Template as static resource
- [ ] Include Template in kustomization manifests

**New Files:**
- `scripts/generate_nim_metadata.sh` (can be based on the reference script in this repo, and adapted to another language if needed)
- `config/runtimes/nim-http-template.yaml` (alongside existing runtime templates)
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

**Jira:** [NVPE-413](https://issues.redhat.com/browse/NVPE-413)

**Tasks:**
- [ ] Remove NIM-specific enablement flag from DataScienceCluster CRD
- [ ] Update Kserve component configuration
- [ ] Update documentation

**Files to Modify:**
- CRD definition for DataScienceCluster
- Kserve component handling code
- Related tests

### Cleanup Obsolete NIM Resources

**Jira:** [NVPE-414](https://issues.redhat.com/browse/NVPE-414)

**Tasks:**
- [ ] Add cleanup logic to the operator's existing upgrade package for obsolete NIM resources (Account CRs, old ConfigMaps, Templates, Pull Secrets)
- [ ] Document what gets cleaned up automatically

---

## Dashboard Enhancements (odh-dashboard)

**Jira:** [NVPE-397](https://issues.redhat.com/browse/NVPE-397)

See [Dashboard Interface Specification](03_NIM_Dashboard_Interface_Spec.md) for detailed technical requirements and resource contracts.

---

## Testing and Validation

### Unit Tests

**Tasks:**
- [ ] Remove tests for removed Account controller
- [ ] Add tests for new ConfigMap loading logic

### Integration Tests

**Tasks:**
- [ ] Test end-to-end NIM deployment flow
- [ ] Test upgrade from current architecture to new architecture
- [ ] Verify cleanup of obsolete resources (Account CR, etc.)

---

## Future Enhancements (Out of Scope)

See [Future Enhancements](05_NIM_Future_Enhancements.md) for features enabled by this redesign (key rotation, dual-protocol, enhanced air-gap).
