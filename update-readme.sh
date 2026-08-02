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

# ─── Cross-tool table ────────────────────────────────────────────────────────
# Separate config from the version history above (see competitors/README.md),
# so the two tables are not comparable and are rendered apart.
akeneo_version=$(jq -r '.akeneo_version // "v2026.3"' "$latest")

competitors_block="_Run: ${date} — Akeneo ${akeneo_version} — PHP ${php_version} — ${runs_per_version} runs per tool — one shared rule_

| Tool | Version | Median (s) | Violations |
|------|---------|------------|------------|"

while IFS= read -r row; do
    tool=$(echo "$row" | jq -r '.tool')
    tool_version=$(echo "$row" | jq -r '.version')
    violations=$(echo "$row" | jq -r '.violations')
    median_s=$(echo "$row" | jq -r '.median_s | tonumber')
    median_rounded=$(awk "BEGIN {printf \"%.1f\", $median_s}")

    competitors_block+="
| ${tool} | ${tool_version} | ${median_rounded} | ${violations} |"
done < <(jq -c '.competitors[]' "$latest")

awk -v block="$competitors_block" '
  /<!-- COMPETITORS_RESULTS_START -->/ { print; print block; skip=1; next }
  /<!-- COMPETITORS_RESULTS_END -->/   { skip=0 }
  !skip
' "$README" > "${README}.tmp" && mv "${README}.tmp" "$README"

echo "→ README updated."
