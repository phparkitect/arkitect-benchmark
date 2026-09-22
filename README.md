# phparkitect Benchmark

Two benchmarks for [phparkitect](https://github.com/phparkitect/arkitect), each with its own subject:

- **Version history** — is phparkitect getting slower between releases? Measured over the [Symfony](https://github.com/symfony/symfony) source.
- **Compared to other tools** — how does it stand against deptrac and phpat? Measured over [Akeneo PIM](https://github.com/akeneo/pim-community-dev).

The two use different subjects, different rules and different configs. Their numbers are not comparable with each other.

## Version history

phparkitect's five latest releases plus `main`, all timed on the same machine in the same run.

<!-- BENCHMARK_RESULTS_START -->
_Run: 2026-09-22T20:18:51Z — Symfony v7.2.0 — PHP 8.3.33 — 5 interleaved rounds_

|  | main | 1.3.1 | 1.3.0 | 1.2.0 | 1.1.1 | 1.1.0 |
|---|---|---|---|---|---|---|
| **Median** | 28.9s | 27.5s | 28.0s | 27.4s | 27.9s | 28.0s |
| **vs 1.3.1** | ≈ | baseline | ≈ | ≈ | ≈ | ≈ |

_≈ means the rounds disagreed on the direction — faster than 1.3.1 in some, slower in others — i.e. no measurable difference._
<!-- BENCHMARK_RESULTS_END -->

Compare figures within a single run only. Absolute seconds reflect whichever CI machine ran the benchmark: an unchanged release has been measured anywhere between 21.8s and 35.5s across different runs, which is why the first row is only there for scale.

The second row is what to read, and how it is measured matters more than how often. A shared CI machine does not only differ from the next one, it also changes speed while the job runs. Timing each version's repetitions back to back handed that drift to whichever version was running at the time: across five runs, the unchanged 1.0.0 release came out anywhere from 12% faster to 8% slower than 1.3.0. So the versions are now timed in interleaved rounds — every round runs each version once, in a fresh random order — and compared with the baseline round by round, where both timings came from the same few minutes on the same machine. The median of those per-round differences is reported only when every round agrees on the direction; otherwise it is `≈`.

A single run is still never evidence of a regression; a trend across several is. The raw timings of every run are kept in [`results/`](results/), so a trend can be checked rather than remembered.

## Compared to other tools

A separate run measures phparkitect against other architecture-testing tools on one shared rule — *classes in `Akeneo\*\Domain` must not depend on Symfony* — over [Akeneo PIM](https://github.com/akeneo/pim-community-dev). Different subject, different config: these numbers are **not** comparable with the version table above.

The subject is an application rather than a framework monorepo on purpose. Frameworks ship classes that are valid only against one version of an optional dependency, which a reflection-based analyser cannot load at all.

<!-- COMPETITORS_RESULTS_START -->
_Run: 2026-09-22T20:18:51Z — Akeneo v2026.3 — PHP 8.3.33 — 5 runs per tool — one shared rule_

| Tool | Version | Cold | Warm cache |
|------|---------|------|------------|
| phparkitect | 1.3.1 | 7.3s | — *(no cache)* |
| deptrac | 4.7.2 | 9.4s | 2.5s |
| phpat | 0.11.10 | 37.3s | 2.7s |
<!-- COMPETITORS_RESULTS_END -->

Every tool is checked before it is timed: it must report the violations it is known to find on this codebase, or the run aborts rather than publish a figure. A tool that silently runs no rules at all would otherwise look very fast — which happened three separate times while this was being built.

**The warm column needs its own caveat.** It is the time when the tool's own cache survives from a previous run, which on CI only happens if the workflow restores it — a fresh checkout always pays the cold price. And for phpat it is the same cache that silently reported zero violations when a rule changed, since PHPStan keys it on the analysed files and phpat's rules live outside them. Fast, but not free.

The violation counts are not shown, because they would mislead. All three tools flag the same classes for the same reasons and disagree only on how many times to report one, so a higher number means a finer-grained report, not a better result. [competitors/akeneo/RULE.md](competitors/akeneo/RULE.md) has the rule and the numbers; [competitors/comparison.md](competitors/comparison.md) has what each tool turned out to be strong and weak at.

## How it works

1. Clones `symfony/symfony` and `akeneo/pim-community-dev`, both at a pinned tag. Akeneo also gets its `vendor/` installed, because phpat resolves dependencies through reflection and needs the analysed project's autoloader.
2. Fetches the 5 latest stable phparkitect releases plus `main`, and times them over Symfony in N interleaved rounds, each running every version once in a random order.
3. Runs phparkitect, deptrac and phpat over Akeneo on one shared rule, cold and with a warm cache, asserting each tool's violation count before timing it.

Results are updated automatically every day when new commits are pushed to `phparkitect/arkitect` main.

## Running locally

```bash
bash run.sh            # run benchmark, writes results/<timestamp>.json
RUNS=10 bash run.sh    # more rounds: slower, but fewer ≈ from a noisy machine
bash update-readme.sh  # update this README with the latest results
```
