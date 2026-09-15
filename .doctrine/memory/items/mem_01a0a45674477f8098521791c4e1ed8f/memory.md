Seen mutating `host/volume-root.nix` for `volumeRootCases` (SL-002 PHASE-01,
2026-09-15). The subjects are `writeShellApplication`s, so shellcheck runs when
the *program* builds, before the suite's `runCommand` does. Replacing
`[ -z "$wrote" ] || rm -f -- "$mark"` with `rm -f -- "$mark"` left `wrote`
assigned and never read: SC2034 failed the helper's build, the suite never ran,
and `nix build` exited 1 just as a red case would have.

**Read which cases went red, never only the exit status.** An `error: builder
for '…-capsule-<program>.drv'` with no `FAIL` lines means the mutant never
reached the suite. Keep the mutated variable referenced (`: "$wrote";
rm -f -- "$mark"`) so the behaviour change reaches the cases.

The same session found a second way a mutation can mislead, in the opposite
direction: a case that **passes with the behaviour removed**. The planned
copy-failure case used an unreadable source, and `cp` refuses that before
creating the temporary file, so dropping the EXIT trap left the case green. Only
a failure *after* the temporary file exists can see the trap. This is CLAUDE.md's
"check the suite can fail by mutating the behaviour it claims to pin", applied to
every case rather than to the suite as a whole.
