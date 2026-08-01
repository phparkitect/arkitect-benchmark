# What the benchmark revealed about each tool

Notes collected while building the cross-tool benchmark, 2026-08-02. Subject:
`symfony/symfony` v7.2.0 (~7000 files), three dependency rules, PHP 8.3 on CI /
8.5 locally. Tool versions: phparkitect 1.3.0, deptrac 4.7.1, phpat 0.11.10 with
phpstan 2.2.7.

Everything below is either **measured** (a command was run and the output
recorded) or **read** (taken from the tool's own configuration or source). The
distinction is marked, because the measured parts come from one codebase and
three rules and should not be read as a general verdict on performance.

## Measured timings

From CI run 30720544439, 5 repetitions per tool, same machine, same run:

| Tool | Version | Median (s) |
|------|---------|------------|
| phparkitect | 1.3.0 | 27.4 |
| deptrac | 4.7.1 | 31.4 |

Both report 29 violations on the shared three rules. phpat is absent for the
reasons below, not because it is slow.

Absolute seconds are machine-dependent: the same pair measured 13.1s and 18.5s
on a laptop, a ratio of 1.4× against 1.15× on the CI runner. Only the within-run
comparison means anything.

## The main dividing line: AST names vs reflection

**Measured.** phparkitect and deptrac read class names from the parsed AST. The
target class does not need to exist: both found the `Doctrine\DBAL` dependencies
in `HttpFoundation` with Doctrine not installed at all.

phpat runs on PHPStan's reflection, so a dependency on a class it cannot resolve
is invisible to it. Pointed at the same source without Symfony's autoloader, it
reported **zero** violations — not an error, just silence. Adding
`../../symfony/vendor/autoload.php` as a bootstrap file made the same rules find
26 violations in a single subdirectory.

Most of the differences further down follow from this one.

## Tolerance to unparseable code

**Measured.** Symfony's test suite contains deliberately broken fixtures.

phparkitect reports them and carries on:

```
⚠️ 34 violations detected!
❌ found parsing errors in these files:
Syntax error, unexpected EOF on line 8 in file: .../Fixtures/ParseError.php
```

deptrac does the same, printing `Syntax Error on File ...` before its report.
Both still produce their full result.

PHPStan refuses to complete: *"Result is incomplete because of severe errors"*,
and excluding the offending file surfaces the next one.

An automated loop chased that for 25 iterations and 38 exclusions without
converging — but that was a misdiagnosis on our side, worth recording because it
is an easy trap. The `phpat/` project did not have PHPUnit installed, every
Symfony test extends `PHPUnit\Framework\TestCase`, and PHPStan turns that single
unresolvable parent class into a fatal *internal error* per file rather than a
reportable one. One missing dev dependency looked like an endless tail of broken
tests. Installing PHPUnit collapsed 38 blockers to 17.

What remains after that is a bounded and legitimate list, of two kinds:

- **Fixtures Symfony deliberately keeps broken** to test its own error handling:
  `ParentNotExists`, `BadParent`, `Symfony\Bug\NotExistClass`, `MissingClass`,
  and an `Internal error: boo`. These classes are *meant* not to exist; no
  install fixes them.
- **Missing PHP extensions**: `Redis`, `RedisCluster`, `Relay\Relay` are C
  extensions, not composer packages.

Excluding those (with `excludePaths.analyseAndScan` — plain `excludePaths` is not
enough, the files are still scanned for symbols) leaves **two blockers that
cannot be excluded at all**:

```
Child process error (exit code 255): PHP Fatal error: Class
Symfony\Component\HttpClient\Internal\AmpListenerV4 contains 20 abstract methods
and must therefore be declared abstract or implement the remaining methods
```

`AmpListenerV4` is one of Symfony's version-conditional shims: against the
installed amphp major it is genuinely invalid PHP. PHPStan reaches it through the
autoloader while resolving reflection, actually `include`s the file, and the
child process dies. It cannot be excluded, because it does not arrive through
`paths` — it arrives through the autoloader, which is precisely what phpat needs
in order to see dependencies at all.

**This is where the attempt ends.** The mechanism that gives phpat its
reach — real reflection over loaded classes — is the same mechanism that makes it
unable to analyse a codebase shipping version-conditional classes.

The robustness difference is therefore narrower than the first misdiagnosis
suggested, but real and in the same direction: given a class it cannot resolve or
even load, phparkitect and deptrac record the fact and finish the job, while
PHPStan aborts. For a tool that runs over other people's code — including test
fixtures written specifically to be pathological — that is the behaviour that
matters.

It also matters for the benchmark: each exclusion means phpat analysing a
different file set than the other two, which is the "same work" premise the
correctness guard in `run.sh` exists to protect.

## How the rules are expressed

**Measured** (the configs are in this directory):

| | Model | Cost of the same 3 rules |
|---|---|---|
| phparkitect | deny-list (`NotDependsOnTheseNamespaces`) | 20 lines of PHP |
| deptrac | **allow-list** per layer | 70 lines of YAML |
| phpat | deny-list, fluent | ~45 lines of PHP |

deptrac's ruleset is an allow-list, which fits "may only depend on" and fights
"must not depend on". Expressing the three rules required enumerating every layer
that is *not* forbidden, plus a rule for `HttpKernel` that none of the original
rules mentions — without it deptrac reports dependencies no phparkitect rule
cares about.

## Where the other tools are ahead

**Read**, from `vendor/phpat/phpat/extension.neon`: phpat has the richest
vocabulary of the three. It ships assertions phparkitect has no equivalent for —
`ShouldBeReadonly`, `ShouldHaveOnlyOnePublicMethod`, `ShouldNotConstruct`,
`ShouldBeInvokable` — and it detects dependencies in places an AST-name approach
has to handle case by case: `@param`, `@return`, `@throws`, `@var`, `@mixin`
docblock tags, attributes, `catch` blocks and `instanceof`.

**Measured**: phpat is also the only one of the three that uses more than one
core — 770% CPU on a 12-core machine, against single-threaded competitors. On a
2-core CI runner that advantage largely disappears, which is another reason a raw
wall-clock number would have been misleading.

**Measured**: deptrac reports `Uncovered: 3275` — classes belonging to no layer.
It tells you what your ruleset is *not* looking at. phparkitect has nothing
equivalent.

**Read**: deptrac has no counterpart for asserting a naming convention. Its
collectors match class names to *select* layers, but there is no "classes here
must be named `*Command`" assertion, so phparkitect's `HaveNameMatching` rule
(5 violations on Symfony) has no equivalent and is excluded from the timed set.

## Violation counting is not the same unit

**Measured.** phparkitect counts per occurrence: in `PdoSessionHandler` a single
dependency on `Doctrine\DBAL\Types\Types` produces seven violations, one per line
(214-222). phpat deduplicates per class pair. On this subject phparkitect and
deptrac happened to agree exactly at 29, but that is not guaranteed in general —
any future tool added to the benchmark needs its own expected count, verified by
hand, rather than a shared constant.

## Two ways a tool can silently do nothing

Worth recording, since both were hit while building this:

1. **Not registered.** The April 2026 attempt ran phpat under PHPUnit, which has
   no idea what a phpat rule is. Result: 0.1s and a green run. phpat must be
   registered as a PHPStan extension (`phpat.test` tag) and needs `bootstrapFiles`
   for its own test class to be loadable.
2. **Registered but blind.** Correctly wired, but without the analysed project's
   autoloader, every target class is unresolvable and every rule passes.

Neither produces an error. Both produce a fast, green, meaningless benchmark —
which is why `run.sh` asserts the violation count before recording any timing.
