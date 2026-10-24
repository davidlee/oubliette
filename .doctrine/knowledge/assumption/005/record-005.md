# ASM-005: In a room guest, room-persist runs after home.mount and before the bind, and postgresql.target follows the bind

<!-- Knowledge record body — context, detail, links. The structured, queried
     fields live in the sister `record-NNN.toml`; this prose is free-form and is
     never structurally parsed (the storage rule). -->

## Validated (2026-10-24, SL-009 PHASE-05 steps 1 and 3)

Live, on this host's room `assistant` (oubliette `67977f9`): `postgresql.target`
active; `findmnt` sources the bind from `/dev/vdb` (the `/home` volume) at
`/.fragments/postgresql-18/var/lib/postgresql`; `/home/.fragments` `700 root`;
`postgresql.service` `Requires=var-lib-postgresql.mount`; one boot's journal
orders `/home` (5.80 s) → room-persist (5.81 s) → bind (5.82 s) → server
(6.23 s) → setup (6.29 s). A row written before a VMM stop/start reads back
after it; the data directory stays `postgres:postgres 750`. Quoted output:
SL-009 `notes.md` `## PHASE-05 (live)`.

What it does not prove: the order is one boot plus the declared dependencies,
not a race-free guarantee across boots; a room volume deleted and recreated was
not exercised.
