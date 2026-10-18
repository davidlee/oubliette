`d <stateDir>/room/<name>` with no rule for `<stateDir>/room`: tmpfiles creates
the intermediate **root:root**, then refuses to descend from the owner-owned
`stateDir` into it:

    Detected unsafe path transition /var/lib/capsule (owned by david) → /var/lib/capsule/room (owned by root)

**The switch says nothing.** It reruns tmpfiles as `systemd-tmpfiles-resetup`,
whose `SuccessExitStatus` includes CANTCREAT, so the unit is green and the
directory is simply absent. Seen live in SL-006 PHASE-07 (ISS-024).

**A pre-existing directory masks it**: `<stateDir>/slot` was the same latent gap,
hidden because it predated the rules and is owner-owned. A fresh host would hit it.

Fixed in 4c1d210: services.nix declares both roots (`rooms.stateRootOf` is the
room root's one spelling), and `hostModuleUnits`' `unparented` check requires,
under `stateDir`, every declared `d` rule's parent to be declared too, owned by
root or the same user. A new `d` rule under `stateDir` goes red there if its
parent is missing — add the parent rule, don't rely on the directory existing.
