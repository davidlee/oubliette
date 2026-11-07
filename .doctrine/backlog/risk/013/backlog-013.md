# RSK-013: A capsule running claude or codex holds a persistent, high-value OAuth credential in its home

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

To run `claude` or `codex` inside a capsule, the guest's `$HOME` must hold
that CLI's OAuth credential, delivered by `capsule-inject`. That credential is
the account itself: long-lived, refreshable, not limited to particular models
and with no spending cap, and usable from anywhere once it has left the guest. The guest is the
least-trusted place it lives, and the perimeter (POL-001) limits where it can
be *sent* from the capsule, not what it is worth if it leaves.

Related, but distinct:
- QUE-003 asks how long an injected copy stays *good* (it rotates on refresh).
- CON-004 says a rotation does not reach a running capsule, deliberately.
This item is about the copy's *value*, not its freshness.

Mitigation today: none beyond the egress allowlist and inject being explicit.
The way out is IDE-004 (the gateway holds the OAuth credential; the guest
holds a narrow gateway key), which rests on IDE-003 (the door).
