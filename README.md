# NIM Integration Redesign

Planning documents for the redesign of NVIDIA NIM integration in OpenDataHub (ODH) and Red Hat OpenShift AI (RHOAI).

## Overview

This repository contains the planning and design documentation for a significant redesign of the NIM integration. The redesign addresses three critical pain points:

1. **High Latency** - Metadata fetching takes 1-2 minutes during enablement
2. **Security Risk** - API keys are copied from the main namespace to user projects
3. **Wizard Incompatibility** - The async backend flow doesn't align with the new deployment Wizard

## Documents

| Document | Description |
|----------|-------------|
| [01 - ADR: NIM Integration Redesign](docs/01_ADR_NIM_Integration_Redesign.md) | Architecture Decision Record detailing the proposed changes |
| [02 - Stakeholder Brief](docs/02_NIM_Redesign_Stakeholder_Brief.md) | Executive summary for stakeholders |
| [03 - Implementation Plan](docs/03_NIM_Redesign_Implementation_Plan.md) | Implementation plan with tasks, risks, and decisions |
| [04 - Dashboard Interface Spec](docs/04_NIM_Dashboard_Interface_Spec.md) | Technical specification for Dashboard/Frontend team |
| [05 - EU Regulation Investigation](docs/05_NIM_EU_Regulation_Investigation.md) | Investigation into EU model restrictions (HTTP 451) |
| [06 - Future Enhancements](docs/06_NIM_Future_Enhancements.md) | Out-of-scope features enabled by this redesign |
| [07 - API Endpoints](docs/07_NIM_API_Endpoints.md) | NVIDIA API endpoints used by the integration |

## Projects Involved

- **opendatahub-operator** - Main operator, DataScienceCluster CRD
- **odh-model-controller** - Backend code, Account CRD/Controller (to be removed)
- **odh-dashboard** - Frontend UI, OdhDashboardConfig CRD

## Key Changes

- Remove Account CRD and Controller from odh-model-controller
- Remove NIM component from DataScienceCluster CRD
- Fetch model metadata at build time, ship as immutable ConfigMap
- Move API key collection to the Wizard (per-project)
- Dashboard creates resources directly in user's project

## Related Jira

- [NVPE-390](https://issues.redhat.com/browse/NVPE-390)
