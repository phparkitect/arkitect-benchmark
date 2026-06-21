# phparkitect Benchmark

Benchmark comparing performance across phparkitect versions using the [Symfony](https://github.com/symfony/symfony) codebase as test subject.

## Benchmark results

<!-- BENCHMARK_RESULTS_START -->
_Run: 2026-06-21T04:07:21Z — Symfony v7.2.0 — PHP 8.3.31 — 15 runs per version_

| Version | Median (s) | vs 1.1.1 |
|---------|------------|------------------------|
| main | 27.7 | -1.4% |
| 1.1.1 | 28.1 | baseline |
| 1.1.0 | 27.5 | -2.1% |
| 1.0.0 | 27.7 | -1.4% |
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
