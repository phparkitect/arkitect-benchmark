#!/usr/bin/env bash
set -euo pipefail

# ─── Configuration ────────────────────────────────────────────────────────────
SYMFONY_VERSION="v7.2.0"
SYMFONY_DIR="./symfony"
VERSIONS_DIR="./phparkitect-versions"
PHPAT_RUNNER_DIR="./phpat-runner"
RESULTS_DIR="./results"
RUNS="${RUNS:-15}"
GITHUB_API="https://api.github.com/repos/phparkitect/arkitect/releases"
ARKITECT_CONFIG="$(pwd)/arkitect.php"
PHPAT_TEST_SRC="$(pwd)/phpat/ArchitectureTest.php"

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

# ─── Setup composer.json for a phparkitect version ───────────────────────────
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

# ─── Setup phpat runner ───────────────────────────────────────────────────────
setup_phpat() {
    mkdir -p "$PHPAT_RUNNER_DIR"

    cat > "${PHPAT_RUNNER_DIR}/composer.json" <<'EOF'
{
    "require": {
        "phpat/phpat": "^0.10",
        "phpunit/phpunit": "^10"
    },
    "config": {
        "sort-packages": true
    }
}
EOF

    if [[ ! -d "${PHPAT_RUNNER_DIR}/vendor" ]]; then
        echo "  → Running composer install for phpat..."
        composer install \
            --working-dir="$PHPAT_RUNNER_DIR" \
            --no-interaction \
            --no-progress \
            --quiet
    else
        echo "  → vendor/ already exists for phpat, skipping composer install."
    fi

    # Generate phpunit.xml with the absolute path to Symfony src
    local abs_symfony_src
    abs_symfony_src="$(realpath "${SYMFONY_DIR}/src")"

    cat > "${PHPAT_RUNNER_DIR}/phpunit.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<phpunit xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:noNamespaceSchemaLocation="vendor/phpunit/phpunit/phpunit.xsd"
         bootstrap="vendor/autoload.php">
    <extensions>
        <bootstrap class="PHPat\PHPatExtension">
            <parameter name="src" value="${abs_symfony_src}"/>
        </bootstrap>
    </extensions>
    <testsuites>
        <testsuite name="architecture">
            <file>ArchitectureTest.php</file>
        </testsuite>
    </testsuites>
</phpunit>
EOF

    cp "$PHPAT_TEST_SRC" "${PHPAT_RUNNER_DIR}/ArchitectureTest.php"
}

# ─── Get installed phpat version ─────────────────────────────────────────────
phpat_version() {
    jq -r '.packages[] | select(.name == "phpat/phpat") | .version' \
        "${PHPAT_RUNNER_DIR}/vendor/composer/installed.json"
}

# ─── Run benchmark for one phparkitect version ───────────────────────────────
benchmark_version() {
    local version="$1"
    local dir="${VERSIONS_DIR}/${version}"
    local phparkitect_bin="${dir}/vendor/bin/phparkitect"
    local hf_json
    hf_json=$(mktemp /tmp/hf_XXXXXX.json)

    echo "  → Benchmarking phparkitect/${version} (warmup: 2, runs: ${RUNS})..." >&2
    export BENCHMARK_SRC_DIR="${SYMFONY_DIR}/src"

    hyperfine \
        --warmup 2 \
        --runs "$RUNS" \
        --ignore-failure \
        --export-json "$hf_json" \
        "${phparkitect_bin} check --config=${ARKITECT_CONFIG} >/dev/null 2>&1" \
        >&2

    _emit_result_json "phparkitect" "$version" "$hf_json"
    rm -f "$hf_json"
}

# ─── Run benchmark for phpat ─────────────────────────────────────────────────
benchmark_phpat() {
    local version="$1"
    local phpunit_bin="${PHPAT_RUNNER_DIR}/vendor/bin/phpunit"
    local hf_json
    hf_json=$(mktemp /tmp/hf_XXXXXX.json)

    echo "  → Benchmarking phpat/${version} (warmup: 2, runs: ${RUNS})..." >&2

    hyperfine \
        --warmup 2 \
        --runs "$RUNS" \
        --ignore-failure \
        --export-json "$hf_json" \
        "${phpunit_bin} --configuration=${PHPAT_RUNNER_DIR}/phpunit.xml >/dev/null 2>&1" \
        >&2

    _emit_result_json "phpat" "$version" "$hf_json"
    rm -f "$hf_json"
}

# ─── Emit result JSON fragment ────────────────────────────────────────────────
_emit_result_json() {
    local tool="$1"
    local version="$2"
    local hf_json="$3"

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

    printf '{"tool":"%s","version":"%s","runs_ms":[%s],"min_ms":%d,"max_ms":%d,"median_ms":%d,"median_s":"%s","spread_s":"%s"}' \
        "$tool" \
        "$version" \
        "$times_ms_json" \
        "$min_ms" "$max_ms" "$median_ms" "$median_s" "$stddev_s"
}

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
    check_deps

    mkdir -p "$VERSIONS_DIR" "$PHPAT_RUNNER_DIR" "$RESULTS_DIR"

    clone_symfony

    mapfile -t releases < <(fetch_releases)
    echo "→ Found releases: ${releases[*]}"

    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local php_version
    php_version=$(php -r 'echo PHP_VERSION;')
    local result_file="${RESULTS_DIR}/$(date -u +"%Y%m%dT%H%M%SZ").json"

    local results_json=""
    local sep=""

    # Benchmark phparkitect versions
    local versions=("${releases[@]}" "main")
    for version in "${versions[@]}"; do
        echo ""
        echo "=== phparkitect: ${version} ==="
        setup_version "$version"
        local fragment
        fragment=$(benchmark_version "$version")
        results_json+="${sep}${fragment}"
        sep=","
    done

    # Benchmark phpat
    echo ""
    echo "=== phpat ==="
    setup_phpat
    local phpat_ver
    phpat_ver=$(phpat_version)
    local fragment
    fragment=$(benchmark_phpat "$phpat_ver")
    results_json+="${sep}${fragment}"

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
