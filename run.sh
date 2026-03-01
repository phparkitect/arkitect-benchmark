#!/usr/bin/env bash
set -euo pipefail

# ─── Configuration ────────────────────────────────────────────────────────────
SYMFONY_VERSION="v7.2.0"
SYMFONY_DIR="./symfony"
VERSIONS_DIR="./phparkitect-versions"
RESULTS_DIR="./results"
RUNS="${RUNS:-3}"
GITHUB_API="https://api.github.com/repos/phparkitect/arkitect/releases"
ARKITECT_CONFIG="$(pwd)/arkitect.php"

# ─── Dependency check ─────────────────────────────────────────────────────────
check_deps() {
    local missing=()
    for cmd in php composer git curl jq; do
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

# ─── Median of N numbers ──────────────────────────────────────────────────────
median() {
    local arr=("$@")
    local count=${#arr[@]}
    # Sort numerically
    IFS=$'\n' sorted=($(sort -n <<< "${arr[*]}")); unset IFS
    local mid=$(( count / 2 ))
    if (( count % 2 == 1 )); then
        echo "${sorted[$mid]}"
    else
        echo $(( (sorted[mid-1] + sorted[mid]) / 2 ))
    fi
}

# ─── min / max ────────────────────────────────────────────────────────────────
array_min() {
    local min=$1; shift
    for v in "$@"; do (( v < min )) && min=$v; done
    echo "$min"
}

array_max() {
    local max=$1; shift
    for v in "$@"; do (( v > max )) && max=$v; done
    echo "$max"
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
    local runs_ms=()

    echo "  → Benchmarking ${version} (${RUNS} runs)..." >&2
    export BENCHMARK_SRC_DIR="${SYMFONY_DIR}/src"

    for (( i=1; i<=RUNS; i++ )); do
        local t_start t_end elapsed
        t_start=$(date +%s%3N)
        "$phparkitect_bin" check --config="$ARKITECT_CONFIG" \
            >/dev/null 2>&1 || true
        t_end=$(date +%s%3N)
        elapsed=$(( t_end - t_start ))
        runs_ms+=("$elapsed")
        echo "    run ${i}: ${elapsed} ms" >&2
    done

    local min max med
    min=$(array_min "${runs_ms[@]}")
    max=$(array_max "${runs_ms[@]}")
    med=$(median "${runs_ms[@]}")

    # Emit JSON fragment (collected by caller via substitution)
    printf '{"phparkitect_version":"%s","runs_ms":[%s],"min_ms":%d,"max_ms":%d,"median_ms":%d}' \
        "$version" \
        "$(IFS=,; echo "${runs_ms[*]}")" \
        "$min" "$max" "$med"
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
