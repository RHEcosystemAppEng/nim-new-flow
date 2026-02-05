# NIM Integration Redesign - Stakeholder Brief

## Executive Summary

We are proposing a significant redesign of the NVIDIA NIM integration in OpenDataHub and Red Hat OpenShift AI. This redesign addresses critical user experience and security concerns while simplifying the codebase and enabling future enhancements.

**Key Outcomes:**
- Eliminate 2-minute enablement delay
- Resolve security risk from shared API keys
- Enable seamless Wizard integration
- Reduce maintenance burden

---

## Problem Statement

### Current Architecture Issues

The existing NIM integration has three major pain points:

1. **High Latency (UX Impact)**
   - Enablement requires 1-2 minutes of async metadata fetching
   - Each model requires a separate API call for tag resolution
   - This delay is incompatible with the new deployment Wizard

2. **Security Risk**
   - Admin's API key is copied from the main namespace to every user project
   - All users share the same credentials
   - No isolation between projects

3. **Architectural Misfit**
   - Current backend-driven model requires async controller reconciliation
   - New Wizard expects synchronous, immediate operations
   - Moving enablement to per-project would multiply the latency problem

---

## Proposed Solution

### Build-Time Metadata + Per-Project Secrets

The solution shifts metadata fetching to build time and moves secret management to the project level:

| Aspect | Current | Proposed |
|--------|---------|----------|
| Metadata source | Runtime API calls | Build-time shipped ConfigMap |
| Enablement time | 1-2 minutes | Instant |
| API key scope | Cluster (shared) | Per-project (isolated) |
| Secret location | Copied from admin namespace | Created directly in project |
| Key validation | Backend controller | Dashboard (direct to NVIDIA) |

### Architecture Changes

1. **Remove Backend**
   - Delete Account CRD and Controller from odh-model-controller
   - Remove NIM component from DataScienceCluster CRD (under KServe)
   - Eliminate async reconciliation loop

2. **Build-Time Metadata**
   - Fetch model metadata during CI/CD using Red Hat API key
   - Ship immutable ConfigMap with product
   - Include ServingRuntime Template as static resource

3. **Dashboard Enhancements**
   - Validate user's API key directly against NVIDIA
   - Create all secrets within user's project namespace
   - Support custom ConfigMap for restricted environments

---

## Benefits

### For Users
- **Instant enablement** - No more waiting for metadata scraping
- **Better security** - Their API key stays in their project
- **Seamless Wizard experience** - Synchronous operations

### For Admins
- **Simplified configuration** - Remove backend enablement flag
- **Air-gap support** - Custom ConfigMap for restricted networks
- **Clearer security model** - No cross-namespace secret copying

### For Engineering
- **Reduced code complexity** - Remove entire controller
- **Lower maintenance burden** - No runtime API dependencies
- **Enable future features** - Key rotation, dual-protocol support (see [Future Enhancements](07_NIM_Future_Enhancements.md))

---

## Coordination

This work involves Backend, Model Serving, Dashboard, and Documentation teams. NVIDIA coordination for build-time API key usage is complete.

See [Coordination Matrix](04_NIM_Coordination_Matrix.md) for full details on team responsibilities, dependencies, risks, and contacts.

**Key External Dependency:** [EU Regulation Handling](06_NIM_EU_Regulation_Investigation.md) - Some models may be restricted in EU regions.

---

## Open Questions

1. **EU Regulation**
   - How do we reliably determine which models are EU-restricted?
   - Should Dashboard detect geographic location or rely on config?

2. **Upgrade Path**
   - What happens to existing Account CRs after upgrade?
   - Do we need automatic cleanup or manual steps?

3. **Application Screen**
   - Should we keep the application screen enablement toggle?
   - If yes, what does it control without API key collection?

---

## Related Documents

- [ADR: NIM Integration Redesign](01_ADR_NIM_Integration_Redesign.md)
- [Implementation Plan](03_NIM_Redesign_Implementation_Plan.md)
- [Dashboard Interface Specification](05_NIM_Dashboard_Interface_Spec.md)
- [Coordination Matrix](04_NIM_Coordination_Matrix.md)

---

## Next Steps

1. Share ADR with stakeholders
2. ~~Coordinate with NVIDIA on build-time API key usage~~ Done
3. Assign team members and create Jira tasks
4. [Begin implementation](03_NIM_Redesign_Implementation_Plan.md)
5. Coordinate with Dashboard team on Wizard integration
