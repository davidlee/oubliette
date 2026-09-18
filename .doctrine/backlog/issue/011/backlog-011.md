# ISS-011: A cross-target re-provision records a base read from the old target's guest path

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

`recordProvisioned` (host/cli.nix) reads the guest's HEAD through `guestHead` →
`observed` → `slotProfile`, which resolves the slot's profile from its record
*as it stands before this provision is recorded*. For a re-provision onto a
different target, that is the previous target's document, so `observe` looks at
the previous target's `guestPath`, and the base recorded for the new
assignment is read from the wrong checkout, or is `-`.

Pre-existing: before SL-001 the HEAD question also ran before the record write.
SL-001's reorder (HEAD asked before the pin; design sec-3) neither causes nor
fixes it. Unreachable today in practice — one image, one target per slot until
`IMP-006` — which is why it is parked rather than folded into SL-001.

Likely repair: have `guestHead` take the profile the provision was taken under
(`recordProvisioned` already holds it in `prof`), rather than re-resolving the
slot. Found during the self-review of SL-001's design after the Opus review
(fnd-13…fnd-30).
