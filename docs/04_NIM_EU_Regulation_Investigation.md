# NIM EU Regulation Investigation

## Background

Some NVIDIA NIM models are not available in the European Union due to regulatory restrictions. When attempting to access metadata for these models from an EU location, the NVIDIA API returns HTTP status code 451 ("Unavailable For Legal Reasons").

This creates a challenge for our redesigned NIM integration, where model metadata is fetched at build time (manually by the NIM team prior to each release). If the script is run from outside the EU, it will successfully fetch metadata for EU-restricted models, but EU users won't be able to deploy them.

---

## Problem Statement

### Current Behavior

With the existing runtime metadata fetching:
- The Account controller fetches tags for each model at runtime
- If running in EU, restricted models return 451
- These models naturally get excluded from the ConfigMap

### New Architecture Challenge

With build-time metadata fetching:
- If the script is run from outside the EU, it will successfully fetch all models
- EU users will see models they cannot deploy
- Deployment will fail at image pull or model download stage
- Poor user experience

---

## Identification and Marking Approach

**Identify and Mark EU-Restricted Models:**
1. Run `detect-eu` script from an EU location - models returning HTTP 451 are saved to `eu_restricted_models.json`
2. Run `generate` script which reads the restricted list and adds `euRestricted: true` to flagged models in the ConfigMap
3. Both scripts are run manually by the NIM team prior to each release

**Other approaches considered:**
- Contact NVIDIA for official list (no structured data available)
- Analyze model metadata for patterns (no reliable indicators found)
- Maintain a hardcoded list (requires manual updates when list changes)
- Request NVIDIA to add regional availability to their API (out of our control)

---

## Dashboard Handling Options

> **Resolution:** Option 4 (Warning Tooltip) was chosen. The Dashboard will show a warning tooltip when a user selects an EU-restricted model, without blocking selection.

### Option 1: Configuration-Based Region

**Mechanism:**
- Add `nimConfig.clusterRegion` to OdhDashboardConfig
- Admin sets region during installation
- Dashboard filters based on region

**Pros:**
- Simple, explicit
- Works offline (air-gap)
- Admin has control

**Cons:**
- Manual configuration required
- Could be misconfigured

**Example:**
```yaml
nimConfig:
  clusterRegion: "EU"  # or "US", "APAC", etc.
```

### Option 2: Runtime Probe

**Mechanism:**
- Dashboard makes test call to known EU-restricted model
- If 451, assume EU and filter
- Cache result

**Pros:**
- Automatic detection
- No configuration needed

**Cons:**
- Adds latency at Wizard load
- Requires network access
- Won't work in air-gap

### Option 3: Cloud Provider Metadata

**Mechanism:**
- Query cloud provider metadata for region
- Map to EU/non-EU classification

**Pros:**
- Automatic for cloud deployments

**Cons:**
- Won't work for on-premise
- Different APIs for each cloud

### Option 4: Warning Tooltip ✓ CHOSEN

**Mechanism:**
- EU-restricted models (`euRestricted: true`) are displayed normally in the model dropdown
- When a user selects a restricted model, show a warning tooltip (e.g., "This model may not be available in the EU due to regulatory restrictions")
- Do not block selection — let the user proceed with deployment

**Pros:**
- No need for the Dashboard to detect its region
- Simple to implement — no filtering, just a visual indicator
- Works offline (air-gap)
- Users in non-EU regions are unaffected

**Cons:**
- EU users could still attempt deployment (will fail at image pull/model download)

---

## Action Items

- [x] Contact NVIDIA for official EU restriction list
- [x] Set up EU test environment for validation
- [x] Document findings from investigation
- [x] Propose final approach based on findings
- [x] Update ADR with EU handling section
