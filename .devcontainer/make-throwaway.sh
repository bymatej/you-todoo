#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 <name>"
  exit 1
fi

RAW_NAME="$1"
SAFE_NAME="$(printf '%s' "$RAW_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9._-]/-/g')"

if [ -z "$SAFE_NAME" ]; then
  echo "Error: name became empty after sanitization"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_FILE="${SCRIPT_DIR}/throwaway.template.json"
OUTPUT_DIR="${SCRIPT_DIR}/generated/${SAFE_NAME}"
OUTPUT_FILE="${OUTPUT_DIR}/devcontainer.json"

mkdir -p "${OUTPUT_DIR}"

sed "s|__NAME__|${SAFE_NAME}|g" "${TEMPLATE_FILE}" > "${OUTPUT_FILE}"

echo "Generated: ${OUTPUT_FILE}"
