# phparkitect Benchmark

Benchmark comparing phparkitect performance across versions and against competitors, using the [Symfony](https://github.com/symfony/symfony) codebase as test subject.

## Benchmark results

### phparkitect version history

<!-- BENCHMARK_RESULTS_START -->
_Run: 2026-04-28T02:49:40Z — Symfony v7.2.0 — PHP 8.3.30 — 15 runs per version_

| Version | Median (s) | vs 1.0.0 |
|---------|------------|------------------------|
| main | 24.5 | -2.4% |
| 1.0.0 | 25.1 | baseline |
| 0.8.0 | 23.7 | -5.6% |
| 0.7.0 | 23.6 | -6.0% |
<!-- BENCHMARK_RESULTS_END -->

### vs competitors

> **Note:** phpat runs via PHPUnit — its time includes PHPUnit startup overhead (~1–2 s).
> Rules are best-effort equivalent (3 of 4); the naming-convention rule has no direct phpat counterpart and is omitted.

<!-- COMPETITOR_RESULTS_START -->
<!-- COMPETITOR_RESULTS_END -->

## How it works

The benchmark:
1. Clones `symfony/symfony` at a pinned tag
2. Fetches the 3 latest stable phparkitect releases + `main`
3. Also installs the latest stable `phpat/phpat` release
4. Runs each tool N times and records the median

Results are updated automatically every day when new commits are pushed to `phparkitect/arkitect` main.

## Running locally

```bash
bash run.sh            # run benchmark, writes results/<timestamp>.json
bash update-readme.sh  # update this README with the latest results
```
