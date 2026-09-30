# ISS-016: vm-stop finds its VMM by slot name, and every runner is microvm@capsule

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

`vm-stop`'s `own_vms` (`flake.nix:1325`) runs `pgrep -f "microvm@$name"` with
`$name` the argument, a slot letter. Every capsule runner is
`exec -a "microvm@capsule"` (the image's hostName), so the pattern matches
only for `vm-stop c` (a prefix of `capsule`) or `vm-stop capsule`. For any
other slot, `own_vms` is empty, so `vm-stop` prints "`<slot>` is down" at once,
without waiting for a VMM that took the reboot and without reaping one that
hung. It is the `pkill -f` trap in reverse: the netns scoping is right and the
name it filters is wrong.

Found reading the code during SL-003's design review (RV-010 F-2). Not run.
SL-003's design lifts `own_vms` into a fragment that `vm` and `vm-stop` share,
and passes it the runner's hostName instead of the slot name. That fixes this
if SL-003 lands. If it does not, the one-line fix is the same pattern.
