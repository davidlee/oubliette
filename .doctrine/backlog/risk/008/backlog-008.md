# RSK-008: The guest-path guard is pinned, its call site is not

`vm/guest-path.nix` throws unless a path is `^/[A-Za-z0-9._/@+-]+$`, and it
exists because `home` and every `scrubPaths` entry are spliced **unquoted** into
`capsule-reset-home`'s `rm` as root. `vm/capsule.nix:48-57` is the one place it
is called.

**Nothing detects the call being removed.** `resetHomeCases` reads five
`builtins.tryEval` verdicts straight off the function, which hold whether or not
anything calls it; and `shippedPlain` asserts only that *this host's* values are
plain, which they are either way. So the mutation that matters reddens nothing,
and the guard could be deleted in a refactor with a green build.

This is CLAUDE.md's fourth kind of gap — a program's behaviour depending on
something wrapped around it rather than inside it — one level down from the
`wrapCases`/`ISS-004` instance, and it is the shape `NOTES item 51` warns about:
a suite that agrees with itself.

**What would close it:** the guest evaluated against a *hostile* `target`, which
means `mkVm` parameterised by target and a second full NixOS eval in
`just build`. That is the cost that stopped it at `RV-004` `F-4`, where the
agreed fix plan was the function itself and the finding was a minor.

Raised at `SL-002`'s closure audit as `RV-006` `F-6`, disposed follow-up.
Related: `RSK-004` (the two copies of the CLI are one store path by
construction, unchecked) is the same unverified-by-construction shape.
