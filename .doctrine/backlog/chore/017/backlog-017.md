# CHR-017: Drop the microvm-spike symlink and the MICROVM_SPIKE_ROOT fallback

SL-004 design sec-7 step 10, deferred out of that slice because it changes
program text (RV-013 F-10).

Since the SL-004 cutover every `/var/lib/microvms/*/flake` reads `/srv/fleet`
and `~/flakes` overrides `fleet`, so nothing on this host names
`~/dev/microvm-spike` any more. What still carries the old name:

- `perimeter/root.nix:6` — `root="${CAPSULE_ROOT:-${MICROVM_SPIKE_ROOT:-$PWD}}"`,
  spliced into most programs, so removing it moves most derivations;
  the devshell `shellHook`'s foreign-root warning (mkfleet.nix) reads the same
  fragment, so it goes with it;
- the `~/dev/microvm-spike` symlink itself (the user's to delete).

Done when: the fallback is gone, `just` green,
and the symlink is deleted or the user says to keep it. Check no shell profile
still exports `MICROVM_SPIKE_ROOT` first.

Related: CHR-016 (the other spellings of the root, and its own question whether
`MICROVM_SPIKE_ROOT` has a caller left).
