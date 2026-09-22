#!/usr/bin/env bash
set -euo pipefail

# ─── Configuration ────────────────────────────────────────────────────────────
SYMFONY_VERSION="v7.2.0"
SYMFONY_DIR="./symfony"
VERSIONS_DIR="./phparkitect-versions"
RESULTS_DIR="./results"
# Rounds per version. The version history interleaves them — every round runs
# each version once, in a shuffled order — so a CI machine that slows down
# halfway through slows down every version, instead of whichever one happened
# to be running at the time.
RUNS="${RUNS:-5}"
GITHUB_API="https://api.github.com/repos/phparkitect/arkitect/releases"
ARKITECT_CONFIG="$(pwd)/arkitect.php"

# Cross-tool comparison: one rule, three tools. See competitors/README.md.
COMPETITORS_DIR="./competitors"
DEPTRAC_DIR="${COMPETITORS_DIR}/deptrac"
PHPAT_DIR="${COMPETITORS_DIR}/phpat"
CROSS_TOOL_CONFIG="$(pwd)/competitors/phparkitect/config.php"

# Cross-tool subject: an application, not a framework monorepo. See
# competitors/comparison.md for why that distinction decides what can run here.
AKENEO_VERSION="v2026.3"
AKENEO_DIR="./akeneo"

# One rule, three tools, three counting models — see competitors/akeneo/RULE.md.
# These are per-tool on purpose; forcing them to agree would mean weakening one.
EXPECTED_PHPARKITECT=14
EXPECTED_PHPAT=20
EXPECTED_DEPTRAC=32

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

# ─── Clone the cross-tool subject ────────────────────────────────────────────
# phpat needs the analysed project's autoloader, so this one needs its vendor/
# installed too — unlike the version-history subject.
clone_akeneo() {
    if [[ ! -d "$AKENEO_DIR/.git" ]]; then
        echo "→ Cloning akeneo/pim-community-dev@${AKENEO_VERSION}..."
        git clone --depth=1 --branch "$AKENEO_VERSION" \
            https://github.com/akeneo/pim-community-dev.git "$AKENEO_DIR"
    else
        echo "→ Akeneo already cloned, skipping."
    fi

    if [[ -d "$AKENEO_DIR/vendor" ]]; then
        echo "→ Akeneo vendor/ already installed, skipping."
        return
    fi
    echo "→ Installing Akeneo dependencies..."
    # The benchmark never boots the app, it only reads the files, so the
    # platform requirements of a PIM do not have to be satisfied here.
    composer install \
        --working-dir="$AKENEO_DIR" \
        --no-interaction --no-progress --no-scripts \
        --ignore-platform-reqs --quiet
}

