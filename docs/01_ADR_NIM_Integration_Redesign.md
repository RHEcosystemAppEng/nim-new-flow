# ADR: Redesign of NVIDIA NIM Integration for RHOAI/ODH

Owner: [Tomer Figenblat](mailto:tfigenbl@redhat.com)
Date: Jan 20, 2026
Jira: [NVPE-390](https://issues.redhat.com/browse/NVPE-390) (exploration), [NVPE-409](https://issues.redhat.com/browse/NVPE-409) (implementation)
**Status**: Approved

## Executive Summary

We are proposing a significant redesign of the NVIDIA NIM integration in OpenDataHub and Red Hat OpenShift AI. This redesign addresses critical user experience and security concerns while simplifying the codebase and enabling future enhancements.

**Key Outcomes:**
- Eliminate 2-minute enablement delay
- Resolve security risk from shared API keys
- Enable seamless Wizard integration
- Reduce maintenance burden

---

# Context

The existing architecture for NVIDIA NIM integration necessitates a redesign due to two major technical drawbacks: **high user-facing latency** and a **security risk**. The high latency is caused by an asynchronous backend process for scraping model metadata that creates friction with the need for synchronous availability to provide an optimal experience in the RHOAI deployment wizard. The security risk stems from the Dashboard disseminating sensitive API credentials by copying them from an administrative namespace into individual user project namespaces.

This document proposes shifting to **Build-Time Metadata Fetching** and **Decentralized Secret Management**. By fetching NIM model metadata during the build process and shipping it as an immutable artifact, we ensure all necessary information is immediately available to the Dashboard at installation. Additionally, to address the security risk, we propose a shift to **Decentralized Secret Management**, empowering the Dashboard to generate secrets directly within the target user projects and eliminating cross-namespace leakage.

The existing effort to integrate the NVIDIA NIM Operator into RHOAI is noted but will not be a focus of this discussion, as it is not anticipated to conflict with this proposal's requirements. Updates on this integration can be tracked via [NVPE-311](https://issues.redhat.com/browse/NVPE-311) and [RHAIRFE-256](https://issues.redhat.com/browse/RHAIRFE-256).

Separately, the subject of Decentralized Secret Management will be addressed as part of the process for onboarding NIM onto the new wizard. The investigation status for this work is documented under [NVPE-387](https://issues.redhat.com/browse/NVPE-387).

## Current Architecture

### The Enablement Process

The enablement phase is an administrative requirement to prepare the cluster for NIM workloads:

1. **Credential Collection:** An Admin provides an NVIDIA API Key via the **Dashboard's "Applications" page**.
2. **CR Creation:** The Dashboard creates an **Opaque Secret** (containing the collected API key) and an **Account CR** (referencing that secret) within the main system namespace (e.g., redhat-ods-applications).
3. **Controller Orchestration:** The odh-model-controller detects the Account CR and triggers a reconciliation loop. **At every step, the controller updates the Account's Status conditions to reflect progress:**
   * **Model Discovery:** Fetches available models from a public NVIDIA endpoint (no API key required).
   * **Key Validation:** Verifies the admin-provided API key against NVIDIA's validation endpoint.
   * **Tag Resolution (Versions):** Fetches tags for each model. **This step requires an API key and involves an individual API call per model.** This takes 1–2 minutes, creating a significant delay before the integration is reported as available for use.
   * **Metadata Storage:** The controller creates a **ConfigMap** in the main system namespace containing the aggregated model data and resolved tags.
   * **Resource Injection:** Upon success, the controller creates a `template.openshift.io/v1` Template CR (encapsulating a ServingRuntime) and a "Prototype Pull Secret" in the main namespace.

### The Deployment Process

Once enablement is reported as successful:

1. **Metadata Access:** The Dashboard uses the ConfigMap created during enablement to populate the model selection UI.
2. **Resource Deployment:** When a user deploys a NIM, the Dashboard handles the resource setup:
   * **Secret Propagation (Security Risk):** The Dashboard copies the **Opaque Secret** and the **Pull Secret Prototype** from the main system namespace into the User’s Project namespace.
   * **Model Deployment:** The Dashboard creates the **PVC, ServingRuntime, and InferenceService** resources.

![Current Architecture](../images/current-architecture.jpg)

Figure 1: Current Architecture \- Controller-Driven
Alt text: Illustrates the heavy reliance on the odh-model-controller and the security risk of copying secrets across namespaces.

##  Proposed Architecture: "Build-Time & Localized"

### Build-Time Phase (Metadata Fetching)

> **Important:** "Build-time" means the ConfigMap is updated via **pull requests** to the odh-model-controller repository, not via automated CI. The NIM team is responsible for checking whether an update is needed (e.g., new models in NVIDIA's catalog) and submitting a PR with the regenerated ConfigMap prior to each release.

* **Metadata Scraping:** A script is run manually by the NIM team using a Red Hat-managed API key. **This key is used exclusively to fetch model tags;** all other model metadata is publicly accessible.
* **Immutable ConfigMap:** This metadata is saved as a static ConfigMap, committed to the repository, and shipped with the product.
* **Template Integration:** The Template CR (encapsulating the ServingRuntime) is defined as a static resource at build-time, removing dynamic generation from the controller.

### Backend Simplification

* **Removal of Controller Logic:** The Account controller and all enablement-related logic in odh-model-controller are removed.
* **Account CRD Deletion:** The **Account CRD** is being removed entirely from the system. This eliminates the runtime reconciliation loop entirely.
* **DSC CRD Update:** The NIM component is being removed from the **DataScienceCluster CRD** (currently under the KServe component in `spec.components.kserve.nim`).

### Dashboard Enhancements

The Dashboard will now manage the deployment lifecycle directly within the user project:

1. **Metadata Source:** The Dashboard reads the pre-shipped ConfigMap. A new flag in **OdhDashboardConfig** allows admins to specify a customConfigMap (Object Reference) to be used instead of the immutable version.
2. **Validation:** The Wizard validates the user's personal API key against NVIDIA (legacy keys are not supported). In disconnected environments, key collection and validation are disabled via `OdhDashboardConfig.spec.nimConfig.disconnected.disableKeyCollection`.
3. **Local Secret Creation:** The Wizard creates deployment-specific **Opaque Secret** and **Pull Secret** directly in the user’s project namespace.
   * **Opaque Secret:** Mounted to the ServingRuntime container as an environment variable (`NGC_API_KEY`) and used to download models at runtime.
   * **Pull Secret:** Referenced by the ServingRuntime's `imagePullSecrets` for pulling the model container image from NVIDIA's registry.
4. **Resource Deployment:** The Dashboard creates the **PVC, ServingRuntime, and InferenceService**.
   * The Template CR ships without secrets — the ServingRuntime inside has no `NGC_API_KEY` env var and no `imagePullSecrets`. The Dashboard adds the deployment-specific secret references when creating the ServingRuntime in the user's namespace, alongside other customizations (image, model format, PVC name). The resulting ServingRuntime looks the same as the current integration.
   * The **InferenceService** remains unchanged — model format, resources, and runtime reference only.

![Proposed Architecture](../images/proposed-architecture.jpg)

Figure 2: Proposed Architecture \- Build-Time & Wizard-Driven
Alt text: Streamlined flow where metadata is "baked in" and secrets are local to the project from the start.

### CRD Changes

The OdhDashboardConfig CRD will be updated:

```yaml
apiVersion: opendatahub.io/v1alpha
kind: OdhDashboardConfig
metadata:
  name: odh-dashboard-config
spec:
  # ... existing fields ...
  nimConfig:
    # Allows overriding the default shipped metadata
    customConfigMap:
      name: "custom-nim-models"
      namespace: "redhat-ods-applications"
    # Disconnected (air-gapped) environment settings
    disconnected:
      # Skip API key collection and validation in the Wizard
      disableKeyCollection: true
```

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
- **Enable future features** - Key rotation, dual-protocol support (see [Future Enhancements](05_NIM_Future_Enhancements.md))

---

## Addressing Potential Concerns

* **Why use a Red Hat key at build-time?** The key is used **only to fetch tags/versions** so the model list is populated immediately upon installation without scraping latency.
* **What is the user's key used for?** The user’s personal API key is used for both **pulling the container image** from the registry (via the Pull Secret) and **downloading the model** at runtime (via the Opaque Secret environment variable).
* **Operational Runtime Security:** From a user perspective, their API key will get validated by the dashboard. If validation passes but something else is broken, the image pull will fail at the cluster level, or the model download will fail at the container runtime level. In either scenario, the use of a Red Hat API key during the build phase to fetch tags does not leverage or expose that key at runtime.
* **How does this support Air-Gap?** By shipping metadata with the product, we remove the requirement for the cluster to "discover" models. For disconnected environments, admins configure `spec.nimConfig.disconnected` to disable key collection. Image pulling is handled by OpenShift's standard disconnected mechanisms: [ImageTagMirrorSet](https://docs.redhat.com/en/documentation/openshift_container_platform/4.21/html/config_apis/imagetagmirrorset-config-openshift-io-v1) to redirect `nvcr.io` to an internal mirror, and the [global pull secret](https://docs.redhat.com/en/documentation/openshift_container_platform/4.21/html/postinstallation_configuration/post-install-image-config) for registry authentication. No per-namespace secrets are needed for image pulls. See [Future Enhancements - Enhanced Air-Gap Support](05_NIM_Future_Enhancements.md#3-enhanced-air-gap-support) for setup steps.
* **Legacy Key Deprecation:** This redesign only supports personal API keys. Legacy (org-level) keys are no longer supported.

  > **Note:** We will confirm with NVIDIA that they have completed the legacy key deprecation process on their side before finalizing this change.

* **What about NVIDIA coordination?** We have informed NVIDIA and clarified our limited usage: we are only using a Red Hat key to fetch the list of available version strings. All subsequent operations, including verification, pulling, and downloading, rely on the user's personal key. Red Hat's keys are used only by maintainers when generating the metadata ConfigMap prior to releases.

---

## Open Questions

1. **EU Regulation** - Resolved
   - ~~How do we reliably determine which models are EU-restricted?~~
   - ~~Should Dashboard detect geographic location or rely on config?~~
   - Using build-time detection: run `detect-eu` from EU location, then `generate` adds `euRestricted: true` to flagged models. Dashboard shows a warning tooltip when a user selects an EU-restricted model. See [EU Regulation Investigation](04_NIM_EU_Regulation_Investigation.md).

2. **Application Screen**
   - Should we keep the application screen enablement toggle?
   - If yes, what does it control without API key collection?

3. **Multiple API Keys per Project** - Resolved
   - ~~Current design uses fixed secret names (`nvidia-nim-secrets`, `nvidia-nim-image-pull`) per project, meaning one API key per project~~
   - ~~Should we support multiple API keys (e.g., per deployment) in the future? This would require deployment-specific secret naming~~
   - Adopted **key-per-deployment**: each deployment gets its own secrets (`nvidia-nim-secrets-{deployment-name}`, `nvidia-nim-image-pull-{deployment-name}`). This avoids key reuse across deployments, simplifies Dashboard implementation, and enables per-deployment key rotation.

4. **Dashboard External API Calls**
   - The current design requires the Dashboard/Wizard to call NVIDIA's API to validate the user's API key before deployment
   - The odh-dashboard backend currently makes **zero external internet calls**. All HTTP calls are to internal cluster services (K8s API, Prometheus). Adding NVIDIA API validation would be the first external call.
   - **Options:**
     - **A. Frontend direct call:** Dashboard frontend calls NVIDIA API directly (blocked by CORS, likely not viable)
     - **B. Backend proxy endpoint:** Add a new endpoint to odh-dashboard backend that proxies validation requests to NVIDIA.
     - **C. Validating admission webhook:** A webhook in odh-model-controller intercepts Secret creation, validates the key with NVIDIA, and annotates the Secret with validation status. Dashboard polls/watches for the annotation. Keeps external calls in the controller layer.
   - **Trade-offs:**
     - Option B is simpler but introduces external dependencies to the dashboard
     - Option C is more complex but keeps the dashboard stateless

---

## Next Steps

1. ~~Coordinate with NVIDIA on build-time API key usage~~ Done
2. ~~Get stakeholder alignment and approval~~ Done

---

## Related Documents

- [Implementation Plan](02_NIM_Redesign_Implementation_Plan.md)
- [Dashboard Interface Specification](03_NIM_Dashboard_Interface_Spec.md)
- [EU Regulation Investigation](04_NIM_EU_Regulation_Investigation.md)
- [Future Enhancements](05_NIM_Future_Enhancements.md)
- [API Endpoints](06_NIM_API_Endpoints.md)
