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

**Widened (SL-001 `fnd-37`).** The defect is not only the re-provision.
`guestHead` (through `observed`), `guestStages` and `guestDropState` all call
`slotProfile "$n"` with no argv, so they read the slot's record — or, after
SL-001, its declared default — and never the verb's `--profile`. Two more
reachable shapes once a slot declares a default:

- a first `capsule <slot> provision --profile X <ref>` on a slot declaring `Y`
  reads its HEAD under `Y`'s `guestPath`;
- `capsule <slot> setup --profile X --state-from-host` probes (and under
  `handoff`, drops) `Y`'s state chain.

Both are unreachable while every slot declares the one target the one image
carries. The repair is the same for all three functions: take the profile the
caller already resolved, not the slot.
