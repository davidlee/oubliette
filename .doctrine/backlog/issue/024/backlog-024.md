# ISS-024: No tmpfiles rule makes the room state directory's parent, so tmpfiles refuses the unsafe path transition

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

## Observed

SL-006 PHASE-07, 2026-10-19, after the `~/flakes` switch that first declared a
room with repos. The switch did not create `/var/lib/capsule/room/assistant`, and
`sudo systemd-tmpfiles --create` refused:

    Detected unsafe path transition /var/lib/capsule (owned by david) → /var/lib/capsule/room (owned by root)

The user worked round it by hand: `chown david:users` and `chmod 0750` on
`/var/lib/capsule/room`, then `systemd-tmpfiles --create`. Record:
`docs/probes.md`, *Two repos in one room*.

## Cause

`host/services.nix`'s `systemd.tmpfiles.rules` (~:782-790) declare `d
${stateDir}` and `d ${stateDir}/room/<name>` (`rooms.stateDirOf`) but nothing for
the intermediate `${stateDir}/room`. tmpfiles makes a missing parent itself,
`root:root`, and then refuses the root-owned → owner-owned step below it.

The same gap is latent for `${stateDir}/slot/<name>`: no rule names
`${stateDir}/slot`. It works on this host only because `slot/` pre-dates the
rules and is owner-owned, so a fresh host would hit it on its first slot.

## Fix shape

Declare both intermediates — `d ${stateDir}/room` and `d ${stateDir}/slot`, mode
0750, the owner — ahead of the per-name rules. `hostModuleUnits` can pin that
every declared path's parent chain is itself declared. Also say whether the
switch itself is meant to make these (the comment at ~:802 says tmpfiles runs
at boot, and activation at switch).

**Fixed (2026-10-19, SL-006, before audit).** `host/services.nix` declares both
intermediates ahead of the per-name rules: `d <stateDir>/slot 0750 <owner> users`
when any slot is declared, and `d <rooms.stateRootOf stateDir> 0750 <owner> users`
when any room is. `rooms.nix` gains `stateRootOf`, and `stateDirOf` is written in
terms of it, so the room root has one spelling. 0750 matches `stateDir`, the
slot directories and the user's hand fix. `capsule-room-git`'s `mkdir -p` under
`umask 077` still makes the room root 0700 when nothing else has. tmpfiles sets
an existing directory's mode and owner to the rule's, so a switch moves it to 0750.

`hostModuleUnits` pins the class, not the two names: under `stateDir`, every
declared `d` rule's parent must be declared too, owned by root or by the same
user (`unparented`, `mkfleet.nix`, beside item 39's traversal pairing). It went
red on the unfixed module naming both `slot` and `room`. Dropping either new
rule, or giving the slot root another owner, sends it red for that reason.

On the switch question: a switch does rerun tmpfiles, as
`systemd-tmpfiles-resetup` (nixpkgs `tmpfiles.nix`). Its `SuccessExitStatus`
includes `CANTCREAT`, so the refusal never failed the switch. That is why it
was silent.

Not exercised: this host gets the fix at the user's next rebuild. A fresh host's
first boot was not run.

## Live acceptance (RV-018 F-8, 2026-10-19)

The fix is pinned at eval (`hostModuleUnits`' `unparented` check, green at
`e16fe32`). tmpfiles accepting the declared parent *on this host* is not yet
observed: it waits on the user's next rebuild. Until then the live
`/var/lib/capsule/room` is the hand-fixed one (`david:users 0750`), which
matches the rule. After the rebuild, `sudo systemd-tmpfiles --create` with no
"unsafe path transition" line is the observation.
