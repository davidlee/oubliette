**Fact.** `builtins.tryEval` returns `{success = false;}` only for `throw` and
a failed `assert`. A type error, such as dereferencing an attribute of `null`
("expected a set but found null") or calling a non-function, is not caught: it
aborts the whole evaluation, including the suite that wrapped it.

**Consequence for an eval-verdict case** (CLAUDE.md's "force what you pin"):
`tryEval (deepSeq x true)` written to guard against a type-error hazard can
never report `false`. Under the hazard the suite dies at eval instead of
printing a FAIL line, and without the hazard it passes. So the case is
decorative. Found in SL-005 PHASE-04 (mutation M4): `fabric-cases.nix`'s
no-throw verdict over `liveNames` was removed for this reason, and its header
now says the hazard aborts the eval.

**How to apply.** Pin a `throw` with tryEval + deepSeq, plus the reason exposed
as a value. For a type-error hazard, make some case *force the value*: a red
build is then the signal, and the suite header says so. Don't write a tryEval
case for it.
