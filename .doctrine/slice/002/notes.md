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

The helper and `volumeRootCases` are built as sec-3 specifies and are green. A
finding against sec-3 held the phase open until the design was revised: it is
`RV-003` `F-1`, fixed at run revision 55 (`0bd060f`) and built in the commit
after it. **What no suite reaches** is the drop itself: no sandbox has a second
uid, so the suite logs which acts went through `asImageOwner` and greps the
shipped render for its `setpriv` line. That `setpriv --reuid=microvm
--regid=kvm --init-groups` works under `sudo -k` on this host is PHASE-06
`VH-6`.

- **Root does path work in a directory the `microvm` uid can write** (as found). Read on this
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
  planned copy-failure case could not see the EXIT trap. A post-copy failure (at
  first a `chown` a non-root sandbox is refused, and after `F-1` the owner stub
  refusing the `chmod`) was added beside it.

## PHASE-02 — 2026-09-15

`capsule-reset-home` and `resetHomeCases` are built as sec-4 specifies and are
green, and the guest closure builds with the program in it (`87e682b`). The
shipped scrub list is `/work/.env` and the ed25519 host key and its `.pub`.

- **The suite runs the shipped store path as well as a render.** `loginctl` and
  `systemctl` are deliberately not in the program's `runtimeInputs` (they must be
  the running guest's), so a suite can fake them on `PATH`
  (`mem.pattern.oubliette.fake-guest-tools-on-path`). That reached the real
  session listing, which a fixture render replaces, and found a fail-open in it: a
  failed `loginctl list-sessions` inside a captured function read as "nobody is
  working" (`mem.fact.oubliette.errexit-skips-a-captured-function`). Fixed before
  commit. The same case written against the fixture had passed with the bug
  present.
- **The fake's output shape is assumed.** It is logind's `show-session -p` form
  as the program parses it. Whether a real guest prints that, and what an `agent`
  ssh login and a detached baseline report, is still PHASE-06 live exercise 2.
- **Mutations** (VA-1 plus two): the trap without the getty restart, the slice
  stop after the `rm`, the `manager` exclusion dropped, a trailing slash on the
  `rm` (it followed the symlink and deleted its target), and the listing's
  `|| return` removed. Each turned its named cases red. The trailing-slash mutant
  first died at Nix eval, which a narrow grep of the output hid; the lesson is
  appended to `mem.pattern.oubliette.a-mutation-must-reach-the-case`.
- `just build` now evaluates the guest, and so prints nixpkgs'
  `stdenv.isLinux is deprecated` warning. The warning predates this phase (HEAD
  `410e840` prints it too); it is not this repo's code.

## PHASE-03 — 2026-09-15

`capsule <slot> volume reset` and `volume clone-from <src> [--identity]` are in
the front end, and `start` holds the volume lock shared across its
`systemctl start` and stays-up check (`2bd3ddd`). `volumeCases` has 95 checks,
all green, inside `just build`.

