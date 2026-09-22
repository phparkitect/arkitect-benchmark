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

# Build the markdown block
new_block="_Run: ${date} — Symfony ${symfony_version} — PHP ${php_version} — ${runs_per_version} interleaved rounds_
"

# Transposed: versions as columns, so more of them fit on one screen.
header="|  |"
sep="|---|"
row_median="| **Median** |"
row_ratio="| **vs ${baseline_version}** |"

while IFS= read -r row; do
    version=$(echo "$row" | jq -r '.phparkitect_version')
    median_s=$(echo "$row" | jq -r '.median_s | tonumber')
    median_rounded=$(awk "BEGIN {printf \"%.1f\", $median_s}")

    if [[ "$version" == "$baseline_version" ]]; then
        ratio="baseline"
    else
        # Compared round by round: both timings of a round were taken minutes
        # apart on the same machine, so its drift cancels out. The median of those
        # differences is reported only if every round agrees on the direction;
        # otherwise the machine moved more than the versions differ.
        ratio=$(jq -r --arg v "$version" --arg b "$baseline_version" '
            (.results[] | select(.phparkitect_version == $v) | .runs_ms) as $t
            | (.results[] | select(.phparkitect_version == $b) | .runs_ms) as $base
            | [range(0; $t | length) | ($t[.] / $base[.] - 1) * 100] | sort
            | (length) as $n
            | (if $n % 2 == 1 then .[($n - 1) / 2] else (.[$n / 2 - 1] + .[$n / 2]) / 2 end) as $median
            | ($median | fabs | round) as $pct
            | if (.[0] < 0 and .[-1] > 0) or $pct == 0 then "≈"
              elif $median > 0 then "+\($pct)%"
              else "-\($pct)%" end' "$latest")
    fi

    header+=" ${version} |"
    sep+="---|"
    row_median+=" ${median_rounded}s |"
    row_ratio+=" ${ratio} |"
done < <(jq -c '[(.results[] | select(.phparkitect_version == "main")), (.results[] | select(.phparkitect_version != "main"))][]' "$latest")

new_block+="
${header}
${sep}
${row_median}
${row_ratio}

_≈ means the rounds disagreed on the direction — faster than ${baseline_version} in some, slower in others — i.e. no measurable difference._"

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

| Tool | Version | Cold | Warm cache |
|------|---------|------|------------|"

while IFS= read -r row; do
    tool=$(echo "$row" | jq -r '.tool')
    tool_version=$(echo "$row" | jq -r '.version')
    median_s=$(echo "$row" | jq -r '.median_s | tonumber')
    median_rounded=$(awk "BEGIN {printf \"%.1f\", $median_s}")

    warm_s=$(echo "$row" | jq -r '.median_warm_s // "null"')
    if [[ "$warm_s" == "null" ]]; then
        warm="— *(no cache)*"
    else
        warm="$(awk "BEGIN {printf \"%.1f\", $warm_s}")s"
    fi

    competitors_block+="
| ${tool} | ${tool_version} | ${median_rounded}s | ${warm} |"
done < <(jq -c '.competitors[]' "$latest")

awk -v block="$competitors_block" '
  /<!-- COMPETITORS_RESULTS_START -->/ { print; print block; skip=1; next }
  /<!-- COMPETITORS_RESULTS_END -->/   { skip=0 }
  !skip
' "$README" > "${README}.tmp" && mv "${README}.tmp" "$README"

echo "→ README updated."
