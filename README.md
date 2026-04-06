# phparkitect Benchmark

Benchmark comparing performance across phparkitect versions using the [Symfony](https://github.com/symfony/symfony) codebase as test subject.

## Benchmark results

<!-- BENCHMARK_RESULTS_START -->
_Run: 2026-04-06T17:11:25Z — Symfony v7.2.0 — PHP 8.3.30 — 15 runs per version_

| Version | Median (s) | vs 0.8.0 |
|---------|------------|------------------------|
| main | 27.0 | +4.7% |
| 0.8.0 | 25.8 | baseline |
| 0.7.0 | 25.5 | -1.2% |
| 0.6.0 | 23.6 | -8.5% |
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