- **Deviation from sec-7's seam table, for audit.** `volumeControl` carries
  `vmmState` (the slot's `microvm@` unit state) as well as `volumeRoot`.
  `pkgs.systemd` is in the front end's `runtimeInputs`, so in a sandbox
  `unitState` reads every unit as `--`. Every `reset` and `clone-from` would then
  refuse before the root step, and VT-2 could not be reached. Which states count
  as stopped (`inactive`, `failed`) stays in the branch's text. The precedent is
  `proxyControl`'s `proxyActive`. Sec-7's table should list the second function
  at reconcile.
- **`sudo` is not in the front end's `runtimeInputs`**, so the suite's stub `sudo`
  is what `start` runs. The stub records whether the lock was held at the moment
  of `systemctl start`. This is the host-side instance of
  `mem.pattern.oubliette.fake-guest-tools-on-path`, and it is appended there.
- **`reset-home` is not parsed yet** (PHASE-04). The name gate runs before the
  sub-verb parse, so its `CAPSULE_NAME` refusal is pinned already. An argv-named
  `reset-home` refuses as an unknown sub-verb until its branch lands, and the
  usage line leaves it out until then.
- `microvms` is spliced as a shell word (`${microvms}/"$1"/…`), like
  `moduleState`, because a fixture's quoted expression inside a quoted string
  fails shellcheck (SC2086).
- handoff's inline "source is declared" loop became `isDeclared`, shared with
  clone-from. `volumeRootCases` now reads `hostPrograms.volumeRootHelper` rather
  than a second render of it (`refactor`, after green).
- **Mutations** (VA-1 plus four), each turning exactly its named cases red:
  `-k` dropped (the shipped-render case); a `CAPSULE_NAME` name accepted; a
  resolved name accepted; `mkdir` after the root step; the lock released before
  `systemctl start`; a held lock ignored. Two of them still exit 1 for another
  reason (`reset-home` as an unknown sub-verb, and a start failing later in the
  sandbox). Only the reason checks caught those.
- Not exercised: the password prompt, real unit states, and whether the module
  copy of the front end is one store path with the devshell's. The same
  arguments are threaded at both sites, and `hostModulePrograms` evaluates, but
  nothing compares the two store paths.

## PHASE-04 — 2026-09-15

`capsule <slot> volume reset-home` is in the front end. So is the gate that keeps
credentials off a clone until it has been scrubbed, and the clone's closing
lines. `volumeCases` now has 162 checks, all green, inside `just build`.

- **The gate is `scrubPending`, called in `work()` just before it execs the
  program, and only for `inject`.** sec-7 says "at the top of `work()`" and
  sec-5 says "just before it runs `capsule-inject`". The call is below the
  `--capsule` refusal, so a command refused for its arguments deletes nothing
  first. One case pins that, and mutant (c) below turns it red.
- **Deviation for audit, beside PHASE-03's `vmmState`.** `reset-home` checks
  that a door exists (`door "$name" probe`, a `-S` test on the socket), not that
  the guest *answers* (`answers`, which runs ssh). `pkgs.openssh` is in
  `runtimeInputs`, so `answers` always fails in a sandbox and no case could get
  past it. A guest that does not answer behind the door fails the ssh call, and
  that failure is reported with its status. The flowchart's "admin door
  answers?" should read "has a door" at reconcile.
- **Every `reset-home` failure exits 1**, and the message names the guest's
  status. A front end exiting 127 would read as a missing `capsule`.
- **The clone's cost line is the helper's.** The front end does not stat the
  image a second time. The helper measured the figure under its lock and ran its
  fit check on it. `volumeRootCases` now pins that the line carries the source's
  allocation. After a successful `volumeRoot clone`, the front end adds three
  things: what the first inject will scrub (or, under `--identity`, what was
  kept), that the source was not checked for cleanliness plus `IMP-008`'s
  manual recipe, and the next commands (`just reset-known-hosts`, `start`,
  `setup`, which may need `--force`).
- `docs/contract-assignment.md` now says the clean-source rule is not enforced
  (`DEC-007`), leaves enforcement with `IMP-001`, and names the scrub marker.
- **VA-2** (the gate has no bypass inside `capsule`). `grep -n inject
  host/cli.nix` with comments stripped finds one exec, `"$prog" --capsule`
  inside `work()`. It is reached from `start`, `setup`, `reset-home` and the
  `*) work "$name" "$verb"` fallthrough. Every other mention of `capsule-inject`
  under `host/` is a comment. Running `capsule-inject` straight off `PATH` is
  the boundary sec-5 states.
- **Mutations.** Each turned only its named cases red, and each reached the
  suite (`FAIL` lines, no bare `error:`). (a) Marker removed before the scrub:
  "keeps the marker", the success order, and the marked `reset-home`. (b) Gate
  only in `start`: every inject-onto-a-clone case. (c) Gate above the
  `--capsule` refusal: "refused before any scrub". (d) No 127 arm: both
  "predates" reasons. (e) `reset-home` without its inject: both `reset-home`
  success orders. (f) The helper printing `need` rather than the allocation: the
  new `volumeRootCases` case.
- Not exercised: a real root ssh to the guest, and whether a non-interactive
  root command finds `capsule-reset-home` on `PATH` (a missing one would show as
  127, "predates"; PHASE-06 exercise 2). Also not exercised: `start` and `setup`
  reaching the gate on a live host (the sandbox's `start` fails before its
  inject), and the module copy.

## RV-004 — code review of PHASE-02..04 — 2026-09-15

Review over `410e840..97de336` (code and suites), on `RV-004` (`a9d1396`). Every
finding's **disposition holds the fix plan**, with file, line, test and mutation:
`doctrine review show RV-004`. Summary, so the order is clear:

| finding | severity | disposition | touches the design? |
| --- | --- | --- | --- |
| `F-1` 127's remedy says stop then start, which re-boots the same `current`; only `microvm -u` (`just refresh-build <slot>`) moves it | major | design-wrong | sec-2 node RG, and `slice-002.md`'s risk line (a direct edit) |
| `F-2` `scrubPending` collapses 127/3/4 into one message; the mapping is only in the `reset-home` branch | major | fix-now | sec-5 block and diagram, sec-8 `volumeCases` bullets |
| `F-3` the `manager-early` case is satisfied by `Service=login` | minor | fix-now | no |
| `F-4` target-derived `home`/`scrubPaths` spliced raw into a root `rm`; no eval guard | minor | fix-now | no |
| `F-5` `start`'s `answers()` and `setup`'s provision open an `agent@` session just before the scrub, and closing sessions count as work | minor | fix-now (PHASE-06 exercise 3, not code) | only if the live read shows it |
| `F-6` `volume reset` does not name `just reset-known-hosts` | minor | fix-now | sec-7, one sentence |
| `F-7` `vmmState` in a volume-named seam | nit | tolerated, verified | reconcile, with the PHASE-03 deviation |

**The design run was reopened for `F-1` and `F-2`** at revision 62 (locked →
reviewing), and it made `RV-005`, empty, as the earlier reopen made `RV-002`.
The relock follows the revision-60 precedent: revise sec-2, sec-5, sec-7 and
sec-8; re-attest them; conclude `RV-005`; the user accepts; lock. Then the code
and tests go red and then green against the revised text, each `RV-004` finding
is verified as it lands, and PHASE-05 starts only after that, since it edits
`host/cli.nix` and `host/volume-cases.nix` too.

**Relocked at revision 74** (materialised at 75). The user read and accepted the
revised sec-2 (127's remedy is `just refresh-build <slot>`, with why), sec-5
(`resetHomeRefusal <slot> <rc>` in the front end's main body, called by
`scrubPending` and the `reset-home` branch; 255 read as ssh's own), sec-7 (a
successful `reset` prints `next: just reset-known-hosts <slot>; capsule <slot>
start`) and sec-8 (per-status reason-and-remedy cases at both call sites, and two
mutations). `slice-002.md`'s risk line was edited directly. `RV-005` records the
pass with no new findings and is concluded. `F-1`, `F-2` and `F-6` stay
*answered* on `RV-004` until the code lands and each is verified there. A
further design pass is not needed for these: what is left to probe is whether
the code matches the text, which the mutations in sec-8 are for.

**Landing, one commit per finding.** Fix work on completed phases, so no phase
status moves.

- `F-1` + `F-2` together, as the design was relocked for them together.
  `resetHomeRefusal <slot> <rc>` is one table in `host/cli.nix`'s main body,
  called by `scrubPending` and the `reset-home` branch; 127 names `just
  refresh-build <slot>` and 255 is read as ssh's own. `volumeCases` grew one
  per-status expectation (`refusal` sets what a refusal must say and, for 127,
  what it must not; `saidWhy` asserts it) read by both the reset-home block and
  the gate loop, with 255 added to both. Both sec-8 mutations were run and read:
  dropping the call from `scrubPending` reddens the gate's per-status cases and
  leaves reset-home's green; putting stop-then-start back as 127's remedy
  reddens both 127 cases. `just` green.
  - **Restoring a mutation with `git checkout <file>` throws away an
    uncommitted fix in the same file.** It cost one re-apply here. Either commit
    the fix before mutating it, or keep the green copy aside and restore from
    that.
- `F-6`. A successful `volume reset` prints `next: just reset-known-hosts
  <slot>; capsule <slot> start`, as `clone-from` does; a refused one prints
  nothing, which `set -e` gives for free since the root step is a simple
  command. Cases: the success case sees the line, the `CASE_ROOT_FAIL` case does
  not. Mutation: move the line above `volumeRoot reset` — only the negative case
  reddens, which is what makes it discriminate.

## Harvest
<!-- single-copy: updated in place each harvest; ids only, never restated content -->
fresh-as-of: 2026-09-15 · started (PHASE-01..04 complete; design relocked at revision 74 over RV-004 F-1/F-2)

### Produced
- `design.md` sec-1..sec-8 — materialised from run `dr-01a0a2ae…`; all eight walked with the user, sec-3/4/5/7/8 revised for `RV-001` `F-1`..`F-5` (`075ead9`)
- `DEC-001`..`DEC-011` — the design's rulings, all accepted
- `IMP-008`, `IMP-009`, `IMP-010`, `CHR-013` — follow-ups filed during inquiry
- commits `78a6460`, `10d277b`, `4379895`, `075ead9`, `e3a4a90` — nothing built; one spike on slot `b` (stopped and restored its gettys and agent slice)
- `RSK-007`, `IMP-011` — filed while disposing `F-9` and `F-7`
- `RV-001` `F-11` — found while planning (the user manager is a logind session); sec-2/4/8 revised through a reopened run, `RV-002` is that pass
- `plan.toml`, `plan.md` — six phases; commits `95ccff1`, `c21a391`, `3a07fe7`
- PHASE-01: `host/volume-root.nix`, `host/volume-root-cases.nix`, `capsules.nix` `volumeLock`/`volumeReserve`, the lock's tmpfiles rule — commits `6f33e38`, `661c13c`
- `RV-003` `F-1` — found executing PHASE-01; sec-1/3/8 revised (`0bd060f`); PHASE-01 `EX-7`/`VT-5`/`VA-3` and PHASE-06 `VH-6` appended
- PHASE-02: `vm/reset-home.nix`, `vm/reset-home-cases.nix`, `vm/capsule.nix` `resetHome` + `scrubPaths` — commit `87e682b`
- PHASE-03: `host/cli.nix` `volume` verb, `nameFrom`, start lock, `microvms`/`volumeControl`; `host/volume-cases.nix`; `hostPrograms.volumeRootHelper` — commits `2bd3ddd`, `814970d`
- `RV-004` — code review of PHASE-02..04, seven findings with fix plans in their dispositions; `RV-005` is the reopened run's ledger — see `## RV-004`
- PHASE-04: `host/cli.nix` `reset-home`, `scrubPending` in `work()`, `guestResetHome`, clone output; `docs/contract-assignment.md` clean-source line — see `## PHASE-04`

### Learned
- mem.fact.oubliette.design-apply-disposes-through-checkpoints — how the run takes dispositions
- mem.fact.oubliette.guest-autologins-agent-on-every-getty — tty1 and ttyS0, and the user manager is a session too; quiesce by the user slice
- mem.fact.oubliette.nologin-is-pams-job-under-sshd — `/etc/nologin` blocks no ssh login on the guest
- mem.fact.oubliette.image-directories-are-vmm-writable — root acts in an image directory only as the image owner
- mem.pattern.oubliette.a-mutation-must-reach-the-case — read which cases went red, not the exit status; a mutant can also die at Nix eval
- mem.fact.oubliette.errexit-skips-a-captured-function — a failed listing inside `$(...)` reads as empty; `|| return`
- mem.pattern.oubliette.fake-guest-tools-on-path — tools left out of `runtimeInputs` let a suite run the shipped store path; a stub `sudo` for host/cli.nix (PHASE-03)

### Open
- `RV-004` `F-1`..`F-6` — dispositioned, not yet fixed; the design text for `F-1`/`F-2`/`F-6` is locked (revision 74), the code is next
- `ASM-001` — a detached baseline keeps its logind session (live exercise 2, PHASE-06)
- `Service`/`Class` of an `agent` ssh login and of a detached baseline — unread (live exercise 2)
- `ASM-002` — restarting guest sshd keeps the admin session (live exercise 3, PHASE-06)
- the `setpriv` drop under `sudo -k` on this host — no suite reaches it (PHASE-06 `VH-6`)
- sec-7's seam table lacks `vmmState` — deviation recorded in `## PHASE-03`, for reconcile
- sec-2's flowchart asks "door answers?"; the front end asks "has a door" — deviation in `## PHASE-04`, for reconcile
- a non-interactive root ssh finds `capsule-reset-home` on `PATH` — else 127 misreads as "predates" (live exercise 2)
- `notHeld` fails open if `fuser` itself errors — noted in `## PHASE-01`, not filed
- the real `loginctl` output against `agentSessions`'s parser — the suite's fake is an assumed shape (live exercise 2)
