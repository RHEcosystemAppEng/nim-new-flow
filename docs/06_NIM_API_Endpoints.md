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

**Example response:** [catalog_search.json](../api-responses/catalog_search.json)

---

## 2. API Key Validation

**Endpoint:** `POST https://api.ngc.nvidia.com/v3/keys/get-caller-info`

**Purpose:** Validates a user's NVIDIA API key. **Only supports personal API keys (not legacy keys).**

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
  - Skipped when `OdhDashboardConfig.spec.nimConfig.disconnected.disableKeyCollection` is true (disconnected environments)

**Example response:** [key_validation.json](../api-responses/key_validation.json) (personal data redacted)

---

## 3. Model Tags/Metadata

**Endpoint:** `GET https://api.ngc.nvidia.com/v2/org/{org}/team/{team}/repos/{repo}`

**Example:** `GET https://api.ngc.nvidia.com/v2/org/nim/team/nvidia/repos/nv-embedqa-e5-v5-pb24h2`

**Purpose:** Fetches tags and detailed metadata for a specific model.

**Headers:**
```
Authorization: Bearer <api_key>
```

**Query Parameters:**
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

**Example responses:**
- [model_tags.json](../api-responses/model_tags.json) (200 - success)
- [model_tags_451.json](../api-responses/model_tags_451.json) (451 - EU restricted)

---

## Notes

- The model discovery endpoint does not require authentication
- The validation and tags endpoints require a valid NVIDIA API key
- Build-time scripts use Red Hat's API key for metadata fetching
- Runtime validation uses the user's API key
