# phparkitect Benchmark

Benchmark comparing performance across phparkitect versions using the [Symfony](https://github.com/symfony/symfony) codebase as test subject.

## Benchmark results

<!-- BENCHMARK_RESULTS_START -->
_Run: 2026-08-02T11:21:18Z — Symfony v7.2.0 — PHP 8.3.33 — 5 runs per version_

| Version | Median | vs 1.3.0 |
|---------|--------|------------------------|
| main | 21.5s | +0.0% |
| 1.3.0 | 21.5s | baseline |
| 1.2.0 | 21.6s | +0.5% |
| 1.1.1 | 21.8s | +1.4% |
<!-- BENCHMARK_RESULTS_END -->

Compare figures within a single run only. Absolute seconds reflect whichever CI machine ran the benchmark: an unchanged release has been measured anywhere between 21.8s and 29.5s across runs. The ratio column cancels most of that, since every version in a run is timed on the same machine, but it still carries a noise floor of roughly ±3 percentage points — a single run showing main a few percent slower is not evidence of a regression, only a trend across several runs is.

## Compared to other tools

A separate run measures phparkitect against other architecture-testing tools on one shared rule — *classes in `Akeneo\*\Domain` must not depend on Symfony* — over [Akeneo PIM](https://github.com/akeneo/pim-community-dev). Different subject, different config: these numbers are **not** comparable with the version table above.

The subject is an application rather than a framework monorepo on purpose. Frameworks ship classes that are valid only against one version of an optional dependency, which a reflection-based analyser cannot load at all.

<!-- COMPETITORS_RESULTS_START -->
_Run: 2026-08-02T11:21:18Z — Akeneo v2026.3 — PHP 8.3.33 — 5 runs per tool — one shared rule_

| Tool | Version | Median |
|------|---------|--------|
| phparkitect | 1.3.0 | 5.7s |
| deptrac | 4.7.1 | 7.5s |
| phpat | 0.11.10 | 43.1s |
<!-- COMPETITORS_RESULTS_END -->

Every tool is checked before it is timed: it must report the violations it is known to find on this codebase, or the run aborts rather than publish a figure. A tool that silently runs no rules at all would otherwise look very fast — which happened three separate times while this was being built.

The counts themselves are not shown, because they would mislead. All three tools flag the same classes for the same reasons and disagree only on how many times to report one, so a higher number means a finer-grained report, not a better result. [competitors/akeneo/RULE.md](competitors/akeneo/RULE.md) has the rule and the numbers; [competitors/comparison.md](competitors/comparison.md) has what each tool turned out to be strong and weak at.

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
