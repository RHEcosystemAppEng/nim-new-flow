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
- [ ] Add NIM models ConfigMap to odh-model-controller kustomize manifests
- [ ] Create metadata generation script (reference: `nim_metadata.sh` in this repo)
- [ ] Add Makefile target for developers to regenerate ConfigMap safely
- [ ] Document release process (see below)
- [ ] Create ServingRuntime Template as static resource
- [ ] Include Template in kustomization manifests

**Release Process:**
1. NIM team checks if NVIDIA catalog has new/updated models
2. Run metadata generation script locally
3. Submit PR with updated ConfigMap to odh-model-controller
4. PR is reviewed, merged, and included in the next release

> **Note:** This is a manual PR-based workflow, not automated CI. CI automation may be considered in the future after the process is validated with QE.

**New Files:**
- `scripts/generate_nim_metadata.sh` (based on the reference script in this repo)
- `config/nim/nvidia-nim-models-data.yaml` (generated ConfigMap, committed to repo)
- `config/runtimes/nim-http-template.yaml` (alongside existing runtime templates)

### EU Regulation Handling (Build-Time)

**Approach:** Run `detect-eu` script from an EU location to identify restricted models, then run `generate` which adds `euRestricted: true` to flagged models. Dashboard displays warning tooltip for restricted models.

**Tasks:**
- [x] Investigate whether models can be identified as EU-restricted at build time
- [x] Modify metadata generation script to mark restricted models
- [x] Document the approach for EU model restrictions

See [EU Regulation Investigation](04_NIM_EU_Regulation_Investigation.md) for details.

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

### Air-Gap Testing

**Jira:** [NVPE-415](https://issues.redhat.com/browse/NVPE-415)

Validate the solution in an air-gapped environment and document setup instructions. See Jira for acceptance criteria.

---

## Future Enhancements (Out of Scope)

See [Future Enhancements](05_NIM_Future_Enhancements.md) for features enabled by this redesign (key rotation, dual-protocol, enhanced air-gap).
