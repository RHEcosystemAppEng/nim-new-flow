#!/usr/bin/env bash
# nim_metadata.sh
#
# Utility for NIM model metadata operations.
#
# Commands:
#   generate   - Fetch model metadata and generate a ConfigMap YAML.
#   detect-eu  - Probe models and list EU-restricted ones (HTTP 451).
#
# Usage:
#   ./nim_metadata.sh generate <api_key>
#   ./nim_metadata.sh detect-eu <api_key>
#   ./nim_metadata.sh generate --output /custom/path.yaml <api_key>
#   ./nim_metadata.sh detect-eu --output /custom/path.json <api_key>
#   NGC_API_KEY=<api_key> ./nim_metadata.sh generate
#
# Default output:
#   generate:   generated/nvidia-nim-models-data.yaml
#   detect-eu:  generated/eu_restricted_models.json

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${SCRIPT_DIR}/generated"

# --- API Endpoints ---
CATALOG_URL="https://api.ngc.nvidia.com/v2/search/catalog/resources/CONTAINER"
VALIDATE_URL="https://api.ngc.nvidia.com/v3/keys/get-caller-info"
MODEL_DATA_URL="https://api.ngc.nvidia.com/v2/org/%s/team/%s/repos/%s"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $*" >&2; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*" >&2; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# --- Usage ---
usage() {
    echo "Usage: $0 <command> [options] [api_key]" >&2
    echo "" >&2
    echo "Commands:" >&2
    echo "  generate              Generate ConfigMap from NIM model metadata" >&2
    echo "  detect-eu             Detect EU-restricted models (HTTP 451)" >&2
    echo "" >&2
    echo "Options:" >&2
    echo "  --output <file>       Override default output path" >&2
    echo "" >&2
    echo "API key can be provided as an argument or via NGC_API_KEY env var." >&2
    echo "Only personal API keys (starting with 'nvapi-') are supported." >&2
    exit 1
}

# --- Validate API Key ---
validate_api_key() {
    local api_key="$1"

    if [[ ! "${api_key}" =~ ^nvapi- ]]; then
        log_error "Only personal API keys (starting with 'nvapi-') are supported."
        exit 1
    fi

    log_info "Validating API key..."
    local status
    status=$(curl -s -o /dev/null -w "%{http_code}" \
        -X POST "${VALIDATE_URL}" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -H "Authorization: Bearer ${api_key}" \
        -d "credentials=${api_key}")

    if [[ "${status}" != "200" ]]; then
        log_error "API key validation failed (HTTP ${status})."
        exit 1
    fi
    log_info "API key validated successfully."
}

