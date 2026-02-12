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
| `generate` | Fetch model metadata and generate a ConfigMap YAML |
| `detect-eu` | Probe models and list EU-restricted ones (HTTP 451) |

**Usage:**
```bash
# Generate ConfigMap
./nim_metadata.sh generate <personal-api-key>

# Detect EU-restricted models (run from EU location)
./nim_metadata.sh detect-eu <personal-api-key>

# Override default output path
./nim_metadata.sh generate --output /custom/path.yaml <personal-api-key>
./nim_metadata.sh detect-eu --output /custom/path.json <personal-api-key>

# Use environment variable instead of argument
NGC_API_KEY=<personal-api-key> ./nim_metadata.sh generate
```

Only personal API keys (starting with `nvapi-`) are supported.

**Default output:**

| Command | Default Path | Format |
|---------|-------------|--------|
| `generate` | `generated/nvidia-nim-models-data.yaml` | Kubernetes ConfigMap YAML |
| `detect-eu` | `generated/eu_restricted_models.json` | JSON array (`name`, `resourceId`, `org`, `team`) |

## Related Jira

**Backend:**
- [NVPE-409](https://issues.redhat.com/browse/NVPE-409) - Implementation (story with subtasks)
- [NVPE-390](https://issues.redhat.com/browse/NVPE-390) - Exploration (completed)

**Frontend:**
- [NVPE-397](https://issues.redhat.com/browse/NVPE-397) - New UI Wizard changes for NIM
- [NVPE-387](https://issues.redhat.com/browse/NVPE-387) - Investigation new UI wizard (completed)
- [RHAIRFE-767](https://issues.redhat.com/browse/RHAIRFE-767) - RFE
- [RHAISTRAT-1202](https://issues.redhat.com/browse/RHAISTRAT-1202) - STRAT
