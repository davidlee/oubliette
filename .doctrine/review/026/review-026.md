# Review RV-026 — reconciliation of SL-009

Adversarial-review ledger. Structured findings live in the sister
ledger toml; this prose companion carries the reviewer's framing.

## Brief

<!-- Pre-reading + lines of attack: what this review is probing, the invariants
     it must hold the subject to, and where the bodies are likely buried. Seeded
     at `review new`; the reviewer fills it before raising findings. -->

Conformance audit of SL-009 (PHASE-01..05) in the primary tree at c6e1c55;
not dispatched, so no candidate branch. Lines of attack:

- path conformance: `doctrine slice conformance 009` (design-target selectors
  vs recorded deltas);
- the gate at HEAD, since the operator's lock bump (67977f9) post-dates the last
  green (e07fb7b): `just check && just`, and `doctrine slice verify-vt 9`;
- design.md sec-1..sec-9 against the code: an independent read-only pass
  (quotient `pi_agent`, review profile, given the design and the diff and no
  conclusions), each claim then checked against the source;
- the items carried in notes.md `## Harvest` for /reconcile and /audit;
- PHASE-05's live evidence against EX-1..EX-4 and the ASMs it settles.

Invariants held: POL-001..005 (the perimeter host-side; nothing generic names a
target; one declaration per axis; reusable code jail-blind; a room never
fetches), STD-001 (report at the rung reached).

## Synthesis

**Closure story.** The slice delivers what its design set out: one capability
fragment, `postgresql-18`, selected by a room's `extras`, rendered as a guest
module plus a path persisted on `/home`, refused by a slot. Every path the
design targeted was edited and nothing was left undelivered (12 conformant, 0
undelivered); the 11 undeclared are doctrine bookkeeping and the operator's lock
bump (F-6, aligned). The gate is green at HEAD after that bump, and verify-vt
passes every VT of PHASE-01..04. PHASE-05 took the claims the build cannot make
to the live rung on this host's real `assistant` room: readiness, the bind's
source and boot order, persistence across a VMM stop/start, peer auth through a
forward over the door, and `samerole` exclusion and shared-role admission.
ASM-005 and ASM-006 are validated on that quoted output.

**Divergences.** None in behaviour. Four are the design saying something false
or stale about code that is right (F-1..F-4, design-wrong, all per-slice
edits): the stop key as a second root credential, the impossible forward
through `capsule <room> ssh`, the sec-9 table missing the in-flight adaptations,
and sec-6 not describing the suite's ninth case. All four were already known to
the implementing session (notes.md) and the README was corrected where it was
user-facing; the design is the one place that lags.

**Standing risks.** F-5 (follow-up, IMP-027): the suite leaves several
mechanisms unpinned — three door rules with no negative case, the bind's place
in `room-persist.before`, `room-persist`'s script text, and that an unselected
fragment's module is never forced. The live run covers the ordering on one boot,
not regression. Not exercised anywhere: a TCP-port forward, a recreated room
volume.

**Consciously accepted.** A passing slot's assertion carries `message = null`;
NixOS reads messages only of failing assertions, so this is harmless today, but
a generic helper that forces every message would trip on it (independent
reviewer, medium confidence; not raised — no consumer does this).

**Route for a human.** `fragments.nix` (`postgresql-18` entry, `persists`,
`slotRefusal`) → `vm/room.nix` (`room-persist`, the bind, sudo off) →
`vm/capsule.nix` (the slot's refusal) → `fragments-cases.nix` (cases 1-9). The
one behaviour worth reading is the bind: `fsType = "none"`, `bind` plus
`x-systemd.requires=room-persist.service`, so postgres's
`RequiresMountsFor` waits on a directory that exists on `/home` — case 9 pins
both options by breaking each, and step 1 of PHASE-05 saw it live.
`doctrine show ASM-005` / `ASM-006` carry the live evidence; `doctrine show
DEC-061` is why the data lives on `/home`.

## Reconciliation Brief

### Per-slice (direct edit)

- **F-1** — design.md sec-4 (lines 154, 158) and sec-7 (line 300): root in the
  guest is reached by the host's admin keys **and** the host's stop key (an
  unrestricted root login, vm/door.nix:86); a room with `adminKeys = []` still
  has the stop key. Replace "only by the host's admin keys" accordingly.
- **F-2** — design.md sec-4 (lines 191-192): drop "or `capsule <room> ssh`";
  the forward is the room-client bundle's `ssh -L` only, because the verb takes
  no ssh options (host/cli.nix:1922-1948).
- **F-3** — design.md sec-9 (lines 333-335): `vm/capsule.nix` adds an
  `assertions` entry from `slotRefusal` (matching sec-5), not a throw;
  `fragments.nix` takes a required `lib` (imports may not force `pkgs`);
  `fragments-cases.nix` also takes `flavour` and `roomRecords`.
- **F-4** — design.md sec-6 (lines 241-271): the capsule negative case extends
  the image by `specialArgs.flavour`, not a module; add case 9, the persistence
  rules (fsType and `x-systemd.requires`, each broken once against a clean
  control).

### Governance/spec (REV)

- None. No ADR, policy, standard or spec is contradicted; POL-005's "a room never
  fetches" is untouched (the fragment adds no uplink, and the server listens on
  no address).
