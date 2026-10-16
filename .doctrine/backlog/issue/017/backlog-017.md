# ISS-017: just up treats an undeclared name as never created and runs sudo microvm -c

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

Fix shape: take the create branch only for a declared, uncreated slot; refuse
anything else with the front end's reason. Add a case that types an undeclared
name at `up`, red first. Related: oubliette's own `just --list` still offers
operational recipes that cannot work from its root (SL-004 reconcile item).
