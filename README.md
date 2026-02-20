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
| [01 - ADR: NIM Integration Redesign](docs/01_ADR_NIM_Integration_Redesign.md) | Architecture Decision Record (main document for stakeholders) |
| [02 - Implementation Plan](docs/02_NIM_Redesign_Implementation_Plan.md) | Implementation plan with tasks and workstreams |
| [03 - Dashboard Interface Spec](docs/03_NIM_Dashboard_Interface_Spec.md) | Technical specification for Dashboard/Frontend |
| [04 - EU Regulation Investigation](docs/04_NIM_EU_Regulation_Investigation.md) | Investigation into EU model restrictions (HTTP 451) |
| [05 - Future Enhancements](docs/05_NIM_Future_Enhancements.md) | Out-of-scope features enabled by this redesign |
| [06 - API Endpoints](docs/06_NIM_API_Endpoints.md) | NVIDIA API endpoints used by the integration |
| [07 - Deployment Migration Guide](docs/07_NIM_Deployment_Migration_Guide.md) | Optional guide for migrating existing deployments to per-deployment secrets |
| [Changelog](CHANGELOG.md) | Track significant changes to these docs |

## Projects Involved

- **opendatahub-operator** - Main operator, DataScienceCluster CRD
- **odh-model-controller** - Backend code, Account CRD/Controller (to be removed)
- **odh-dashboard** - Frontend UI, OdhDashboardConfig CRD

## Key Changes

- Remove Account CRD and Controller from odh-model-controller
- Remove NIM component from DataScienceCluster CRD
- Fetch model metadata at build time, ship as immutable ConfigMap
- Move API key collection to the Wizard (per-deployment)
- Dashboard creates resources directly in user's project

## Timeline

Targeting **RHOAI 3.5.EA1**. Fallback is EA2 if needed.

| Milestone | Code Freeze | Release |
|-----------|-------------|---------|
| **3.5.EA1** (target) | May 15 | Jun 18 |
| 3.5.EA2 (fallback) | Jun 19 | Jul 16 |
| 3.5 GA | Jul 24 | Aug 20 |

## Team

| Name | Role |
|------|------|
| [Swati Kale](mailto:swkale@redhat.com) | Project Lead |
| [Tomer Figenblat](mailto:tfigenbl@redhat.com) | Task Owner, Backend |
| [Marcus Trujillo](mailto:matrujil@redhat.com) | Air-Gap Support, Backend |
| [Matan Talvi](mailto:mtalvi@redhat.com) | Wizard Onboarding, Frontend |

## Script

### `nim_metadata.sh`

Utility for NIM model metadata operations. Requires `curl` and `jq`.

**Commands:**

| Command | Description |
|---------|-------------|
| `detect-eu` | Probe models and list EU-restricted ones (HTTP 451) |
| `generate` | Fetch model metadata and generate a ConfigMap YAML (uses `nim_eu_restricted.json` if present) |

**Usage:**
```bash
# Detect EU-restricted models (run from EU location)
./nim_metadata.sh detect-eu <personal-api-key>

# Generate ConfigMap (uses nim_eu_restricted.json if present)
./nim_metadata.sh generate <personal-api-key>

# Override default output path
./nim_metadata.sh detect-eu --output /custom/path.json <personal-api-key>
./nim_metadata.sh generate --output /custom/path.yaml <personal-api-key>

# Use environment variable instead of argument
NGC_API_KEY=<personal-api-key> ./nim_metadata.sh generate
```

Only personal API keys (starting with `nvapi-`) are supported.

**Default output:**

| Command | Default Path | Format |
|---------|-------------|--------|
| `detect-eu` | `generated/nim_eu_restricted.json` | JSON array (`name`, `resourceId`, `org`, `team`) |
| `generate` | `generated/nim-models-data.yaml` | Kubernetes ConfigMap YAML |

## Related Jira

- [NVPE-409](https://issues.redhat.com/browse/NVPE-409) - NIM Integration Redesign - Implementation (story with subtasks)
  - [NVPE-397](https://issues.redhat.com/browse/NVPE-397) - Onboard NIM to the new deployment Wizard
- [NVPE-390](https://issues.redhat.com/browse/NVPE-390) - Exploration (completed)
- [NVPE-387](https://issues.redhat.com/browse/NVPE-387) - Wizard investigation (completed)
- [RHAIRFE-767](https://issues.redhat.com/browse/RHAIRFE-767) - RFE
- [RHAISTRAT-1202](https://issues.redhat.com/browse/RHAISTRAT-1202) - STRAT
