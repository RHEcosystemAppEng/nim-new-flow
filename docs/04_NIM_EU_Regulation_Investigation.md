# NIM EU Regulation Investigation

## Background

Some NVIDIA NIM models are not available in the European Union due to regulatory restrictions. When attempting to access metadata for these models from an EU location, the NVIDIA API returns HTTP status code 451 ("Unavailable For Legal Reasons").

This creates a challenge for our redesigned NIM integration, where model metadata is fetched at build time. If build servers are outside the EU, they will successfully fetch metadata for EU-restricted models, but EU users won't be able to deploy them.

---

## Problem Statement

### Current Behavior

With the existing runtime metadata fetching:
- The Account controller fetches tags for each model at runtime
- If running in EU, restricted models return 451
- These models naturally get excluded from the ConfigMap

### New Architecture Challenge

With build-time metadata fetching:
- Build servers (likely US-based) will successfully fetch all models
- EU users will see models they cannot deploy
- Deployment will fail at image pull or model download stage
- Poor user experience

---

## Investigation Tasks

### Task 1: Identify EU-Restricted Models

**Approach A: NVIDIA Documentation/API**
- Contact NVIDIA for official list of EU-restricted models
- Check if there's an API field indicating restriction
- Request API enhancement if not available

**Approach B: Model Metadata Analysis**
- Check if model IDs or names follow a pattern for restricted models
- Check if model metadata includes any regional availability info

### Task 2: Define Marking Strategy

**Option A: Build-Time Detection**
- Run metadata script from both US and EU locations
- Compare results to identify EU-restricted models
- Add `euRestricted: true` flag to ConfigMap

**Option B: Hardcoded List**
- Maintain a static list of restricted model IDs
- Apply flag during ConfigMap generation
- Requires manual updates when list changes

**Option C: Model-Level Metadata**
- Request NVIDIA to add regional availability to their API
- Parse and include in our ConfigMap

---

## Dashboard Handling Options

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

### Option 4: Warning Tooltip

**Mechanism:**
- If EU-restricted models are marked in the ConfigMap, display them normally in the dropdown
- When a user selects a restricted model, show a warning tooltip (e.g., "This model is not available in the EU due to regulatory restrictions")
- Do not block selection — let the user decide

**Pros:**
- No need for the Dashboard to detect its region
- Simple to implement — no filtering, just a visual indicator
- Works offline (air-gap)
- Users in non-EU regions are unaffected

**Cons:**
- Requires EU-restricted models to be marked in the ConfigMap
- EU users could still attempt deployment (will fail at image pull/model download)

> **Note:** Final approach will be determined after investigation and discussion with the Dashboard team.

---

## Action Items

- [ ] Contact NVIDIA for official EU restriction list
- [x] Set up EU test environment for validation
- [ ] Document findings from investigation
- [ ] Propose final approach based on findings
- [ ] Get legal review if needed
- [ ] Update ADR with EU handling section
