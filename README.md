# phparkitect Benchmark

Two benchmarks for [phparkitect](https://github.com/phparkitect/arkitect), with different subjects and configs — their numbers are not comparable with each other.

## Version history

Is phparkitect getting slower between releases? The five latest releases plus `main`, timed over the [Symfony](https://github.com/symfony/symfony) source in the same CI job.

<!-- BENCHMARK_RESULTS_START -->
_Run: 2026-09-22T20:18:51Z — Symfony v7.2.0 — PHP 8.3.33 — 5 interleaved rounds_

|  | main | 1.3.1 | 1.3.0 | 1.2.0 | 1.1.1 | 1.1.0 |
|---|---|---|---|---|---|---|
| **Median** | 28.9s | 27.5s | 28.0s | 27.4s | 27.9s | 28.0s |
| **vs 1.3.1** | ≈ | baseline | ≈ | ≈ | ≈ | ≈ |

_Difference from 1.3.1, measured round by round. ≈ means too few rounds agreed on the direction to call it a difference._
<!-- BENCHMARK_RESULTS_END -->

Read the second row. The seconds depend on which CI machine ran the job, while the round-by-round comparison cancels that out. One run is not evidence of a regression; a trend across several is, and every run's raw timings are kept in [`results/`](results/). [How it is measured, and why](docs/methodology.md).

## Compared to other tools

phparkitect against deptrac and phpat, on one shared rule — *classes in `Akeneo\*\Domain` must not depend on Symfony* — over [Akeneo PIM](https://github.com/akeneo/pim-community-dev).

<!-- COMPETITORS_RESULTS_START -->
_Run: 2026-09-22T20:18:51Z — Akeneo v2026.3 — PHP 8.3.33 — 5 runs per tool — one shared rule_

| Tool | Version | Cold | Warm cache |
|------|---------|------|------------|
| phparkitect | 1.3.1 | 7.3s | — *(no cache)* |
| deptrac | 4.7.2 | 9.4s | 2.5s |
| phpat | 0.11.10 | 37.3s | 2.7s |
<!-- COMPETITORS_RESULTS_END -->

Each tool must report the violations it is known to find before it is timed, or the run aborts. *Warm cache* only applies if the tool's cache survives between runs, which on CI it does not by default. Details on the subject, the rule and each tool in [competitors/](competitors/README.md).

## Running locally

```bash
bash run.sh            # writes results/<timestamp>.json
RUNS=10 bash run.sh    # more rounds: slower, but detects smaller differences
bash update-readme.sh  # renders the latest result into this README
```

Runs daily on CI when `phparkitect/arkitect` main has new commits.
