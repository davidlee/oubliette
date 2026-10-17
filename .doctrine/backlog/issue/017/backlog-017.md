# ISS-017: shared recipes guess which capsule a name means from a probe, and a wrong guess takes a branch silently

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

`just/fleet.just` `up` reads any failure of `capsule NAME created` as "never
created" and falls through to `sudo microvm -c NAME -f <justfile dir>`. A name
the front end refuses ("neither a verb nor a capsule on this host") takes the
create branch.

Observed 2026-10-17: `just up j` from oubliette's devshell after SL-004 PHASE-07,
where `capsule` is built over `fixture/` (slots `alpha`, `beta`). It prompted for
sudo and failed only because oubliette no longer declares
`nixosConfigurations.j`. `/var/lib/microvms/j` was untouched. A typo in a
consumer reaches the same branch.

Second instance, folded in 2026-10-17: `reset-known-hosts NAME` picks its
branch from whether `/run/capsule/NAME/ssh.sock` exists. Present: it removes
`capsule-NAME` (the module path's `HostKeyAlias`, host/cli.nix:720). Absent: it
removes the devshell capsule's guest address (`_net guest`). So for a module
slot that is **stopped**, it removes the wrong entry, leaves `capsule-NAME`
stale, and exits 0. After the SL-004 cutover every real slot is a module slot,
so this is the common case: a fresh volume has fresh host keys
(mem.fact.oubliette.fresh-capsule-fresh-host-keys). Hit 2026-10-17 on `a` after
cutover; the user fixed known_hosts by hand. That was with `a` running, so the
recipe would have worked; the hazard is running it before a start.

Common shape: a recipe infers *which capsule path a name refers to* from a
probe (`capsule NAME created` failing, a socket's absence) rather than from the
declaration, and a probe failure for any other reason takes a branch with side
effects.

Fix shape: resolve the name against the declared slots (the consumer's
`capsules.nix`, or the front end's own refusal) before branching.
- `up`: take the create branch only for a declared, uncreated slot.
- `reset-known-hosts`: a declared slot always means `capsule-NAME`; the
  devshell address only on that path's own spelling.
- Anything else: refuse with the front end's reason.

Add a case per recipe that types an undeclared name, and one that resets a
stopped declared slot, red first. Also stale since the cutover:
`capsule-capsule` and `capsule-capsule-b` entries in the owner's known_hosts,
for the slots CHR-013 cleared. Related: oubliette's own `just --list` still offers
operational recipes that cannot work from its root (SL-004 reconcile item).

## Resolution (2026-10-17)

The front end exits 2 when it cannot tell what was asked (no verb, an unknown
word, a bad `CAPSULE_NAME`), so `created` answers only 0 or 1 and `up` creates
only on a 1. The host-key entry is now the front end's verb,
`capsule NAME forget-host-key`: it removes `capsule-NAME` (the alias `door`
files every key under, one definition) and the guest address only where the
devshell tap is in this namespace. `reset-known-hosts` delegates to it, and the
volume verbs' "next:" hints name it. Pinned in `host/volume-cases.nix`.

Not done here: the owner's stale `capsule-capsule` / `capsule-capsule-b`
known_hosts entries (the verb refuses undeclared names, so `ssh-keygen -R` by
hand), and oubliette's own `just --list` offering recipes that need a
consumer's root. The `up` recipe's branching is not run by a suite (it needs
`nix eval` of `net.nix`); it was exercised by hand against `/srv/fleet` with a
stub `sudo`.
