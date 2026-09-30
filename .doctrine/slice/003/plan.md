# Implementation Plan SL-003: A slot boots its own image, so a second target runs beside doctrine

Prose companion to `plan.toml`. Narrative only — the phase list, criteria and
verification are authored in the TOML.
<!-- Reference forms: `lib:reference/glossary.md` § reference forms. -->

## Overview

Design sec-6's three-step order, cut into five phases so each ends green and
each has one reason to exist:

```
design step 1 ──┬─ PHASE-01  devshell groundwork: one root, one own_vms, vm's booted link
                └─ PHASE-02  the marker, the reader, the refusal          ◀ disrupts c at next switch
design step 2 ──┬─ PHASE-03  targets/ as a set; every consumer moved      (no behaviour change)
                └─ PHASE-04  fleet.nix: one image per target, slot bound  (no behaviour change)
design step 3 ──── PHASE-05  goad-walk + slot j                           ◀ gated on the user's sec-5 preconditions
```

## Sequencing & Rationale

**PHASE-01 before PHASE-02.** The refusal reads `booted` on both paths. If it
landed before `vm` wrote the devshell link, every devshell capsule would refuse
every profile verb (RV-009 F-1). The groundwork changes nothing a module-path
capsule sees, so it can land at any time, and it fixes `ISS-016` on the way.

**The refusal before the target set.** This is the design's order. It is right
because the refusal is correct with one target (it closes `ISS-011`), and
because it is the one phase that changes behaviour on this host. So it goes
alone and early, and it is the phase whose timing the user controls
(`DEC-023`). The disruption starts at the user's host switch, not at the
commit: the module path runs the program that `~/flakes`' lock names. The devshell
is the second door: re-entering it after PHASE-02 lands rebuilds its `capsule`,
which refuses `c` at once.

**PHASE-03 and PHASE-04 split at the target/image seam.** Moving every
consumer to the set is a wide, mechanical refactor with an exact oracle:
doctrine's guest toplevel drvPath and the rendered profile are unchanged.
`fleet.nix` is a small new piece with its own suite. Doing both in one phase
would mix a refactor with new logic, and a failure would not say which one
caused it. Both phases end with this host's drvPaths unchanged. That is the
behaviour oracle for a refactor that has no cases of its own.

**PHASE-05 last and gated.** Everything before it builds and is tested without
goad-walk (design sec-5). Its entrance is the user's upstream work. Its exit
has a human half: starting a slot is the user's act on this host.

## The plan question (design sec-4, sec-6)

*Should `hostModuleUnits` check a real runner's `microvm-run`/`--config-file`
layout?* **No.** `hostModuleUnits` evaluates and does not build. A runner's
text exists only after the guest closure is built (~3 GiB), and `just build`
deliberately does not build that. A check there would be either an eval that
cannot see the text, or a build that makes every `just` pay for an image. The
layout is instead covered at three rungs:

- **run:** `policyCases` over a fixture tree in the same shape (PHASE-02 VT).
- **take:** `jq` and `sed` over the real `image-doctrine` runner after
  `just build-vm`, recorded (PHASE-02 EX-6/VA-2).
- **start:** a profile verb on `c` proceeding after its restart onto the marked
  image (PHASE-02 VH-1). This is the strongest of the three, because only a
  real runner with the right layout gets past the refusal.

If microvm.nix moves the layout later, `bootedTarget` prints nothing and every
verb refuses as unmarked. The failure is closed and names itself. `IMP-013`'s
status column would show it too.

## Notes

- Governance changes (`DEC-016` superseded, `POL-002`/`POL-003`/`CON-001`
  revised, `IMP-012`/`IMP-006`/`ISS-011`/`RSK-002` updated, ledger items'
  `*State:*` headers) are reconcile's, not a phase's (design sec-6).
- Commit at each phase, subject naming the finding (CLAUDE.md).
