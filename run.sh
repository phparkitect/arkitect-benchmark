#!/usr/bin/env bash
set -euo pipefail

# ─── Configuration ────────────────────────────────────────────────────────────
SYMFONY_VERSION="v7.2.0"
SYMFONY_DIR="./symfony"
VERSIONS_DIR="./phparkitect-versions"
RESULTS_DIR="./results"
# Run-to-run noise between CI machines (σ ≈ 6%) dwarfs the noise between
# repetitions on one machine (σ ≈ 1%), so repetitions past a handful buy
# precision the result cannot keep.
RUNS="${RUNS:-5}"
GITHUB_API="https://api.github.com/repos/phparkitect/arkitect/releases"
ARKITECT_CONFIG="$(pwd)/arkitect.php"

# Cross-tool comparison: a subset of the rules every tool can express.
# See competitors/README.md.
COMPETITORS_DIR="./competitors"
DEPTRAC_DIR="${COMPETITORS_DIR}/deptrac"
CROSS_TOOL_CONFIG="$(pwd)/competitors/phparkitect/config.php"
EXPECTED_VIOLATIONS=29

# ─── Dependency check ─────────────────────────────────────────────────────────
check_deps() {
    local missing=()
    for cmd in php composer git curl jq hyperfine; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "ERROR: Missing dependencies: ${missing[*]}" >&2
        exit 1
    fi
}

# ─── Clone Symfony ────────────────────────────────────────────────────────────
clone_symfony() {
    if [[ -d "$SYMFONY_DIR/.git" ]]; then
        echo "→ Symfony already cloned, skipping."
        return
    fi
    echo "→ Cloning symfony/symfony@${SYMFONY_VERSION}..."
    git clone --depth=1 --branch "$SYMFONY_VERSION" \
        https://github.com/symfony/symfony.git "$SYMFONY_DIR"
}

# ─── Fetch latest 3 stable releases ──────────────────────────────────────────
fetch_releases() {
    echo "→ Fetching latest phparkitect releases..." >&2
    curl -sf "${GITHUB_API}?per_page=10" \
        | jq -r '[.[] | select(.prerelease == false and .draft == false) | .tag_name] | .[0:3] | .[]'
}

# ─── Setup composer.json for a version ───────────────────────────────────────
setup_version() {
    local version="$1"
    local dir="${VERSIONS_DIR}/${version}"
    mkdir -p "$dir"

    if [[ "$version" == "main" ]]; then
        cat > "${dir}/composer.json" <<'EOF'
{
    "minimum-stability": "dev",
    "prefer-stable": false,
    "require": {
        "phparkitect/phparkitect": "dev-main"
    },
    "config": {
        "sort-packages": true
    }
}
EOF
    else
        cat > "${dir}/composer.json" <<EOF
{
    "require": {
        "phparkitect/phparkitect": "${version}"
    },
    "config": {
        "sort-packages": true
    }
}
EOF
    fi

    if [[ -d "${dir}/vendor" ]]; then
        echo "  → vendor/ already exists for ${version}, skipping composer install."
        return
    fi

    echo "  → Running composer install for ${version}..."
    composer install \
        --working-dir="$dir" \
        --no-interaction \
        --no-progress \
        --quiet
}

# ─── Time one command, emit its stats as JSON object fields ──────────────────
# spread_s contains stddev (± 1σ)
measure() {
    local label="$1" command="$2"
    local hf_json
    hf_json=$(mktemp /tmp/hf_XXXXXX.json)

    echo "  → Benchmarking ${label} (warmup: 1, runs: ${RUNS})..." >&2

    hyperfine \
        --warmup 1 \
        --runs "$RUNS" \
        --ignore-failure \
        --export-json "$hf_json" \
        "$command" \
        >&2

    local median_raw stddev_raw min_raw max_raw times_ms_json
    median_raw=$(jq -r '.results[0].median' "$hf_json")
    stddev_raw=$(jq -r '.results[0].stddev' "$hf_json")
    min_raw=$(jq -r '.results[0].min' "$hf_json")
    max_raw=$(jq -r '.results[0].max' "$hf_json")
    times_ms_json=$(jq -r '[.results[0].times[] | . * 1000 | round] | join(",")' "$hf_json")

    local median_ms min_ms max_ms median_s stddev_s
    median_ms=$(awk "BEGIN {printf \"%d\", $median_raw * 1000}")
    min_ms=$(awk "BEGIN {printf \"%d\", $min_raw * 1000}")
    max_ms=$(awk "BEGIN {printf \"%d\", $max_raw * 1000}")
    median_s=$(awk "BEGIN {printf \"%.1f\", $median_raw}")
    stddev_s=$(awk "BEGIN {printf \"%.2f\", $stddev_raw}")

    rm -f "$hf_json"

    printf '"runs_ms":[%s],"min_ms":%d,"max_ms":%d,"median_ms":%d,"median_s":"%s","spread_s":"%s"' \
        "$times_ms_json" \
        "$min_ms" "$max_ms" "$median_ms" "$median_s" "$stddev_s"
}

