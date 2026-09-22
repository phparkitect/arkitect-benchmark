# phparkitect Benchmark

Two benchmarks for [phparkitect](https://github.com/phparkitect/arkitect), with different subjects and configs — their numbers are not comparable with each other.

## Version history

Is phparkitect getting slower between releases? The five latest releases plus `main`, timed over the [Symfony](https://github.com/symfony/symfony) source in the same CI job.

<!-- BENCHMARK_RESULTS_START -->
_Run: 2026-09-22T21:04:55Z — Symfony v7.2.0 — PHP 8.3.33 — 5 interleaved rounds_

|  | main | 1.3.1 | 1.3.0 | 1.2.0 | 1.1.1 | 1.1.0 |
|---|---|---|---|---|---|---|
| **Median** | 26.8s | 27.1s | 26.7s | 26.5s | 27.1s | 27.0s |
| **vs 1.3.1** | ≈ | baseline | ≈ | ≈ | ≈ | ≈ |

_Difference from 1.3.1, measured round by round. ≈ means no reproducible difference: under 2%, or too few rounds agreed on the direction._
<!-- BENCHMARK_RESULTS_END -->

Read the second row. The seconds depend on which CI machine ran the job, while the round-by-round comparison cancels that out. One run is not evidence of a regression; a trend across several is, and every run's raw timings are kept in [`results/`](results/). [How it is measured, and why](docs/methodology.md).

## Compared to other tools

phparkitect against deptrac and phpat, on one shared rule — *classes in `Akeneo\*\Domain` must not depend on Symfony* — over [Akeneo PIM](https://github.com/akeneo/pim-community-dev).

<!-- COMPETITORS_RESULTS_START -->
_Run: 2026-09-22T21:04:55Z — Akeneo v2026.3 — PHP 8.3.33 — 5 runs per tool — one shared rule_

| Tool | Version | Cold | Warm cache |
|------|---------|------|------------|
| phparkitect | 1.3.1 | 7.2s | — *(no cache)* |
| deptrac | 4.7.2 | 9.0s | 2.4s |
| phpat | 0.11.10 | 35.2s | 2.6s |
<!-- COMPETITORS_RESULTS_END -->

Each tool must report the violations it is known to find before it is timed, or the run aborts. *Warm cache* only applies if the tool's cache survives between runs, which on CI it does not by default. Details on the subject, the rule and each tool in [competitors/](competitors/README.md).

## Running locally

```bash
bash run.sh            # writes results/<timestamp>.json
RUNS=10 bash run.sh    # more rounds: slower, but detects smaller differences
bash update-readme.sh  # renders the latest result into this README
```

Runs on CI daily when `phparkitect/arkitect` main has new commits, and on every push to this repository's main that changes more than Markdown.
