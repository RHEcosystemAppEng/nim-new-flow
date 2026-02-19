# Changelog

Significant changes to the NIM Integration Redesign documentation and tooling.

## 2026-02-19

### Added
- **Deployment Migration Guide**: Optional guide and script (`migrate_nim_deployment.sh`) for admins to migrate existing deployments from shared secrets to per-deployment secrets. Includes warning about double resource requirements during rollout restart. ([Migration Guide](docs/07_NIM_Deployment_Migration_Guide.md))

### Changed
- **Template CR clarification**: Clarified that "ServingRuntime Template" refers to an OpenShift `template.openshift.io/v1` Template CR encapsulating a ServingRuntime. Updated Dashboard Interface Spec to show the full Template CR YAML (based on live cluster resource). Renamed resource to `nim-http-template`. Updated all docs for consistent terminology.

## 2026-02-18

### Added
- **Open Question #4**: Dashboard external API calls - documented finding that odh-dashboard backend makes zero external calls, outlined options (frontend direct, backend proxy, validating webhook). ([ADR](docs/01_ADR_NIM_Integration_Redesign.md))

### Changed
- **Disconnected environment support**: Replaced `disableKeyValidation` with structured `nimConfig.disconnected` config containing `disableKeyCollection` (boolean). Documented reliance on OpenShift's standard disconnected mechanisms: ImageTagMirrorSet for registry mirroring, global pull secret for authentication. No per-namespace secrets needed for image pulls in disconnected mode. Updated ADR, Dashboard Spec, Implementation Plan, Future Enhancements, and API Endpoints docs.
- **Renamed `disableKeyValidation` to `disableKeyCollection`**: Better reflects that the entire key collection step is skipped in disconnected mode, not just validation.
- **Air-gap preparation steps**: Added concrete admin prerequisites in Future Enhancements doc, including ITMS example config, global pull secret setup, and links to OCP 4.21 docs.
- **Secrets removed from Template CR**: The shipped `template.openshift.io/v1` Template CR (encapsulating the ServingRuntime) no longer contains `NGC_API_KEY` env or `imagePullSecrets`. The Dashboard adds these secret references when creating the ServingRuntime in the user's namespace, alongside other customizations (image, model format, PVC). The resulting ServingRuntime and InferenceService look the same as the current integration. Updated ADR, Implementation Plan, and Dashboard Interface Spec.
- **Key-per-deployment**: Adopted deployment-specific secret naming (`nim-api-key-{deployment-name}`, `nim-image-pull-{deployment-name}`). Each deployment gets its own secrets — no key reuse across deployments. Resolved Open Question #3 in ADR. Updated ADR, Implementation Plan, Dashboard Interface Spec, and Future Enhancements.
- **EU Dashboard handling resolved**: Chose Option 4 (Warning Tooltip) - Dashboard shows warning when user selects EU-restricted model, without blocking selection. Updated ADR, Implementation Plan, Dashboard Spec, and EU Investigation docs.
- **Next Steps cleanup**: Removed completed items 3 and 4 (implementation begun, Dashboard coordination ongoing via Jiras).

## 2026-02-13

### Added
- **EU restriction support**: Added `euRestricted` field to ConfigMap schema. The `generate` script now reads `nim_eu_restricted.json` and marks flagged models. ([Dashboard Interface Spec](docs/03_NIM_Dashboard_Interface_Spec.md), [EU Investigation](docs/04_NIM_EU_Regulation_Investigation.md))

### Changed
- **Metadata generation process**: Clarified that "build-time" means manual PR-based updates to the repository, NOT automated CI. NIM team checks for catalog updates and submits PRs with regenerated ConfigMap. ([ADR](docs/01_ADR_NIM_Integration_Redesign.md), [Implementation Plan](docs/02_NIM_Redesign_Implementation_Plan.md))
- **EU detection approach**: Chose Option A (Build-Time Detection) - run `detect-eu` from EU, then `generate` integrates the results. ([EU Investigation](docs/04_NIM_EU_Regulation_Investigation.md))
- **Future Enhancements**: Added CI Metadata Automation as P3 (post-stabilization) item. ([Future Enhancements](docs/05_NIM_Future_Enhancements.md))
- **Documentation cleanup**: Consolidated EU investigation tasks, removed duplicate sections, simplified testing section, marked completed action items.

## 2026-02-06

### Added
- **Air-gap testing subtask**: Added NVPE-415 for testing NIM deployment in air-gapped environments. ([Implementation Plan](docs/02_NIM_Redesign_Implementation_Plan.md))
- **Jira references**: Added ticket references throughout documentation for traceability (NVPE-409, NVPE-410-415, NVPE-397, NVPE-387, RHAIRFE-767, RHAISTRAT-1202).

## 2026-01-27

### Added
- **Metadata generation script**: Added `nim_metadata.sh` for generating NIM models ConfigMap. Supports `generate` and `detect-eu` commands.

### Changed
- **Resource naming**: Standardized resource names across all docs (`nvidia-nim-models-data`, `nvidia-nim-secrets`, `nvidia-nim-image-pull`).

## 2026-01-23

### Added
- **EU Regulation Investigation**: New document exploring options for handling EU-restricted models. ([EU Investigation](docs/04_NIM_EU_Regulation_Investigation.md))
- **API Endpoints Reference**: Documented NVIDIA NGC API endpoints used by the integration. ([API Endpoints](docs/06_NIM_API_Endpoints.md))

### Changed
- **Dashboard Interface Spec**: Updated to use actual ServingRuntime code from odh-model-controller. ([Interface Spec](docs/03_NIM_Dashboard_Interface_Spec.md))

## 2026-01-20

### Added
- **Initial proposal**: ADR for NIM integration redesign addressing latency and security concerns. ([ADR](docs/01_ADR_NIM_Integration_Redesign.md))
- **Implementation Plan**: Task breakdown for backend and frontend work. ([Implementation Plan](docs/02_NIM_Redesign_Implementation_Plan.md))
- **Dashboard Interface Spec**: Contract for Dashboard/backend integration. ([Interface Spec](docs/03_NIM_Dashboard_Interface_Spec.md))
- **Future Enhancements**: Roadmap for post-redesign features. ([Future Enhancements](docs/05_NIM_Future_Enhancements.md))
