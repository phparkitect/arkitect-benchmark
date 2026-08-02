# phparkitect Benchmark

Two benchmarks for [phparkitect](https://github.com/phparkitect/arkitect), each with its own subject:

- **Version history** — is phparkitect getting slower between releases? Measured over the [Symfony](https://github.com/symfony/symfony) source.
- **Compared to other tools** — how does it stand against deptrac and phpat? Measured over [Akeneo PIM](https://github.com/akeneo/pim-community-dev).

The two use different subjects, different rules and different configs. Their numbers are not comparable with each other.

## Version history

phparkitect's five latest releases plus `main`, all timed on the same machine in the same run.

<!-- BENCHMARK_RESULTS_START -->
_Filled in by the next CI run._
<!-- BENCHMARK_RESULTS_END -->

Compare figures within a single run only. Absolute seconds reflect whichever CI machine ran the benchmark: an unchanged release has been measured anywhere between 21.8s and 29.5s across different runs. Comparing versions against a baseline measured on the same machine cancels most of that, which is why the second row exists and the first is only there for scale.

Even that comparison has a floor: across 29 runs the same figure scattered by about ±3 percentage points, so anything smaller is reported as `≈` rather than as a number. A single run is never evidence of a regression; a trend across several is.

## Compared to other tools

A separate run measures phparkitect against other architecture-testing tools on one shared rule — *classes in `Akeneo\*\Domain` must not depend on Symfony* — over [Akeneo PIM](https://github.com/akeneo/pim-community-dev). Different subject, different config: these numbers are **not** comparable with the version table above.

The subject is an application rather than a framework monorepo on purpose. Frameworks ship classes that are valid only against one version of an optional dependency, which a reflection-based analyser cannot load at all.

<!-- COMPETITORS_RESULTS_START -->
_Run: 2026-08-02T11:59:02Z — Akeneo v2026.3 — PHP 8.3.33 — 5 runs per tool — one shared rule_

| Tool | Version | Cold | Warm cache |
|------|---------|------|------------|
| phparkitect | 1.3.0 | 7.3s | — *(no cache)* |
| deptrac | 4.7.1 | 9.3s | 2.4s |
| phpat | 0.11.10 | 46.7s | 2.2s |
<!-- COMPETITORS_RESULTS_END -->

Every tool is checked before it is timed: it must report the violations it is known to find on this codebase, or the run aborts rather than publish a figure. A tool that silently runs no rules at all would otherwise look very fast — which happened three separate times while this was being built.

**The warm column needs its own caveat.** It is the time when the tool's own cache survives from a previous run, which on CI only happens if the workflow restores it — a fresh checkout always pays the cold price. And for phpat it is the same cache that silently reported zero violations when a rule changed, since PHPStan keys it on the analysed files and phpat's rules live outside them. Fast, but not free.

The violation counts are not shown, because they would mislead. All three tools flag the same classes for the same reasons and disagree only on how many times to report one, so a higher number means a finer-grained report, not a better result. [competitors/akeneo/RULE.md](competitors/akeneo/RULE.md) has the rule and the numbers; [competitors/comparison.md](competitors/comparison.md) has what each tool turned out to be strong and weak at.

## How it works

1. Clones `symfony/symfony` and `akeneo/pim-community-dev`, both at a pinned tag. Akeneo also gets its `vendor/` installed, because phpat resolves dependencies through reflection and needs the analysed project's autoloader.
2. Fetches the 3 latest stable phparkitect releases plus `main`, and runs each over Symfony N times.
3. Runs phparkitect, deptrac and phpat over Akeneo on one shared rule, cold and with a warm cache, asserting each tool's violation count before timing it.

Results are updated automatically every day when new commits are pushed to `phparkitect/arkitect` main.

## Running locally

```bash
bash run.sh            # run benchmark, writes results/<timestamp>.json
bash update-readme.sh  # update this README with the latest results
```