# ─── Fetch latest 5 stable releases ──────────────────────────────────────────
# Anonymous API calls share a 60/hour limit per IP, and CI runners share IPs:
# authenticate when a token is available.
fetch_releases() {
    echo "→ Fetching latest phparkitect releases..." >&2
    local auth=()
    [[ -n "${GITHUB_TOKEN:-}" ]] && auth=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
    curl -sSf "${auth[@]}" "${GITHUB_API}?per_page=10" \
        | jq -r '[.[] | select(.prerelease == false and .draft == false) | .tag_name] | .[0:5] | .[]'
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
    local label="$1" command="$2" prepare="${3:-}"
    local hf_json
    hf_json=$(mktemp /tmp/hf_XXXXXX.json)

    echo "  → Benchmarking ${label} (warmup: 1, runs: ${RUNS})..." >&2

    local prepare_args=()
    [[ -n "$prepare" ]] && prepare_args=(--prepare "$prepare")

    hyperfine \
        --warmup 1 \
        --runs "$RUNS" \
        --ignore-failure \
        "${prepare_args[@]}" \
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

# ─── Version history: interleaved rounds ─────────────────────────────────────
# Timing each version's repetitions back to back attributed the CI machine's
# drift to the versions: unchanged releases moved by up to 20 points against the
# baseline between runs. Here every round times every version once, in a fresh
# random order, and the versions are compared round by round.
time_once_ms() {
    local start end
    start=$(date +%s%N)
    # phparkitect exits non-zero when it finds violations; that is still a run.
    bash -c "$1" >/dev/null 2>&1 || true
    end=$(date +%s%N)
    echo $(( (end - start) / 1000000 ))
}

benchmark_versions() {
    local versions=("$@")
    local -A commands times
    local version round ms

    export BENCHMARK_SRC_DIR="${SYMFONY_DIR}/src"

    for version in "${versions[@]}"; do
        commands[$version]="${VERSIONS_DIR}/${version}/vendor/bin/phparkitect check --config=${ARKITECT_CONFIG}"
        times[$version]=""
    done

    echo "  → Warmup: one untimed run per version..." >&2
    for version in "${versions[@]}"; do
        time_once_ms "${commands[$version]}" >/dev/null
    done

    local orders=""
    for (( round = 1; round <= RUNS; round++ )); do
        local order
        mapfile -t order < <(printf '%s\n' "${versions[@]}" | shuf)
        echo "  → Round ${round}/${RUNS}: ${order[*]}" >&2
        for version in "${order[@]}"; do
            ms=$(time_once_ms "${commands[$version]}")
            times[$version]+="${times[$version]:+,}${ms}"
        done
        orders+="${orders:+,}$(printf '%s\n' "${order[@]}" | jq -R . | jq -sc .)"
    done

    # runs_ms[i] of every version comes from the same round i, so they pair up.
    local sep=""
    printf '"rounds_order":[%s],"results":[' "$orders"
    for version in "${versions[@]}"; do
        printf '%s%s' "$sep" "$(jq -nc --arg v "$version" --argjson t "[${times[$version]}]" '
            ($t | sort) as $s
            | ($s | length) as $n
            | (if $n % 2 == 1 then $s[($n - 1) / 2] else ($s[$n / 2 - 1] + $s[$n / 2]) / 2 end) as $median
            | {phparkitect_version: $v, runs_ms: $t, min_ms: $s[0], max_ms: $s[-1],
               median_ms: ($median | floor), median_s: (($median / 100 | round) / 10 | tostring)}')"
        sep=","
    done
    printf ']'
}

# ─── Correctness guard ───────────────────────────────────────────────────────
# A tool that silently runs no rules at all is fast. Assert the work happened
# before recording any timing for it.
assert_violations() {
    local tool="$1" actual="$2" expected="$3"

    if [[ "$actual" != "$expected" ]]; then
        echo "ERROR: ${tool} reported '${actual}' violations, expected ${expected}." >&2
        echo "       Refusing to publish a timing for a tool that is not doing the expected work." >&2
        echo "       If an Akeneo upgrade changed this legitimately, update the EXPECTED_* value." >&2
        exit 1
    fi
    echo "  → ${tool}: ${actual} violations (as expected)" >&2
}

count_violations_phparkitect() {
    local bin="$1"
    CROSS_TOOL_SRC_DIR="${AKENEO_DIR}/src" "$bin" check --config="$CROSS_TOOL_CONFIG" 2>&1 \
        | grep -oP '\d+(?= violations detected)' | head -1
}

# PHPStan's result cache does not know that phpat's rules live outside the
# analysed paths, so a stale cache reports zero violations for a rule that has
# changed. Clear it before counting, and before every timed repetition.
count_violations_phpat() {
    "${PHPAT_DIR}/vendor/bin/phpstan" clear-result-cache \
        -c "${PHPAT_DIR}/phpstan.neon" >/dev/null 2>&1
    "${PHPAT_DIR}/vendor/bin/phpstan" analyse \
        -c "${PHPAT_DIR}/phpstan.neon" \
        --no-progress --memory-limit=-1 --error-format=json 2>/dev/null \
        | jq -r '[.files[].messages[] | select(.identifier | tostring | test("phpat"))] | length'
}

setup_phpat() {
    if [[ -d "${PHPAT_DIR}/vendor" ]]; then
        echo "  → vendor/ already exists for phpat, skipping composer install." >&2
        return
    fi
    echo "  → Running composer install for phpat..." >&2
    composer install \
        --working-dir="$PHPAT_DIR" \
        --no-interaction --no-progress --quiet
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

    export CROSS_TOOL_SRC_DIR="${AKENEO_DIR}/src"

    echo "" >&2
    echo "=== Cross-tool: phparkitect ${ark_version} ===" >&2
    local bin="${VERSIONS_DIR}/${ark_version}/vendor/bin/phparkitect"
    assert_violations "phparkitect" "$(count_violations_phparkitect "$bin")" "$EXPECTED_PHPARKITECT"
    local stats
    stats=$(measure "phparkitect" "${bin} check --config=${CROSS_TOOL_CONFIG} >/dev/null 2>&1")
    # No cross-process cache to warm, so there is no second figure to report.
    results+="{\"tool\":\"phparkitect\",\"version\":\"${ark_version}\",\"violations\":${EXPECTED_PHPARKITECT},\"median_warm_s\":null,${stats}}"

    echo "" >&2
    echo "=== Cross-tool: deptrac ===" >&2
    setup_deptrac
    local deptrac_version
    deptrac_version=$("${DEPTRAC_DIR}/vendor/bin/deptrac" --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1)
    assert_violations "deptrac" "$(count_violations_deptrac)" "$EXPECTED_DEPTRAC"
    # --no-cache: deptrac persists a cache file between processes and phparkitect
    # does not, so without it every run after the first would be timed warm.
    stats=$(measure "deptrac (cold)" "${DEPTRAC_DIR}/vendor/bin/deptrac analyse --config-file=${DEPTRAC_DIR}/depfile.yaml --no-cache --no-progress >/dev/null 2>&1")
    # Warm: same command with its cache left in place, populated by the warmup run.
    local warm
    warm=$(measure "deptrac (warm)" "${DEPTRAC_DIR}/vendor/bin/deptrac analyse --config-file=${DEPTRAC_DIR}/depfile.yaml --no-progress >/dev/null 2>&1" \
        | grep -oP '"median_s":"\K[^"]+')
    results+=",{\"tool\":\"deptrac\",\"version\":\"${deptrac_version}\",\"violations\":${EXPECTED_DEPTRAC},\"median_warm_s\":\"${warm}\",${stats}}"

    echo "" >&2
    echo "=== Cross-tool: phpat ===" >&2
    setup_phpat
    local phpat_version
    phpat_version=$(composer show --working-dir="$PHPAT_DIR" --format=json phpat/phpat 2>/dev/null \
        | jq -r '.versions[0]' | sed 's/^v//')
    assert_violations "phpat" "$(count_violations_phpat)" "$EXPECTED_PHPAT"
    # Cleared before every repetition, so phpat is timed cold like the others.
    stats=$(measure "phpat" \
        "${PHPAT_DIR}/vendor/bin/phpstan analyse -c ${PHPAT_DIR}/phpstan.neon --no-progress --memory-limit=-1 >/dev/null 2>&1" \
        "${PHPAT_DIR}/vendor/bin/phpstan clear-result-cache -c ${PHPAT_DIR}/phpstan.neon >/dev/null 2>&1")
    # Warm: no clearing, so every repetition after the warmup reuses the cache.
    warm=$(measure "phpat (warm)" \
        "${PHPAT_DIR}/vendor/bin/phpstan analyse -c ${PHPAT_DIR}/phpstan.neon --no-progress --memory-limit=-1 >/dev/null 2>&1" \
        | grep -oP '"median_s":"\K[^"]+')
    results+=",{\"tool\":\"phpat\",\"version\":\"${phpat_version}\",\"violations\":${EXPECTED_PHPAT},\"median_warm_s\":\"${warm}\",${stats}}"

    printf '%s' "$results"
}

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
    check_deps

    mkdir -p "$VERSIONS_DIR" "$RESULTS_DIR"

    clone_symfony
    clone_akeneo

    mapfile -t releases < <(fetch_releases)
    # Without releases there is no baseline to compare against.
    if [[ ${#releases[@]} -eq 0 ]]; then
        echo "ERROR: Could not fetch phparkitect releases from ${GITHUB_API}." >&2
        exit 1
    fi
    echo "→ Found releases: ${releases[*]}"

    local versions=("${releases[@]}" "main")
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local php_version
    php_version=$(php -r 'echo PHP_VERSION;')
    local result_file="${RESULTS_DIR}/$(date -u +"%Y%m%dT%H%M%SZ").json"

    for version in "${versions[@]}"; do
        echo ""
        echo "=== Setup: ${version} ==="
        setup_version "$version"
    done

    echo ""
    echo "=== Version history: ${#versions[@]} versions, ${RUNS} interleaved rounds ==="
    local history_json
    history_json=$(benchmark_versions "${versions[@]}")

    local competitors_json
    competitors_json=$(benchmark_competitors "${releases[0]}")

    cat > "$result_file" <<EOF
{
  "date": "${timestamp}",
  "symfony_version": "${SYMFONY_VERSION}",
  "akeneo_version": "${AKENEO_VERSION}",
  "php_version": "${php_version}",
  "runs_per_version": ${RUNS},
  "method": "interleaved",
  ${history_json},
  "competitors": [${competitors_json}]
}
EOF

    echo ""
    echo "=== Results written to: ${result_file} ==="
    cat "$result_file"
}

main
