# NIM Redesign - Coordination Matrix

## Project Responsibilities

### odh-model-controller (Model Serving)
**Lead:** Tomer Figenblat

| Task | Description | Dependencies | Deliverable |
|------|-------------|--------------|-------------|
| Remove Account CRD | Delete CRD definition and related types | None | PR to odh-model-controller |
| Remove Account Controller | Delete controller logic and reconciliation | None | PR to odh-model-controller |
| Create metadata script | Script to fetch NIM models during CI/CD | NVIDIA API key | Script in repo |
| Generate ConfigMap | Create model metadata ConfigMap | Metadata script | ConfigMap YAML |
| Create ServingRuntime Template | Static template resource | None | Template YAML |
| Update Kustomization | Include NIM resources in component | ConfigMap, Template | Kustomization update |
| EU restriction marking | Mark restricted models in ConfigMap | EU investigation | ConfigMap update |

### opendatahub-operator (Backend)
**Lead:** TBD

| Task | Description | Dependencies | Deliverable |
|------|-------------|--------------|-------------|
| Remove NIM backend flag | Remove enablement flag from DSC | None | PR to operator |
| Include NIM resources | Deploy ConfigMap and Template with component | Backend complete | PR to operator |
| Update CRD docs | Document CRD changes | Flag removal | Documentation |

### odh-dashboard (Frontend)
**Lead:** TBD

| Task | Description | Dependencies | Deliverable |
|------|-------------|--------------|-------------|
| OdhDashboardConfig update | Add nimConfig section | None | CRD update |
| ConfigMap reading | Read shipped or custom ConfigMap | ConfigMap available | Frontend code |
| NVIDIA key validation | Direct API validation in Wizard | None | Frontend code |
| Wizard integration | Full deployment flow in Wizard | All resources | Frontend code |
| Secret creation | Create Opaque and Pull secrets | None | Frontend code |
| Resource creation | Create PVC, ServingRuntime, InferenceService | Template available | Frontend code |
| EU filtering | Filter models based on region | EU investigation | Frontend code |
| Application screen update | Update/simplify NIM enablement | None | Frontend code |

---

## Dependency Flow

```
┌─────────────────────────────────────────────────────────────┐
│                         Phase 1                              │
│                  Model Serving Changes                       │
│                  (odh-model-controller)                      │
│                                                              │
│   ┌─────────────┐    ┌─────────────┐    ┌────────────────┐  │
│   │   Remove    │    │   Create    │    │    Create      │  │
│   │ Account CRD │    │  Metadata   │    │ ServingRuntime │  │
│   │ & Controller│    │  ConfigMap  │    │   Template     │  │
│   └─────────────┘    └─────────────┘    └────────────────┘  │
│                             │                    │           │
└─────────────────────────────┼────────────────────┼───────────┘
                              │                    │
                              ▼                    ▼
┌─────────────────────────────────────────────────────────────┐
│                         Phase 2                              │
│                    Backend Changes                           │
│                 (opendatahub-operator)                       │
│                                                              │
│   ┌─────────────┐    ┌─────────────────────────────────────┐│
│   │  Remove NIM │    │    Include NIM ConfigMap and       ││
│   │  NIM Flag   │    │    Template in Component Deploy    ││
│   └─────────────┘    └─────────────────────────────────────┘│
│                                        │                     │
└────────────────────────────────────────┼─────────────────────┘
                                         │
                                         ▼
┌─────────────────────────────────────────────────────────────┐
│                         Phase 3                              │
│                   Dashboard Changes                          │
│                    (odh-dashboard)                           │
│                                                              │
│   ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  │
│   │OdhDashboard  │  │   Wizard     │  │   EU Region      │  │
│   │Config Update │  │ Integration  │  │   Filtering      │  │
│   └──────────────┘  └──────────────┘  └──────────────────┘  │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

---

## Communication Matrix

| From | To | Topic | Frequency |
|------|-----|-------|-----------|
| Model Serving (Tomer) | Dashboard Team | Interface specs, ConfigMap schema | As needed |
| Model Serving (Tomer) | Backend Team | Resource inclusion, flag removal | As needed |
| Model Serving (Tomer) | NVIDIA | EU restrictions | As needed |
| Dashboard Team | Model Serving (Tomer) | Questions on specs, schema changes | As needed |
| All | Stakeholders | Status updates | Weekly |

---

## Sync Points

### Sync 1: Pre-Implementation
**Attendees:** Model Serving, Backend, Dashboard leads  
**Agenda:**
- Review ADR and implementation plan
- Confirm interface contracts
- Identify blockers
- Assign tasks

### Sync 2: Model Serving Complete
**Attendees:** Model Serving, Backend, Dashboard leads  
**Agenda:**
- Demo backend changes
- Review ConfigMap schema
- Review Template structure
- Hand off to Dashboard team

### Sync 3: Integration Testing
**Attendees:** All teams + QE  
**Agenda:**
- End-to-end testing
- Bug triage
- Performance validation

### Sync 4: Release Readiness
**Attendees:** All teams + PM + Docs  
**Agenda:**
- Documentation review
- Release notes
- Upgrade path validation

---

## Decision Log

| Date | Decision | Rationale | Owner |
|------|----------|-----------|-------|
| 2026-02-05 | Use build-time metadata | Eliminate enablement latency | Tomer |
| 2026-02-05 | Per-project secrets | Security isolation | Tomer |
| 2026-02-05 | Config-based EU region | Simple, works in air-gap | TBD |
| | | | |

---

## Risk Register

| Risk | Owner | Status | Mitigation |
|------|-------|--------|------------|
| NVIDIA API key approval delayed | Tomer | Resolved | Approval obtained |
| EU restriction list incomplete | Tomer | Open | Conservative filtering |
| Dashboard team bandwidth | Dashboard Lead | Open | Early coordination |
| Upgrade path complexity | All | Open | Thorough testing |

---

## Jira Task Structure

### Epic: NIM Integration Redesign (NVPE-390)

**Model Serving Stories:**
- NVPE-XXX: Remove Account CRD from odh-model-controller
- NVPE-XXX: Remove Account Controller from odh-model-controller
- NVPE-XXX: Create metadata generation script
- NVPE-XXX: Create ServingRuntime Template
- NVPE-XXX: Investigate EU model restrictions
- NVPE-XXX: Update kustomization for NIM resources

**Backend Stories:**
- NVPE-XXX: Remove NIM component from DataScienceCluster CRD
- NVPE-XXX: Include NIM resources in component deployment

**Dashboard Stories:**
- NVPE-XXX: Update OdhDashboardConfig for nimConfig
- NVPE-XXX: Implement ConfigMap reading
- NVPE-XXX: Implement NVIDIA key validation
- NVPE-XXX: Implement Wizard NIM deployment flow
- NVPE-XXX: Implement EU region filtering
- NVPE-XXX: Update Application screen for NIM

**Testing Stories:**
- NVPE-XXX: Unit tests for removed controller
- NVPE-XXX: Integration tests for new flow
- NVPE-XXX: Upgrade testing
- NVPE-XXX: Air-gap testing

**Documentation Stories:**
- NVPE-XXX: Admin guide for NIM configuration
- NVPE-XXX: User guide for NIM deployment
- NVPE-XXX: Custom ConfigMap documentation

---

## Contact List

| Role | Name | Email | Slack |
|------|------|-------|-------|
| Model Serving Lead | Tomer Figenblat | tfigenbl@redhat.com | @tomer |
| Backend Lead | TBD | | |
| Dashboard Lead | TBD | | |
| QE Lead | TBD | | |
| PM | TBD | | |
| NVIDIA Contact | TBD | | |
