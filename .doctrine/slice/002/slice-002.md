# Volume verbs, and a clone that does not carry an identity

## Context

`docs/plan-d-fleet.md` D3 and D4, which `§9` step 6 puts next and `IMP-001`
carries. The case is operational: S4 (*throw one away and start clean*) and S5
(*warm start*) are the two most frequent administrative actions on this host, and
**S4 today is a hand-typed `sudo rm -rf /var/lib/microvms/<slot>` under
`/var/lib`** — no verb, no partial reset, and it destroys the checkout, `$HOME`,
the caches *and* the ssh host keys whether or not that was the intent. S7 (*reset
just `$HOME`*) is not possible at all short of that same delete, because `$HOME`
is `/work/home` on the same volume as everything else. S5 is not possible either:
nothing shares or copies a volume.

Ungated by [item 49](../../../docs/ledger/049-who-owns-a-state-directory.md) —
both reads are taken, nothing upstream reconciles a declaratively-managed VM at
this lock, and a state directory of ours owes the units `current/bin/*`, `booted/`
and its ownership and nothing else. What that read leaves is a **standing
constraint rather than a gate**: `~/flakes` declares no `microvm.vms.<slot>`,
because `install-microvm-<name>` runs on every rebuild and would re-point
`current` at the declaration. That line is load-bearing for this slice and is
asserted in `capsule-perimeter`, not assumed here.

The recovery ISS-009 recorded is this slice's absence, priced: a hermetic reset by
hand, then a cold volume — figures in [probes](../../../docs/probes.md), which owns
them.

## Scope & Objectives

**One noun, three verbs, host-initiated, each needing an explicit slot name**
(`DEC-008`): `capsule <slot> volume {reset,reset-home,clone-from <m>}`.
`volume` is one entry in `ownVerbs`, and its branch parses the sub-verb. A bare
`capsule volume …` never resolves to the slot that is up, and `all volume` is
refused.

- **`reset`**: discard the whole volume, meaning the checkout, `$HOME`, caches,
  `/work/baseline` and the guest's ssh host keys. This is S4 without the
  hand-typed `rm -rf`. **A reset is a delete.** The runner recreates the image
  (`truncate` plus `mkfs`) when it is absent (`§5`), and `capsule-seed` re-seeds
  `/work` on every boot, so there is no re-seed logic here and never a `resize`.
  Needs the slot **stopped**.
- **`reset-home`**: all of `$HOME` (`<volumePath>/home`,
  `docs/contract-target.md`) and nothing else. `.env`, the checkout, caches and
  `/work/baseline` survive (`DEC-002`). It is done **inside the guest** by a new
  program in the image, `capsule-reset-home`, built from `vm/capsule.nix`'s own
  `home` binding. The program deletes `$HOME` and restarts `capsule-seed`; the
  host runs it over the admin door and then `inject` (`DEC-001`). Needs the
  slot **running** with no `agent` login session other than the serial console's.
- **`clone-from <m>`**: S5. A sparse copy of a stopped source's image onto a
  stopped destination, so a slot starts warm. **Any stopped declared slot other
  than the destination is a source** (`DEC-007`). The verb prints the source's
  allocated size and refuses if it exceeds free space.

**D4's identity half comes with the clone** (`DEC-003`, `DEC-011`). Scrubbing is
the default and `--identity` keeps everything. The scrub is `capsule-reset-home`,
plus every `dest` in `setup.nix`, plus every path in `services.openssh.hostKeys`,
and a guest program derives that list at eval. The scrub regenerates the host key
itself (`sshd-keygen`, then an `sshd` restart). **The scrub is fail-safe:** the
root helper writes `scrub-pending` into `/var/lib/capsule/slot/<dest>/` (a
directory the front end makes as the operator), and while that marker exists
every inject the front end runs (`start`, `setup`, `inject`, `reset-home`) runs
the scrub first, removing the marker only on success. A failed clone never
removes a marker it did not write. So no inject through `capsule` can reach an
unscrubbed clone, however the clone ended.

**And status gains a cost column instead of a `df` verb** (`DEC-009`).
`capsule all status` gets a host-side allocation column (the image's allocated
bytes, which is its high-water mark and needs no root or guest), and a
free-space line under the table. `docs/probes.md`'s disk row is refreshed.

**Gates:**

- **The name must be a declared slot, given explicitly** (`POL-003`,
  `DEC-008`). `/var/lib/microvms/capsule` and `capsule-b` exist and are refused
  as undeclared (`CHR-013`).
- **"Stopped" means the image is not open** (`DEC-004`). The front end refuses
  unless `microvm@<slot>` is `inactive` or `failed`, which is cheap and needs no
  root. The root helper then refuses if anything has the image open (`fuser`)
  immediately before it acts. This identifies the file rather than a process name
  (`mem.fact.oubliette.dead-guest-is-not-a-dead-vm`).
- **"Running and idle" means no `agent` logind session other than the serial
  console's** (`DEC-004`). The console autologins `agent`, so "any agent process"
  cannot be the test; a baseline runs detached (`setsid`) and is assumed to keep
  its ssh session listed until it exits (`ASM-001`). The refusal names
  stop-then-start as the way out, and there is no `--force`.
