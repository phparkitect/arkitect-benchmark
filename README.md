# phparkitect Benchmark

Benchmark comparing performance across phparkitect versions using the [Symfony](https://github.com/symfony/symfony) codebase as test subject.

## Benchmark results

<!-- BENCHMARK_RESULTS_START -->
_Run: 2026-03-14T01:58:02Z — Symfony v7.2.0 — PHP 8.3.30 — 5 runs per version_

| Version | Median (s) | Spread |
|---------|------------|--------|
| main | 29.98 | ± 0.84 |
| 0.8.0 | 29.29 | ± 0.31 |
| 0.7.0 | 27.91 | ± 0.70 |
| 0.6.0 | 25.42 | ± 0.43 |
<!-- BENCHMARK_RESULTS_END -->

## How it works

The benchmark:
1. Clones `symfony/symfony` at a pinned tag
2. Fetches the 3 latest stable phparkitect releases + `main`
3. Runs `phparkitect check` N times per version and records median and spread

Results are updated automatically every day when new commits are pushed to `phparkitect/arkitect` main.

## Running locally

```bash
bash run.sh            # run benchmark, writes results/<timestamp>.json
bash update-readme.sh  # update this README with the latest results
```
