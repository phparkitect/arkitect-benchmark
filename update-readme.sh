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

# Baseline = latest stable release (first non-main result)
baseline_version=$(jq -r '[.results[] | select(.phparkitect_version != "main")] | .[0].phparkitect_version' "$latest")
baseline_median=$(jq -r '[.results[] | select(.phparkitect_version != "main")] | .[0].median_s | tonumber' "$latest")

# Build the markdown block
new_block="_Run: ${date} — Symfony ${symfony_version} — PHP ${php_version} — ${runs_per_version} runs per version_

| Version | Median (s) | vs ${baseline_version} |
|---------|------------|------------------------|"

while IFS= read -r row; do
    version=$(echo "$row" | jq -r '.phparkitect_version')
    median_s=$(echo "$row" | jq -r '.median_s | tonumber')

    median_rounded=$(awk "BEGIN {printf \"%.1f\", $median_s}")

    if [[ "$version" == "$baseline_version" ]]; then
        ratio="baseline"
    else
        ratio=$(awk "BEGIN {
            diff = ($median_s - $baseline_median) / $baseline_median * 100
            sign = (diff >= 0) ? \"+\" : \"\"
            printf \"%s%.1f%%\", sign, diff
        }")
    fi

    new_block+="
| ${version} | ${median_rounded} | ${ratio} |"
done < <(jq -c '[(.results[] | select(.phparkitect_version == "main")), (.results[] | select(.phparkitect_version != "main"))][]' "$latest")

# Replace content between markers in README
awk -v block="$new_block" '
  /<!-- BENCHMARK_RESULTS_START -->/ { print; print block; skip=1; next }
  /<!-- BENCHMARK_RESULTS_END -->/   { skip=0 }
  !skip
' "$README" > "${README}.tmp" && mv "${README}.tmp" "$README"

echo "→ README updated."
