# Notes SL-002: Volume verbs, and a clone that does not carry an identity

Durable per-slice scratchpad — tracked in git. The place to lift anything from a
disposable phase sheet (`.doctrine/state/.../phase-NN.md`) that must survive
`rm -rf` before the slice close-out audit harvests it.

## Design triage — 2026-09-15

Exploring-stage triage, superseded by the design run's decisions
(`DEC-001`..`DEC-011`) and `design.md`. What survives that the run does not hold:

- **Research F4 was wrong.** `$HOME` is contract-derived
  (`docs/contract-target.md:274`), so `research/research.md`'s F4 and OQ-6 should
  not be relied on.
- **Disk was 108 GiB free, 94% used on 2026-09-15** (`df /var/lib`), against
  86 GiB on 2026-08-18. `docs/probes.md` still says 166 GiB; its refresh is in
  sec-8.

## Review passes — 2026-09-15

The findings and their rulings are on `RV-001`; this section says only what is
still worth attacking.

- **Pass 1**, the user's walk with the agent checking claims against code:
  `F-1`..`F-5`.
- **Pass 2**, Codex's adversarial review plus a live spike on slot `b`:
  `F-6`..`F-10`. It reached two decisions (`DEC-004`'s idle test, `DEC-010`'s
  premise) and a measured disk limit. **Pass 1's note said the design could lock
  without a second pass, and that was wrong**: its own items 1–2 came back as
  majors, and the spike found a blocker (`F-10`, the tty1 autologin) that no
  reading of the design could have.

**What a further pass would probe:**

1. **The quiesce, live.** The `Service` values `workingSessions` filters on have
   not been read (sec-8 live exercise 2), and neither has what `stop
   user-<uid>.slice` does to a detached baseline if `ASM-001` is false: the
   baseline would be killed rather than refused.
2. **Pre-existing state**, `F-1`'s class, still unswept: a marker left under
   `reset` by a crash, a `capsule-work.img.clone` from a killed run while that
   slot is running, a marker naming a source other than the current clone's.
3. **The lock's composition.** Checked: the only start of a slot's unit is
   `host/cli.nix:1442`, and the probes run the runner in their own directories.
   Not checked: a host rebuild or `daemon-reload` interacting with a held lock.

**Whether one is needed:** items 1 and 2 are cheap and concrete: 1 is a live
exercise already in sec-8, and 2 is a read of sec-3 against its crash table.
Neither is likely to move a decision. Lock after the user has read the revised
sec-2..8; run item 2 as part of that read rather than as a separate pass.

## PHASE-01 — 2026-09-15

The helper and `volumeRootCases` are built as sec-3 specifies and are green, but
**a finding against sec-3 holds the phase open**.

- **Root does path work in a directory the `microvm` uid can write.** Read on this
  host: `/var/lib/microvms` is `microvm:kvm 0775`, each `/var/lib/microvms/<slot>`
  is `root:kvm 0775`, and `microvm` (uid 970) is in `kvm`. Every running VMM is
  that uid, whichever slot it serves. Sec-3's `clone` does `rm` then `cp`,
  `chown` and `chmod` on the fixed name `capsule-work.img.clone`, and `cp` reads
  `img(src)`, all by path, as root. A VMM on another slot can swap either name
  for a symlink between steps. Root would then `chown` an arbitrary file to
  `microvm:kvm`, `chmod` one `0644`, overwrite one, or copy a file `microvm`
  cannot read into an image it can. `reset`'s `rm -f` and the trap's `rm -f`
  unlink a fixed basename, so at worst they delete a file of that name elsewhere.
  Nothing calls the helper yet, and no sudo rule or `PATH` entry reaches it.
- **`notHeld` fails open if `fuser` errors.** `fuser` exits 1 both for "nothing
  holds it" and for errors. The existence check before it removes the common
  error. What remains is `/proc` unreadable to root, which is not a state this
  host is in.
- **Mutation practice:** a mutation that leaves a variable unused dies at
  shellcheck, before any case runs, which can read as "the suite caught it".
  And `cp` refuses an unreadable source before creating anything, so the
  planned copy-failure case could not see the EXIT trap. A post-copy failure (a
  `chown` a non-root sandbox is refused) replaced it.

## Harvest
<!-- single-copy: updated in place each harvest; ids only, never restated content -->
fresh-as-of: 2026-09-15 · ready (design locked at run revision 53; plan PHASE-01..06 materialised)

### Produced
- `design.md` sec-1..sec-8 — materialised from run `dr-01a0a2ae…`; all eight walked with the user, sec-3/4/5/7/8 revised for `RV-001` `F-1`..`F-5` (`075ead9`)
- `DEC-001`..`DEC-011` — the design's rulings, all accepted
- `IMP-008`, `IMP-009`, `IMP-010`, `CHR-013` — follow-ups filed during inquiry
- commits `78a6460`, `10d277b`, `4379895`, `075ead9`, `e3a4a90` — nothing built; one spike on slot `b` (stopped and restored its gettys and agent slice)
- `RSK-007`, `IMP-011` — filed while disposing `F-9` and `F-7`
- `RV-001` `F-11` — found while planning (the user manager is a logind session); sec-2/4/8 revised through a reopened run, `RV-002` is that pass
- `plan.toml`, `plan.md` — six phases; commits `95ccff1`, `c21a391`, `3a07fe7`

### Learned
- mem.fact.oubliette.design-apply-disposes-through-checkpoints — how the run takes dispositions
- mem.fact.oubliette.guest-autologins-agent-on-every-getty — tty1 and ttyS0, and the user manager is a session too; quiesce by the user slice
- mem.fact.oubliette.nologin-is-pams-job-under-sshd — `/etc/nologin` blocks no ssh login on the guest

### Open
- `ASM-001` — a detached baseline keeps its logind session (live exercise 2, PHASE-06)
- `Service`/`Class` of an `agent` ssh login and of a detached baseline — unread (live exercise 2)
- `ASM-002` — restarting guest sshd keeps the admin session (live exercise 3, PHASE-06)