# ─── Run benchmark for one version ───────────────────────────────────────────
benchmark_version() {
    local version="$1"
    local dir="${VERSIONS_DIR}/${version}"
    local phparkitect_bin="${dir}/vendor/bin/phparkitect"

    export BENCHMARK_SRC_DIR="${SYMFONY_DIR}/src"

    local stats
    stats=$(measure "$version" "${phparkitect_bin} check --config=${ARKITECT_CONFIG} >/dev/null 2>&1")

    printf '{"phparkitect_version":"%s",%s}' "$version" "$stats"
}

# ─── Correctness guard ───────────────────────────────────────────────────────
# A tool that silently runs no rules at all is fast. Assert the work happened
# before recording any timing for it.
assert_violations() {
    local tool="$1" actual="$2"

    if [[ "$actual" != "$EXPECTED_VIOLATIONS" ]]; then
        echo "ERROR: ${tool} reported '${actual}' violations, expected ${EXPECTED_VIOLATIONS}." >&2
        echo "       Refusing to publish a timing for a tool that is not doing the expected work." >&2
        echo "       If a Symfony upgrade changed this legitimately, update EXPECTED_VIOLATIONS." >&2
        exit 1
    fi
    echo "  → ${tool}: ${actual} violations (as expected)" >&2
}

count_violations_phparkitect() {
    local bin="$1"
    BENCHMARK_SRC_DIR="${SYMFONY_DIR}/src" "$bin" check --config="$CROSS_TOOL_CONFIG" 2>&1 \
        | grep -oP '\d+(?= violations detected)' | head -1
}

count_violations_deptrac() {
    # deptrac prints parsing errors before the JSON document
    "${DEPTRAC_DIR}/vendor/bin/deptrac" analyse \
        --config-file="${DEPTRAC_DIR}/depfile.yaml" \
        --no-cache --formatter=json --no-progress 2>/dev/null \
        | sed -n '/^{/,$p' | jq -r '.Report.Violations'
}

# Called from inside a command substitution — everything goes to stderr, or it
# ends up in the JSON.
setup_deptrac() {
    if [[ -d "${DEPTRAC_DIR}/vendor" ]]; then
        echo "  → vendor/ already exists for deptrac, skipping composer install." >&2
        return
    fi
    echo "  → Running composer install for deptrac..." >&2
    composer install \
        --working-dir="$DEPTRAC_DIR" \
        --no-interaction \
        --no-progress \
        --quiet
}

# ─── Cross-tool benchmark ────────────────────────────────────────────────────
# Compares released versions: main is a moving target, and the other tools are
# benchmarked at their latest stable too.
benchmark_competitors() {
    local ark_version="$1"
    local results=""

    echo "" >&2
    echo "=== Cross-tool: phparkitect ${ark_version} ===" >&2
    local bin="${VERSIONS_DIR}/${ark_version}/vendor/bin/phparkitect"
    assert_violations "phparkitect" "$(count_violations_phparkitect "$bin")"
    export BENCHMARK_SRC_DIR="${SYMFONY_DIR}/src"
    local stats
    stats=$(measure "phparkitect" "${bin} check --config=${CROSS_TOOL_CONFIG} >/dev/null 2>&1")
    results+="{\"tool\":\"phparkitect\",\"version\":\"${ark_version}\",\"violations\":${EXPECTED_VIOLATIONS},${stats}}"

    echo "" >&2
    echo "=== Cross-tool: deptrac ===" >&2
    setup_deptrac
    local deptrac_version
    deptrac_version=$("${DEPTRAC_DIR}/vendor/bin/deptrac" --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1)
    assert_violations "deptrac" "$(count_violations_deptrac)"
    # --no-cache: deptrac persists a cache file between processes and phparkitect
    # does not, so without it every run after the first would be timed warm.
    stats=$(measure "deptrac" "${DEPTRAC_DIR}/vendor/bin/deptrac analyse --config-file=${DEPTRAC_DIR}/depfile.yaml --no-cache --no-progress >/dev/null 2>&1")
    results+=",{\"tool\":\"deptrac\",\"version\":\"${deptrac_version}\",\"violations\":${EXPECTED_VIOLATIONS},${stats}}"

    printf '%s' "$results"
}

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
    check_deps

    mkdir -p "$VERSIONS_DIR" "$RESULTS_DIR"

    clone_symfony

    mapfile -t releases < <(fetch_releases)
    echo "→ Found releases: ${releases[*]}"

    local versions=("${releases[@]}" "main")
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local php_version
    php_version=$(php -r 'echo PHP_VERSION;')
    local result_file="${RESULTS_DIR}/$(date -u +"%Y%m%dT%H%M%SZ").json"

    local results_json=""
    local sep=""

    for version in "${versions[@]}"; do
        echo ""
        echo "=== Version: ${version} ==="
        setup_version "$version"
        local fragment
        fragment=$(benchmark_version "$version")
        results_json+="${sep}${fragment}"
        sep=","
    done

    local competitors_json
    competitors_json=$(benchmark_competitors "${releases[0]}")

    cat > "$result_file" <<EOF
{
  "date": "${timestamp}",
  "symfony_version": "${SYMFONY_VERSION}",
  "php_version": "${php_version}",
  "runs_per_version": ${RUNS},
  "results": [${results_json}],
  "competitors": [${competitors_json}]
}
EOF

    echo ""
    echo "=== Results written to: ${result_file} ==="
    cat "$result_file"
}

main
