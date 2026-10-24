# ASM-006: A connection forwarded over the room door with ssh -L reaches peer auth as the logged-in user, and samerole admits own and granted shared databases only

<!-- Knowledge record body — context, detail, links. The structured, queried
     fields live in the sister `record-NNN.toml`; this prose is free-form and is
     never structurally parsed (the storage rule). -->

## Validated (2026-10-24, SL-009 PHASE-05 steps 4–6)

Live, on this host's room `assistant`: a local-socket `ssh -L` over the door
with the room-client bundle, host `psql -U agent`, got `current_user` and
`session_user` both `agent`; `-U satan` through the same forward got `Peer
authentication failed for user "satan"`. `samerole`: `satan` refused `-d agent`
(`no pg_hba.conf entry … user "satan", database "agent"`) and admitted to its
own; after root's `shared_proj` recipe granted to `agent` only, `agent` admitted
and `satan` refused (`no pg_hba.conf entry … database "shared_proj"`). Quoted
output: SL-009 `notes.md` `## PHASE-05 (live)`.

What it does not prove: a TCP-port forward (`-L 5432:…`) was not exercised; nor
a login granted a shared role after a session was already open.
