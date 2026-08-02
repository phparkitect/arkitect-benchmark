# The shared rule

    Classes in Akeneo\*\Domain must not depend on Symfony

One rule, expressed three times. Akeneo keeps its Domain layer free of
Infrastructure (that rule finds nothing), but framework types do leak into it,
which makes this both architecturally meaningful and non-empty.

## Expected violation counts

| Tool | Count |
|------|-------|
| phparkitect | 14 |
| phpat | 20 |
| deptrac | 32 |

They differ on purpose and must not be forced to agree. All three flag **exactly the
same eight classes and the same offending targets** — there is no disagreement about
what is architecturally wrong, only about how many times to say it.

Take `ConstraintViolationListException`, which uses `ConstraintViolationListInterface`
as a property type, a constructor parameter and a return type, plus three docblocks:

| Tool | Count for that class | Unit counted |
|------|---------------------|--------------|
| phparkitect | 3 | roughly one per source line mentioning the name |
| phpat | 5 | one per resolved type usage |
| deptrac | 9 | one per **class pair × dependency kind** |

deptrac ships a separate rule per dependency kind (`MethodParamRule`,
`MethodReturnRule`, `ClassPropertyRule`, `DocParamTagRule`, …), so one pair is reported
once per kind that matches. That is where its higher total comes from.

One difference is substantive rather than arithmetic. `ConstraintViolationInterface`
appears only in a `use` statement and as a generic parameter inside docblocks —
`ConstraintViolationListInterface<ConstraintViolationInterface>` — never as a real type.
phparkitect and deptrac report it; **phpat does not**, recording only the outer type of
the generic. On this rule phpat is therefore the least sensitive of the three, despite
having the broadest catalogue of docblock rules.

Each number was verified by hand when the tool was added. `run.sh` asserts each tool
against its own figure, so what the guard detects is drift, not disagreement.
