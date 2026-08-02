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

They differ on purpose and must not be forced to agree:

- **phparkitect** counts one violation per occurrence — the same dependency on
  three lines is three violations.
- **deptrac** counts unique class-to-class dependencies, but its collectors also
  match dependency kinds the others treat differently.
- **phpat** additionally sees dependencies declared only in docblocks
  (`@param`, `@return`, `@throws`, `@var`), which an AST-name approach does not
  resolve to the same set.

Each number was verified by hand when the tool was added. `run.sh` asserts each
tool against its own figure, so what the guard detects is drift, not
disagreement.