# --- Discover Models ---
discover_models() {
    log_info "Discovering NIM models from catalog..."

    local page=0
    local page_size=1000
    local all_runtimes="[]"

    while true; do
        local query
        query=$(printf '{"query":"orgName:nim","page":%d,"pageSize":%d}' "${page}" "${page_size}")
        local response
        response=$(curl -s -G "${CATALOG_URL}" --data-urlencode "q=${query}")

        local page_runtimes
        page_runtimes=$(echo "${response}" | jq -r '
            [.results[]
                | select(.groupValue == "CONTAINER")
                | .resources[]
                | {
                    resourceId: .resourceId,
                    name: .name,
                    org: (.resourceId | split("/")[0]),
                    team: (.resourceId | split("/")[1]),
                    image: (.resourceId | split("/")[2]),
                    latestTag: (
                        [.attributes[] | select(.key == "latestTag") | .value][0] // ""
                    )
                }
            ]')

        all_runtimes=$(echo "${all_runtimes}" "${page_runtimes}" | jq -s '.[0] + .[1]')

        local result_page_total
        result_page_total=$(echo "${response}" | jq -r '.resultPageTotal // 1')
        local current_page
        current_page=$(echo "${response}" | jq -r '.params.page // 0')

        if (( current_page >= result_page_total - 1 )); then
            break
        fi
        page=$((page + 1))
    done

    local count
    count=$(echo "${all_runtimes}" | jq 'length')
    log_info "Discovered ${count} models."

    if (( count == 0 )); then
        log_error "No models discovered. Aborting."
        exit 1
    fi

    echo "${all_runtimes}"
}

# --- Command: generate ---
cmd_generate() {
    local api_key="$1"
    local runtimes="$2"
    local output_file="${3:-${OUTPUT_DIR}/nvidia-nim-models-data.yaml}"
    local model_count
    model_count=$(echo "${runtimes}" | jq 'length')

    # Filter to models with a latestTag (for generate we need tags)
    runtimes=$(echo "${runtimes}" | jq '[.[] | select(.latestTag != "")]')
    local filtered_count
    filtered_count=$(echo "${runtimes}" | jq 'length')
    if (( filtered_count < model_count )); then
        log_info "Filtered to ${filtered_count} models with tags."
        model_count=${filtered_count}
    fi

    # Load EU restricted models list if available
    local eu_restricted_file="${OUTPUT_DIR}/eu_restricted_models.json"
    local eu_restricted_names=""
    if [[ -f "${eu_restricted_file}" ]]; then
        eu_restricted_names=$(jq -r '.[].name' "${eu_restricted_file}" | tr '\n' '|' | sed 's/|$//')
        local eu_count
        eu_count=$(jq 'length' "${eu_restricted_file}")
        log_info "Loaded ${eu_count} EU-restricted models from ${eu_restricted_file}"
    else
        log_warn "No EU restricted models file found at ${eu_restricted_file}. Run 'detect-eu' first to mark restricted models."
    fi

    log_info "Fetching tags for each model (this may take a while)..."
    mkdir -p "$(dirname "${output_file}")"

    cat > "${output_file}" <<'HEADER'
apiVersion: v1
kind: ConfigMap
metadata:
  name: nvidia-nim-models-data
  labels:
    opendatahub.io/managed: "true"
data:
HEADER

    local processed=0 skipped=0 failed=0

    for row in $(echo "${runtimes}" | jq -r '.[] | @base64'); do
        _jq() { echo "${row}" | base64 --decode | jq -r "${1}"; }

        local org team image resource_id
        org=$(_jq '.org')
        team=$(_jq '.team')
        image=$(_jq '.image')
        resource_id=$(_jq '.resourceId')

        local url http_code
        url=$(printf "${MODEL_DATA_URL}?resolve-labels=true" "${org}" "${team}" "${image}")
        http_code=$(curl -s -o /tmp/nim_model_response.json -w "%{http_code}" \
            -H "Authorization: Bearer ${api_key}" \
            "${url}")

        if [[ "${http_code}" == "451" ]]; then
            log_warn "Skipping ${resource_id} (HTTP 451 - EU restricted)"
            skipped=$((skipped + 1))
            continue
        fi

        if [[ "${http_code}" != "200" ]]; then
            log_warn "Failed to fetch ${resource_id} (HTTP ${http_code})"
            failed=$((failed + 1))
            continue
        fi

        local response model_json cm_key is_eu_restricted
        response=$(cat /tmp/nim_model_response.json)

        # Check if this model is EU-restricted
        is_eu_restricted="false"
        if [[ -n "${eu_restricted_names}" ]] && echo "${image}" | grep -qE "^(${eu_restricted_names})$"; then
            is_eu_restricted="true"
        fi

        model_json=$(echo "${response}" | jq -c --argjson euRestricted "${is_eu_restricted}" '{
            name: .name,
            displayName: .displayName,
            shortDescription: .shortDescription,
            namespace: .namespace,
            tags: .tags,
            latestTag: .latestTag,
            updatedDate: .updatedDate,
            euRestricted: $euRestricted
        }')

        cm_key=$(echo "${model_json}" | jq -r '.name')

        echo "  ${cm_key}: |" >> "${output_file}"
        echo "${model_json}" | jq '.' | sed 's/^/    /' >> "${output_file}"

        processed=$((processed + 1))
        if (( processed % 10 == 0 )); then
            log_info "Progress: ${processed}/${model_count} models processed..."
        fi
    done

    rm -f /tmp/nim_model_response.json

    echo "" >&2
    log_info "Done!"
    log_info "  Processed: ${processed}"
    log_info "  Skipped (EU restricted): ${skipped}"
    log_info "  Failed: ${failed}"
    log_info "  Output: ${output_file}"
}

# --- Command: detect-eu ---
cmd_detect_eu() {
    local api_key="$1"
    local runtimes="$2"
    local output_file="${3:-${OUTPUT_DIR}/eu_restricted_models.json}"
    local model_count
    model_count=$(echo "${runtimes}" | jq 'length')

    log_info "Probing each model for EU restrictions (HTTP 451)..."

    local restricted_json="[]" accessible=0 failed=0 checked=0

    for row in $(echo "${runtimes}" | jq -r '.[] | @base64'); do
        _jq() { echo "${row}" | base64 --decode | jq -r "${1}"; }

        local org team image resource_id
        org=$(_jq '.org')
        team=$(_jq '.team')
        image=$(_jq '.image')
        resource_id=$(_jq '.resourceId')

        local url http_code
        url=$(printf "${MODEL_DATA_URL}" "${org}" "${team}" "${image}")
        http_code=$(curl -s -o /dev/null -w "%{http_code}" \
            -H "Authorization: Bearer ${api_key}" \
            "${url}")

        checked=$((checked + 1))

        if [[ "${http_code}" == "451" ]]; then
            restricted_json=$(echo "${restricted_json}" | jq \
                --arg name "${image}" \
                --arg resourceId "${resource_id}" \
                --arg org "${org}" \
                --arg team "${team}" \
                '. + [{"name": $name, "resourceId": $resourceId, "org": $org, "team": $team}]')
            log_warn "RESTRICTED: ${image} (${resource_id})"
        elif [[ "${http_code}" == "200" ]]; then
            accessible=$((accessible + 1))
        else
            log_warn "Unexpected response for ${resource_id} (HTTP ${http_code})"
            failed=$((failed + 1))
        fi

        if (( checked % 20 == 0 )); then
            log_info "Progress: ${checked}/${model_count}..."
        fi
    done

    local restricted_count
    restricted_count=$(echo "${restricted_json}" | jq 'length')

    echo "" >&2
    log_info "Done!"
    log_info "  Total models: ${model_count}"
    log_info "  Accessible: ${accessible}"
    log_info "  EU restricted: ${restricted_count}"
    log_info "  Failed: ${failed}"

    if (( restricted_count == 0 )); then
        log_info "No EU-restricted models detected. Are you running this from an EU location?"
    else
        echo "" >&2
        log_info "EU-restricted models:"
        echo "${restricted_json}" | jq -r '.[].name' >&2
    fi

    mkdir -p "$(dirname "${output_file}")"
    echo "${restricted_json}" | jq '.' > "${output_file}"
    log_info "Output: ${output_file}"
}

# --- Main ---
COMMAND="${1:-}"
shift || true

if [[ -z "${COMMAND}" ]]; then
    usage
fi

# Parse remaining args
OUTPUT_FILE=""
API_KEY=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -*)
            log_error "Unknown option: $1"
            usage
            ;;
        *)
            API_KEY="$1"
            shift
            ;;
    esac
done

API_KEY="${API_KEY:-${NGC_API_KEY:-}}"
if [[ -z "${API_KEY}" ]]; then
    log_error "API key is required."
    usage
fi

validate_api_key "${API_KEY}"
RUNTIMES=$(discover_models)

case "${COMMAND}" in
    generate)
        cmd_generate "${API_KEY}" "${RUNTIMES}" "${OUTPUT_FILE}"
        ;;
    detect-eu)
        cmd_detect_eu "${API_KEY}" "${RUNTIMES}" "${OUTPUT_FILE}"
        ;;
    *)
        log_error "Unknown command: ${COMMAND}"
        usage
        ;;
esac
