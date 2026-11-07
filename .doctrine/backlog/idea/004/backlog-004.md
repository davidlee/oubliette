# IDE-004: llm-gateway holds the claude and codex OAuth credentials, so a capsule holds only a gateway key (needs ~/flakes)

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

A later step after IDE-003. Extend `llm-gateway` so that it, not the guest,
holds the claude and codex OAuth credentials. Then every model, including
those two CLIs, is reached through the gateway. The guest holds only a gateway
key from `llm-gateway issue`, limited to named models and a budget, and
revocable on the host with `llm-gateway revoke` without touching the guest.
Rotation and refresh stay on the host, which also answers QUE-003 and CON-004
for these credentials rather than measuring around them.

**Dependency: `~/flakes`.** The gateway is that repo's service (`flakes:SL-011`;
module ownership is `flakes:IDE-008`). The OAuth handling is gateway work and
lands there. This item tracks the oubliette side: the capsule config that
points `claude`/`codex` at the door, and dropping their credentials from
inject.

Unknowns for design:
- Whether each CLI can be pointed at a custom base URL while still using
  subscription OAuth, or needs API-key mode against the gateway.
- Whether the gateway may serve more than chat completions and the model list
  (Plan F §2 says it serves only those today).

Mitigates RSK-013.
