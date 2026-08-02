# Cross-tool benchmark

The version-history benchmark in the repository root answers "is phparkitect getting
slower between releases?" over the Symfony source. This directory answers a different
question — "how does phparkitect compare to other architecture-testing tools?" — over a
different subject, with a different config. The two sets of numbers are not comparable
and are rendered as separate tables.

## Subject

[Akeneo PIM](https://github.com/akeneo/pim-community-dev), pinned, with its `vendor/`
installed. An application rather than a framework monorepo, deliberately: frameworks
ship classes that are valid only against one major of an optional dependency
(`CommandForV9`, `DBAL3\Connection`, `AmpResolverV4`), and a reflection-based analyser
cannot load them at all. That difference is what decides which tools can run here — see
[comparison.md](comparison.md).

Akeneo also has real Domain/Application/Infrastructure layering, so the rule is
architecturally meaningful rather than a pretext.

## The rule and the expected counts

One rule, expressed three times: see [akeneo/RULE.md](akeneo/RULE.md) for the rule, the
per-tool violation counts, and why they legitimately differ.

## Cold runs

Both competitors cache, and phparkitect does not, so both are made to run cold or the
comparison would time a warm tool against a cold one:

- **deptrac** runs with `--no-cache`. Measured, its cache is currently worth about 1% —
  within noise — but the flag keeps the comparison from drifting if that changes.
- **phpat** runs with PHPStan's result cache cleared before *every* repetition. This one
  is not cosmetic: PHPStan's cache does not know phpat's rules live outside the analysed
  paths, so a stale cache silently reports **zero** violations for a rule that changed.

## Correctness guard

`run.sh` re-checks each tool's violation count before recording any timing, against that
tool's own expected figure, and aborts if it does not match.

This is not defensive programming for its own sake. Three separate times while building
this benchmark, a tool reported a fast, green, completely meaningless result:

1. **Not registered.** phpat run under PHPUnit, which has no idea what a phpat rule is:
   0.1s and a green run.
2. **Registered but blind.** Correctly wired, but without the analysed project's
   autoloader every target class is unresolvable and every rule passes.
3. **Stale result cache.** Correctly wired and resolving, but PHPStan reused cached
   per-file results: 0 violations where a cleared cache reports 6540.

None of the three produces an error. All three produce a number that looks publishable.

When an Akeneo upgrade legitimately changes a count, update the matching `EXPECTED_*`
value in `run.sh` in the same commit that bumps `AKENEO_VERSION`.

## Not included

**Pest arch** runs inside the Pest runtime and has not been attempted.
