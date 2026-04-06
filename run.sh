#!/usr/bin/env bash
set -euo pipefail

# ─── Configuration ────────────────────────────────────────────────────────────
SYMFONY_VERSION="v7.2.0"
SYMFONY_DIR="./symfony"
VERSIONS_DIR="./phparkitect-versions"
RESULTS_DIR="./results"
RUNS="${RUNS:-15}"
GITHUB_API="https://api.github.com/repos/phparkitect/arkitect/releases"
ARKITECT_CONFIG="$(pwd)/arkitect.php"

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

# ─── Run benchmark for one version ───────────────────────────────────────────
benchmark_version() {
    local version="$1"
    local dir="${VERSIONS_DIR}/${version}"
    local phparkitect_bin="${dir}/vendor/bin/phparkitect"
    local hf_json
    hf_json=$(mktemp /tmp/hf_XXXXXX.json)

    echo "  → Benchmarking ${version} (warmup: 2, runs: ${RUNS})..." >&2
    export BENCHMARK_SRC_DIR="${SYMFONY_DIR}/src"

    hyperfine \
        --warmup 2 \
        --runs "$RUNS" \
        --ignore-failure \
        --export-json "$hf_json" \
        "${phparkitect_bin} check --config=${ARKITECT_CONFIG} >/dev/null 2>&1" \
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

    # Emit JSON fragment (collected by caller via substitution)
    # spread_s contains stddev (± 1σ)
    printf '{"phparkitect_version":"%s","runs_ms":[%s],"min_ms":%d,"max_ms":%d,"median_ms":%d,"median_s":"%s","spread_s":"%s"}' \
        "$version" \
        "$times_ms_json" \
        "$min_ms" "$max_ms" "$median_ms" "$median_s" "$stddev_s"
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

    cat > "$result_file" <<EOF
{
  "date": "${timestamp}",
  "symfony_version": "${SYMFONY_VERSION}",
  "php_version": "${php_version}",
  "runs_per_version": ${RUNS},
  "results": [${results_json}]
}
EOF

    echo ""
    echo "=== Results written to: ${result_file} ==="
    cat "$result_file"
}

main
