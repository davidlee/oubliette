# IMP-026: Add PostgreSQL service support to rooms

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

## Intent

Allow a room to run a PostgreSQL server as a managed service. This is more
than adding the PostgreSQL package to the room's available tools: PostgreSQL
must be configured and supervised as part of the room VM.

## Design questions to resolve

- What declarative room configuration selects PostgreSQL and its version,
  databases, users, and authentication rules?
- Where does PostgreSQL store its data so it survives the room's intended
  restart and rebuild lifecycle? Define volume ownership, provisioning,
  backup/reset expectations, and major-version upgrade behavior.
- How do clients connect? One candidate is an SSH tunnel through the room's
  existing door while PostgreSQL listens only inside the guest. Direct host
  access would require a separately designed forwarding path.
- How does service startup order relate to room storage and readiness?

The intended outcome is an optional room capability that can provide a
PostgreSQL service with an explicit data lifecycle and connection path. These
choices remain open; this item does not assume arbitrary NixOS service
configuration or direct network exposure.
