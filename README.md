# phparkitect Benchmark

Benchmark comparing performance across phparkitect versions using the [Symfony](https://github.com/symfony/symfony) codebase as test subject.

## Benchmark results

<!-- BENCHMARK_RESULTS_START -->
_Run: 2026-03-01T21:13:59Z — Symfony v7.2.0 — PHP 8.3.30 — 3 runs per version_

| Version | Min (ms) | Median (ms) | Max (ms) |
|---------|----------|-------------|----------|
| 0.8.0 | 26240 | 26344 | 26443 |
| 0.7.0 | 25986 | 26068 | 26115 |
| 0.6.0 | 24121 | 24259 | 24296 |
| main | 28005 | 28082 | 28418 |
<!-- BENCHMARK_RESULTS_END -->

## How it works

The benchmark:
1. Clones `symfony/symfony` at a pinned tag
2. Fetches the 3 latest stable phparkitect releases + `main`
3. Runs `phparkitect check` N times per version and records median and spread

Results are updated automatically on every CI run.

## Running locally

```bash
bash run.sh            # run benchmark, writes results/<timestamp>.json
bash update-readme.sh  # update this README with the latest results
```
