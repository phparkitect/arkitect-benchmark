# phparkitect Benchmark

Benchmark comparing performance across phparkitect versions using the [Symfony](https://github.com/symfony/symfony) codebase as test subject.

## How it works

The benchmark:
1. Clones `symfony/symfony` at a pinned tag
2. Fetches the 3 latest stable phparkitect releases + `main`
3. Runs `phparkitect check` N times per version and records min / median / max

Results are updated automatically on every CI run.

## Running locally

```bash
bash run.sh            # run benchmark, writes results/<timestamp>.json
bash update-readme.sh  # update this README with the latest results
```

## Benchmark results

<!-- BENCHMARK_RESULTS_START -->
_Run: 2026-03-01T20:51:11Z — Symfony v7.2.0 — PHP 8.4.18 — 3 runs per version_

| Version | Min (ms) | Median (ms) | Max (ms) |
|---------|----------|-------------|----------|
| 0.8.0 | 28814 | 30754 | 32204 |
| 0.7.0 | 30229 | 31047 | 35622 |
| 0.6.0 | 31091 | 33674 | 36463 |
| main | 35003 | 37354 | 37749 |
<!-- BENCHMARK_RESULTS_END -->
