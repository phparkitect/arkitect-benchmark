#!/usr/bin/env bash
set -euo pipefail

RESULTS_DIR="./results"
README="README.md"

# Find the most recent result file
latest=$(ls -t "${RESULTS_DIR}"/*.json 2>/dev/null | head -1)
if [[ -z "$latest" ]]; then
    echo "ERROR: No JSON files found in ${RESULTS_DIR}/" >&2
    exit 1
fi

echo "→ Using result file: ${latest}"

# Extract metadata
date=$(jq -r '.date' "$latest")
symfony_version=$(jq -r '.symfony_version' "$latest")
php_version=$(jq -r '.php_version' "$latest")
runs_per_version=$(jq -r '.runs_per_version' "$latest")

# Build the markdown block
new_block="_Run: ${date} — Symfony ${symfony_version} — PHP ${php_version} — ${runs_per_version} runs per version_

| Version | Min (ms) | Median (ms) | Max (ms) |
|---------|----------|-------------|----------|"

while IFS= read -r row; do
    version=$(echo "$row" | jq -r '.phparkitect_version')
    min=$(echo "$row" | jq -r '.min_ms')
    median=$(echo "$row" | jq -r '.median_ms')
    max=$(echo "$row" | jq -r '.max_ms')
    new_block+="
| ${version} | ${min} | ${median} | ${max} |"
done < <(jq -c '.results[]' "$latest")

# Replace content between markers in README
awk -v block="$new_block" '
  /<!-- BENCHMARK_RESULTS_START -->/ { print; print block; skip=1; next }
  /<!-- BENCHMARK_RESULTS_END -->/   { skip=0 }
  !skip
' "$README" > "${README}.tmp" && mv "${README}.tmp" "$README"

echo "→ README updated."