- **One root helper, one spelling** (`DEC-005`):
  `capsule-volume-root reset <slot>` and `capsule-volume-root clone <src> <dest>
  [--identity]` validate slots against the declared pool, resolve image paths,
  check and act in one root process, and write the scrub marker. The front end
  runs it through `sudo`, which prompts for a password on both copies of the
  front end, so no rule and no rebuild are needed. Its state roots, image owner
  and the two steps a suite substitutes are **build-time** arguments with
  defaults, never run-time ones. A password-less grant is `IMP-010`.
- **No confirmation step** (`DEC-010`). The password prompt is the second
  keystroke for `reset` and `clone-from`. `IMP-010` must reopen this if it
  removes that prompt.
- **No volume verb writes the assignment record** (`DEC-006`). The warm start is
  `volume clone-from <m>` then `setup <ref> …`. A clone carries the source's
  checkout commits and state chain, so that `setup` may need `--force`
  (`ISS-009` step 1's pre-flight).
- **Fresh host keys already have a home**: `just reset-known-hosts <slot>`
  (`mem.fact.oubliette.fresh-capsule-fresh-host-keys`).

**Documents that move in the same commit as the verbs:**
`docs/contract-assignment.md:277` (the clean-source rule is stated as not
enforced, and stays with `IMP-001`), `docs/probes.md` (the disk row), `CLAUDE.md`
(the suite list names the three new suites), and `docs/contract-target.md` only
if the guest program changes what a target may rely on.

**Verification is suites of the third kind**, because every interesting branch
is one a live host can only reach destructively. One file per program, beside
it, a function of `pkgs`, `lib` and the shipped store path, wired into
`just cases` **and** `just build` (`NOTES item 51` step 3):
- the root helper against a fixture state root, including the marker's
  ordering and ownership across a failed commit;
- the guest program against a fixture `$HOME` and fixture scrub paths, with
  sessions and units substituted;
- the front end's `volume` parsing, name requirement and refusals, and the
  scrub-before-inject gate against a marker, with the helper and door
  substituted.

What a suite cannot reach in the guest (real logind sessions, a real `sshd`
restart) is a live exercise.

## Non-Goals

- **D4's reuse-refusal on a non-clean volume**, and with it the
  `unassigned → provisioned → baselined → dirty` predicate, the enforcement of
  the clean-source rule (`DEC-007`), and the dev-host waiver. Stays with
  `IMP-001`. The host-readable half of *is this source clean* is `IMP-008`.
- **`ISS-009` step 2's composition.** Fresh-per-unit consumes `volume reset` and
  `volume reset-home`; whether that is a flag or a host declaration is decided
  there. This slice makes the verbs exist and be safe to call.
- **`resize`.** Refused rather than deferred: `§5` makes it delete-and-recreate,
  which `reset` already is.
- **`volume df`.** Replaced by the status column (`DEC-009`). Status's overall
  width is `IMP-009`.
- **A password-less grant** (`IMP-010`), and **removing the pre-slot state
  directories** (`CHR-013`).
- **Any `microvm.vms.<slot>` in `~/flakes`.** Named because it must stay absent.

## Summary

The design run's inquiry closed with eleven accepted decisions, `DEC-001` to
`DEC-011`, which replace this document's former `OQ-1` to `OQ-5`. Research
finding F4 was wrong: `$HOME` is contract-derived, which is what made `DEC-002`
cheap.

Risks and assumptions:

- **A wrong name is unrecoverable.** Mitigated by explicit declared names, state
  refusals and the password prompt. There is no undo.
- **A clone costs the source's high-water mark and stays that high** (research
  F6). The allocation column makes it visible, and the fit refusal bounds it.
  Figures live in [probes](../../../docs/probes.md).
- **`capsule-reset-home` exists only in a new image.** A slot running the old
  image fails the door call. The front end must refuse that by reason
  (`command not found` read as *restart onto the new image*), not pass it
  through as a bare error.
- **Assumed, and checked live:** a detached baseline keeps its login session
  listed until it exits (`ASM-001`), and restarting the guest's `sshd` keeps the
  admin session that runs the scrub (`ASM-002`).
- **Known boundary:** `capsule-inject` run straight off `PATH` does not pass the
  front end's gate, so it does not see a scrub marker. `capsule` is the human's
  route; the programs do not know where the record lives, by design.
- Assumed: nothing else writes `/var/lib/microvms/<slot>` while a verb runs.
  That holds because the units are ours, the helper checks the image is not
  open, and volumes are module-path slots (the devshell capsule's volume is
  `.vm/capsule/`).

Closure intent: every suite green inside `just build`, each refusal asserted
**by reason**, and each suite checked for its ability to fail by mutating the
behaviour it pins. Plus live exercises no suite can reach, on finished slots:
a real `reset`; a real `reset-home` on a running idle slot; and a real
`clone-from`, followed by a `start` that shows the scrub ran before `inject`,
that the clone's credentials and host key are its own rather than the source's,
and that the admin session survived the `sshd` restart.

## Follow-Ups

- `ISS-009` step 2, which is filed `after` `IMP-001` for exactly this reason.
- `IMP-008` (status shows a clean clone source), `IMP-009` (status width),
  `IMP-010` (password-less grant), `CHR-013` (pre-slot state directories).
- D4's reuse-refusal and Q3's state model, whenever a second principal makes it
  urgent.
- `CHR-002` is unrelated but adjacent: `handoff`'s own live path is still
  unexercised, and the first real `reset` of a finished slot is a chance to take
  more than one piece of evidence from one boot.
