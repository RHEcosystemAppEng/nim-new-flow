# NIM Integration Redesign - Stakeholder Brief

**Author:** Tomer Figenblat  
**Date:** February 2026  
**Related Jira:** NVPE-390

---

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

1. **Remove Backend Controller**
   - Delete Account CRD and Controller from odh-model-controller
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
- **Enable future features** - Key rotation, dual-protocol support

---

## Required Coordination

### Teams Involved

| Team | Responsibility | Key Contact |
|------|----------------|-------------|
| Backend (Kserve) | Account removal, metadata shipping | Tomer Figenblat |
| Operator | DataScienceCluster CRD changes | TBD |
| Dashboard | Wizard integration, OdhDashboardConfig | TBD |
| NVIDIA Partnership | API key for build-time | Approved |
| Documentation | User and admin guides | TBD |

### External Dependencies

1. **NVIDIA Approval** ✓
   - Need agreement for using Red Hat API key at build time
   - Key only used to fetch tags
   - Not exposed at runtime

2. **EU Regulation Handling**
   - Some models return 451 for EU regions
   - Need approach to identify and mark restricted models
   - Dashboard must filter based on region

---

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| NVIDIA API changes | Version ConfigMap schema, regular updates |
| Build-time key security | Secure CI/CD pipeline, limited scope |
| Upgrade complexity | Migration script, clear cleanup procedures |
| Air-gap deployments | Custom ConfigMap support, documentation |

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

- [ADR: NIM Integration Redesign](./ADR_%20NIM%20Integration%20Redesign.md)
- [Implementation Plan](./NIM_Redesign_Implementation_Plan.md)
- [Dashboard Interface Specification](./NIM_Dashboard_Interface_Spec.md) *(to be created)*

---

## Next Steps

1. Review and approve ADR with stakeholders
2. ~~Obtain NVIDIA approval for build-time API key usage~~ Done
3. Assign team members and create Jira tasks
4. Begin Phase 1 implementation (Backend removal)
5. Coordinate with Dashboard team on Wizard integration
