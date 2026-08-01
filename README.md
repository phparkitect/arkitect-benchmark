# phparkitect Benchmark

Benchmark comparing performance across phparkitect versions using the [Symfony](https://github.com/symfony/symfony) codebase as test subject.

## Benchmark results

<!-- BENCHMARK_RESULTS_START -->
_Run: 2026-08-01T22:06:42Z — Symfony v7.2.0 — PHP 8.3.33 — 5 runs per version_

| Version | Median (s) | vs 1.3.0 |
|---------|------------|------------------------|
| main | 28.1 | +2.6% |
| 1.3.0 | 27.4 | baseline |
| 1.2.0 | 27.1 | -1.1% |
| 1.1.1 | 27.9 | +1.8% |
<!-- BENCHMARK_RESULTS_END -->

Compare figures within a single run only. Absolute seconds reflect whichever CI machine ran the benchmark: an unchanged release has been measured anywhere between 21.8s and 29.5s across runs. The ratio column cancels most of that, since every version in a run is timed on the same machine, but it still carries a noise floor of roughly ±3 percentage points — a single run showing main a few percent slower is not evidence of a regression, only a trend across several runs is.

## Compared to other tools

A separate run measures phparkitect against other architecture-testing tools on the three rules all of them can express. It uses its own config, so these numbers are **not** comparable with the version table above.

<!-- COMPETITORS_RESULTS_START -->
_Run: 2026-08-01T22:06:42Z — Symfony v7.2.0 — PHP 8.3.33 — 5 runs per tool — 3 shared rules, 29 violations found by each_

| Tool | Version | Median (s) |
|------|---------|------------|
| phparkitect | 1.3.0 | 27.4 |
| deptrac | 4.7.1 | 31.4 |
<!-- COMPETITORS_RESULTS_END -->

Each tool's violation count is asserted before it is timed — a tool that runs no rules at all would otherwise look fast. See [competitors/README.md](competitors/README.md) for the rule equivalence, the rules that have no counterpart in every tool, and why phpat and Pest arch are not in the table yet.

## How it works

The benchmark:
1. Clones `symfony/symfony` at a pinned tag
2. Fetches the 3 latest stable phparkitect releases + `main`
3. Runs `phparkitect check` N times per version and records median and spread
4. Runs each tool on the shared rule subset and records the same figures

Results are updated automatically every day when new commits are pushed to `phparkitect/arkitect` main.

## Running locally

```bash
bash run.sh            # run benchmark, writes results/<timestamp>.json
bash update-readme.sh  # update this README with the latest results
```
