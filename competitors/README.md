# Cross-tool benchmark

The version-history benchmark in the repository root answers "is phparkitect getting
slower between releases?". This directory answers a different question: "how does
phparkitect compare to other architecture-testing tools on the same work?".

The two are kept apart on purpose — they have different configs and are not comparable
numbers.

## Rule equivalence

Timings are only meaningful if every tool is doing the same work, so the cross-tool run
uses `phparkitect/config.php`, a **subset** of the root `arkitect.php` containing only
the rules every tool can express:

| Rule | phparkitect | deptrac |
|------|-------------|---------|
| HttpFoundation must not depend on Doctrine, Twig, Monolog, Psr\Log | ✅ | ✅ |
| EventDispatcher must not depend on Doctrine, Twig | ✅ | ✅ |
| DependencyInjection must not depend on HttpFoundation, HttpKernel | ✅ | ✅ |
| Console command classes must be named `*Command` | ✅ | ❌ no equivalent |

Deptrac models dependencies between layers, so it has no counterpart for a naming
constraint. That rule is excluded from the timed run and reported here instead.

Note also that the two rulesets are written inside-out: phparkitect's
`NotDependsOnTheseNamespaces` is a deny-list, while deptrac's `ruleset` is an allow-list.
Expressing the same three rules in `deptrac/depfile.yaml` requires listing every layer
that is *not* forbidden, plus a rule for `HttpKernel`, which would otherwise be reported
against layers no phparkitect rule mentions.

## Cold runs

Deptrac is run with `--no-cache`. It persists a cache file between processes and
phparkitect has no cross-process cache, so every repetition after the first would
otherwise be timed warm against a cold competitor. Measured, the difference is currently
about 1% — within noise — but the flag keeps the comparison from silently drifting if
that changes.

## Correctness guard

Both tools report **29 violations** on Symfony v7.2.0 with these three rules — verified
by hand when each tool was added.

`run.sh` re-checks that count before recording any timing and aborts if it does not
match. A previous attempt to benchmark phpat published a 0.1s result that was really
PHPUnit starting up with no tests registered; the tool never executed a single rule. A
timing from a tool that is not doing the work is worse than no timing at all, so the
count is asserted rather than assumed.

When a Symfony upgrade legitimately changes the number, update `EXPECTED_VIOLATIONS` in
`run.sh` in the same commit that bumps `SYMFONY_VERSION`.

## Not yet included

**phpat** is wired up in `phpat/` and its rules do work — verified at 26 violations on a
single subdirectory — but PHPStan cannot complete an analysis of this subject. After
installing PHPUnit and excluding Symfony's deliberately-broken fixtures, two blockers
remain that cannot be excluded at all: version-conditional classes that are invalid PHP
against the installed dependencies, which PHPStan loads through the autoloader and which
kill the process. See [comparison.md](comparison.md) for the full trail.

**Pest arch** runs inside the Pest runtime and has not been attempted.

See [comparison.md](comparison.md) for what the two are strong and weak at, and for the
two ways a tool in this benchmark can silently do no work at all.
