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
