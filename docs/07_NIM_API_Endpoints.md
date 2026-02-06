# NIM API Endpoints

## Overview

This document describes the NVIDIA API endpoints used by the NIM integration for model discovery, API key validation, and metadata fetching.

---

## 1. Model Discovery

**Endpoint:** `GET https://api.ngc.nvidia.com/v2/search/catalog/resources/CONTAINER`

**Purpose:** Discovers all available NIM models from the NVIDIA catalog.

**Authentication:** None required

**Query Parameters:**
```
q={"query":"orgName:nim","page":0,"pageSize":1000}
```

**Usage:**
- Used at build time to fetch the list of available NIM models
- Returns model metadata including resource IDs, names, and attributes
- No API key required for this endpoint

---

## 2. API Key Validation

**Endpoint:** `POST https://api.ngc.nvidia.com/v3/keys/get-caller-info`

**Purpose:** Validates a user's NVIDIA API key.

**Headers:**
```
Content-Type: application/x-www-form-urlencoded
Authorization: Bearer <api_key>
```

**Body:**
```
credentials=<api_key>
```

**Response:**
- `200` = Key validated successfully
- Any other status = Key not validated

**Usage:**
- Build-time: Validates Red Hat's API key before fetching metadata
- Runtime: Called by Dashboard to validate user's API key before deployment
  - Can be disabled via `OdhDashboardConfig.nimConfig.disableKeyValidation` for air-gap environments

---

## 3. Model Tags/Metadata

**Endpoint:** `GET https://api.ngc.nvidia.com/v2/org/nim/team/{team}/repos/{repo}`

**Example:** `GET https://api.ngc.nvidia.com/v2/org/nim/team/nvidia/repos/nv-embedqa-e5-v5-pb24h2`

**Purpose:** Fetches tags and detailed metadata for a specific model.

**Headers:**
```
Authorization: Bearer <api_key>
```

**Query Parameters (optional):**
```
resolve-labels=true
```

**Response Codes:**
- `200` = Success, returns model tags and metadata
- `401` = Invalid API key
- `451` = Unavailable for legal reasons (EU-restricted model)

**Usage:**
- Used at build time to fetch available tags for each model
- Requires one API call per model (can be slow for large catalogs)
- The `451` response indicates a model restricted in EU regions

---

## Notes

- The model discovery endpoint does not require authentication
- The validation and tags endpoints require a valid NVIDIA API key
- Build-time scripts use Red Hat's API key for metadata fetching
- Runtime validation uses the user's API key
