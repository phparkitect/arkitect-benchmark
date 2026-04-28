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

# ─── phparkitect version history table ───────────────────────────────────────

# Baseline = latest stable release (first non-main phparkitect result)
baseline_version=$(jq -r '[.results[] | select(.tool == "phparkitect" and .version != "main")] | .[0].version' "$latest")
baseline_median=$(jq -r '[.results[] | select(.tool == "phparkitect" and .version != "main")] | .[0].median_s | tonumber' "$latest")

arkitect_block="_Run: ${date} — Symfony ${symfony_version} — PHP ${php_version} — ${runs_per_version} runs per version_

| Version | Median (s) | vs ${baseline_version} |
|---------|------------|------------------------|"

while IFS= read -r row; do
    version=$(echo "$row" | jq -r '.version')
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

    arkitect_block+="
| ${version} | ${median_rounded} | ${ratio} |"
done < <(jq -c '[
    (.results[] | select(.tool == "phparkitect" and .version == "main")),
    (.results[] | select(.tool == "phparkitect" and .version != "main"))
  ][]' "$latest")

# ─── Competitor table ─────────────────────────────────────────────────────────

# Baseline for competitor table = phparkitect main
arkitect_main_median=$(jq -r '[.results[] | select(.tool == "phparkitect" and .version == "main")] | .[0].median_s | tonumber' "$latest")

competitor_block="_Run: ${date} — Symfony ${symfony_version} — PHP ${php_version} — ${runs_per_version} runs per version_

| Tool | Version | Median (s) | vs phparkitect/main |
|------|---------|------------|---------------------|"

while IFS= read -r row; do
    tool=$(echo "$row" | jq -r '.tool')
    version=$(echo "$row" | jq -r '.version')
    median_s=$(echo "$row" | jq -r '.median_s | tonumber')
    median_rounded=$(awk "BEGIN {printf \"%.1f\", $median_s}")

    if [[ "$tool" == "phparkitect" && "$version" == "main" ]]; then
        ratio="baseline"
    else
        ratio=$(awk "BEGIN {
            diff = ($median_s - $arkitect_main_median) / $arkitect_main_median * 100
            sign = (diff >= 0) ? \"+\" : \"\"
            printf \"%s%.1f%%\", sign, diff
        }")
    fi

    competitor_block+="
| ${tool} | ${version} | ${median_rounded} | ${ratio} |"
done < <(jq -c '[
    (.results[] | select(.tool == "phparkitect" and .version == "main")),
    (.results[] | select(.tool != "phparkitect"))
  ][]' "$latest")

# ─── Replace markers in README ────────────────────────────────────────────────
tmp=$(mktemp)

awk -v ab="$arkitect_block" -v cb="$competitor_block" '
  /<!-- BENCHMARK_RESULTS_START -->/   { print; print ab; skip=1; next }
  /<!-- BENCHMARK_RESULTS_END -->/     { skip=0 }
  /<!-- COMPETITOR_RESULTS_START -->/  { print; print cb; skip=1; next }
  /<!-- COMPETITOR_RESULTS_END -->/    { skip=0 }
  !skip
' "$README" > "$tmp" && mv "$tmp" "$README"

echo "→ README updated."
