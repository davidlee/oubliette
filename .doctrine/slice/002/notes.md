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
- `F-3`. The `manager-early` row was spelled `Service=login`, so the getty
  exclusion passed it and the case was green whatever the `manager-early` clause
  did. Row is now `systemd-user`, which is what a real one is. Read both ways:
  deleting the clause with the old row leaves the case green; with the new row
  it goes red. Test-only — `vm/reset-home.nix` is unchanged.
- `F-4`. `vm/guest-path.nix` is the guard: one function, `what: path`, that
  returns the path or throws unless it matches `^/[A-Za-z0-9._/@+-]+$`.
  `vm/capsule.nix` puts `home` and every `scrubPaths` entry through it;
  `vm/reset-home.nix` still takes raw shell expressions, so the fixture is
  unaffected, and its header now says where the check lives. It is its own file
  rather than a `let` in capsule.nix so the suite takes it as an argument
  instead of re-rendering it. `resetHomeCases` reads five `builtins.tryEval`
  verdicts at eval and asserts them in the shell, plus one over the list the
  *image* carries. Mutation: widen the class to `.*` and the four negative
  verdicts redden.
  - **Open, and a gap of the kind CLAUDE.md names:** the suite pins the guard,
    not that `vm/capsule.nix` calls it. Dropping the call changes nothing
    observable for a good target, and catching it needs the guest evaluated
    against a *hostile* `target`, which means `mkVm` parameterised by target and
    a second full NixOS eval in `just build`. Not taken for a minor finding
    whose agreed fix plan was the function; for reconcile.
  - A new file must be `git add`ed before nix can see it: a dirty `git+file:`
    tree still only exposes tracked paths.
- `F-5`. No code. `VH-7` appended to `plan.toml` PHASE-06 and mirrored into the
  phase sheet as a **STOP condition**: if a post-clone `start` refuses the scrub
  as busy, read `loginctl` at that moment for a closing `agent` sshd session the
  front end's own `waitAnswers` (or `provisionSlot`) left. If one is there the
  idle rule counts the front end's own traffic as work, and that reopens the
  design rather than getting patched in code.
- **Criteria appended, never renumbered**, so the plan says what shipped:
  PHASE-02 `EX-6`/`VT-5`/`VA-2` for the guard, PHASE-04 `EX-6`/`EX-7`/`VT-3`/
  `VT-4`/`VA-3` for the shared refusal and the reset's next step. `doctrine
  slice verify-vt SL-002` passes every VT on PHASE-01..04; PHASE-05's `VT-1`
  fails because PHASE-05 has not run.
- **`RV-004` concluded**, all seven findings terminal (F-1..F-6 verified, F-7
  tolerated-verified). `## Synthesis` on the prose ledger: **acceptable** — the
  marker invariant, the name gate and the suites that read the shipped image
  held; what the pass found was operator guidance and one case that could not
  fail. Carried to reconcile: `ASM-001` unsettled with `F-5` as a PHASE-06 STOP
  condition, `F-4`'s uncalled-guard gap, `F-7`'s seam.

## PHASE-05 — status shows what a volume costs — 2026-09-17

`alloc` after `disk`, and the `volumes:` line between the table and
`perimeter`. Both are filesystem reads — `stat -c '%b * %B'` and
`df --output=avail -B1`, the same two the root helper's fit check makes — so
they need neither root nor the guest, and `alloc` is the one measured cell a
**stopped** slot fills. Allocated, not apparent: it is the high-water mark, so
`alloc` and the free line together predict the helper's refusal without running
it.

- **The parenthesis counts state *directories*, not images.** sec-6's rule
  sentence says directories; its sample line words them "images" because on
  this host both have one. A leftover with no image must still be seen
  (`CHR-013`), so the noun went: `(2 outside the pool: capsule, capsule-b)`.
  **Wording deviation from sec-6's sample — for reconcile.**
- **`status` died on a host with no image root**, and `policyCases` caught it:
  it takes the default `/var/lib/microvms` and runs in a sandbox that has none,
  so `df` under `set -e` took the verb down. That is the devshell path on a
  fresh machine, not a corner. The line now says what it found. `EX-5`/`VT-2`
  appended while executing.
- Four mutations, each read for *which* cases reddened: the parenthesis without
  its declared-slot filter; `alloc` filled only for a running slot; apparent
  size instead of allocated (a 4 GiB sparse image reads `4.0G` where the case
  wants `0`); the absent-root guard removed.
- **`RV-004` `F-7` did not bind.** Both additions are filesystem reads, so no
  second unit-state seam was needed and `vmmState` was not touched.
- **Lifted from the phase sheet: block accounting is not apparent size.** `%b *
  %B` on a *fully written* file can exceed its apparent size by its indirect
  blocks, so a case asserting an exact figure is flaky by construction. If
  `3.0M` ever goes red, assert the **unit suffix** rather than loosening to "not
  `-`", which would stop discriminating between a sparse image and a written
  one — the distinction the column exists for.
- `EX-3` + `VA-1`, live and read-only: `df /var/lib` is **92 GiB of 1.78 TiB,
  95% used** (was 166 GiB / 91% on 2026-08-13). `EVD-009` supersedes `EVD-005`.
  `capsule all status` read `alloc` for the three stopped slots — `a` 3.3G, `d`
  6.8G, `e` 1.6G — `-` for the never-created ones, a free figure matching `df`
  exactly, and the parenthesis surfaced `CHR-013`'s two leftovers.

## PHASE-06 — the five live exercises — 2026-09-17

Root, a real image, a real guest, on slot `a` (destination) cloned from `d`,
with `e` in the lock race. Capsule `c` was never named. All seven `VH` criteria
satisfied; **`ASM-001` and `ASM-002` both validated**; `VH-7`'s STOP condition
did not fire.

**The entrance criteria were not met when the phase opened, and the check that
found it is worth keeping.** The host ran a `capsule` **18 commits behind** —
volume verbs present, but no `resetHomeRefusal`, no `just refresh-build` remedy,
no `alloc`, so none of the `RV-004` remediation and none of PHASE-05. `a`'s guest
closure was from **7 August** and carried no `capsule-*` program at all. Both
were fixed by the user (rebuild from `~/flakes`, then `just refresh-build a`,
which keeps the volume). Running the exercises before that would have verified
the old program against messages the design no longer says — a pass for the
wrong reason. **Two of my own readings were wrong first**: store-path equality
between the devshell and module copies (which proves they are the same *build*,
not that either is current), then `readlink -f` on the **wrapper**, which holds
none of the program's text. `mem.fact.oubliette.module-programs-on-path-are-wrappers`
already records both traps; it was not retrieved before the check. Both memories
extended with the new readings.

**Exercise 2 ran first, against sec-8's numbering** — exercise 1 destroys the
volume and exercise 2 needs a provisioned one for its detached baseline. The
exercises are a set, not a sequence.

### 1 — `volume reset` (`VH-1`)

Reset deleted the image and printed `F-6`'s `next:` line; `a` stayed
`created yes` with `current` and `flake` intact, so **created is not "has an
image"** — which is what let exercise 3 clone onto it. A cold `start` made a
32 GiB sparse image reading **`alloc 261M`**: sec-6's "allocated, not apparent",
first live reading. The `fuser` refusal fired with the **unit inactive** and the
image held by an unprivileged `sleep 400 < …img`, naming the pid — the front
end's unit check passed and the root helper caught it in the same process. A
second reset over the absent image said *already fresh*.

*Not exercised:* a holder that is a real VMM rather than an unprivileged reader;
the refusal names a file's holder either way, which is the point.

### 2 — `volume reset-home` and the session rule (`VH-2`, `ASM-001`)

Sec-2's table reproduced exactly, and its **two unread rows filled**: an `agent`
ssh login is `Service=sshd Class=user`, and a real `manager-early` (root's user
manager, raised by the admin login) is `Service=systemd-user` — which confirms
`RV-004` `F-3`, whose suite row had been spelled `Service=login` and so passed
through the getty exclusion for the wrong reason.

Refused with an ssh session open (listing only it, both autologins and the
manager correctly excluded); refused with a detached baseline; succeeded idle,
then ran `work a inject`. Afterwards **both gettys were back with `agent` logged
in on `tty1` and `ttyS0`** and sec-2's three-session table was restored.
`/work/doctrine` survived at `6287a4170` — `$HOME` is `/work/home`, a sibling of
the checkout, so the delete is scoped.

**`ASM-001` → validated.** A Ctrl-C'd baseline's sshd logged
*"Received disconnect … disconnected by user"* and **the scope survived it**,
build inside, session pinned in `closing`.

*New, and not in the design:* a baseline leaves **two** agent sessions — the
detached run (`closing`) and a **log tail** over a second ssh that stays
`active` after its host client dies, because `tail -f` blocks without writing.
Recorded as `mem.fact.oubliette.a-detached-baseline-leaves-two-agent-sessions`.

*Not exercised:* `pam_nologin` (`IMP-011`) — a login arriving *during* a reset is
still only detected, and no run here raced one.

### 3 — `volume clone-from` and the scrub (`VH-3`, `VH-6`, `VH-7`)

Host keys live at **`/work/ssh/`, on the volume**, named by `sshd_config`'s
`HostKey` — which is why a clone inherits identity. `d`'s
`SHA256:3DFzu…` became `a`'s `SHA256:DxNDz…` after the scrub; credentials went
from `d`'s 921/41157 bytes to this host's 914/1001; `/work/doctrine` and
`/work/baseline` carried over. The gate ran **scrub, marker removed, inject** in
one invocation.

`VH-6`: the clone is `microvm:kvm 644` and **`grep -c chown host/volume-root.nix`
is 0** — there is no `chown` to have run; ownership comes from `asImageOwner`
(`setpriv --reuid=microvm --regid=kvm --init-groups`). With `d`'s image replaced
by a symlink to `/etc/shadow`, the copy failed `Permission denied` and left **no
`capsule-work.img.clone` and no marker**.

**`ASM-002` → validated.** `sshd`'s `ActiveEnterTimestamp` moved during the
scrub and the scrub still returned 0 over that same admin session, not 255:
`KillMode=process` replaced the listener and kept the established session.

**`VH-7` did not fire**, and it was probed in isolation rather than merely
observed not to happen: `ssh agent@guest true` — `waitAnswers`' exact shape —
leaves no session at the gap the scrub occupies, read three times, with a
`setsid sleep 60 &` control proving the read discriminates. The premise holds
(a `closing` session **does** refuse, seen twice), so **`RV-004` `F-5` is sound
in shape and wrong about this probe**. Recorded as
`mem.fact.oubliette.a-closing-session-lives-as-long-as-its-work`.

*Not exercised, and it is the remaining half of `F-5`:* `setup`'s
`provisionSlot` push is a **heavier** probe than `true` and was never run this
way. If any probe reproduces `F-5`, it is that one.

*Not exercised:* the clone trap. `cp` refuses **before creating anything**, so
the failed-copy case cannot see the trap — `volumeRootCases` says so and the live
run agreed. **The trap's removal of a partial `.clone` is a suite-only
guarantee** and should be stated that way, not counted as live-verified.

### 4 — `alloc` and the free line (`VH-4`)

Four samples. `alloc` filled for every stopped slot and `-` for the
never-created; `a` tracked `3.3G → - → 261M → 6.8G` across the exercises. The
free line moved 88G → 90G → 81G. **It is a whole-filesystem `df`, so a live
capsule moves it**: the 9G drop against a 6.7G clone is `c` growing underneath.
`CHR-013`'s two out-of-pool leftovers surfaced in every sample.

### 5 — one volume operation at a time (`VH-5`)

`/proc/locks` sampled passively (a shared lock of mine could have made the clone
refuse spuriously) showed **two distinct exclusive holders**, one per clone run —
independent of anything the program printed. `capsule e start` refused by reason
twice against a real clone; `capsule a volume reset` refused on the same lock and
printed **no** `next:` line, `set -e` having left first. `capsule e start`
succeeded the moment the lock was free.

*What the evidence covers (`STD-001`):* the `start` refusal was taken against a
**real clone**; the `reset` refusal against a lock **held synthetically** by an
unprivileged `flock -x`, because a 6.7 GiB copy gives ~17 s and the `sudo -k`
prompt eats most of it. Same lock, same branch, same refusal text — but the
reset half holds only **"`volume reset` refuses while `capsules.volumeLock` is
held exclusively"**, which is what `volumeCases` already pins against a fixture
lock. It does **not** hold `VH-5`'s "refuses while a clone is running". The
`start` half does, and keeps the stronger claim.

### Other observations

- **The marker invariant, live.** Two clones back to back; the marker kept the
  **first** one's timestamp. `host/volume-root.nix` writes it *unless one is
  already there*.
- **Inject's two branches in one session.** Nothing skipped on `a`'s scrubbed
  `$HOME`; both skipped as *already there* on `e`'s existing one.
- **Unverified sub-claim for reconcile:** sec-4 step 5 says `capsule-seed`
  "re-links the config files"; the reset `$HOME` held no symlinks. Either this
  target declares none or they are conditional.
- **`git` over the admin door fails** on an agent-owned checkout with
  `detected dubious ownership` — read a checkout as `agent`, not root.

### Which task satisfied which criterion

Lifted from the phase sheet, which is disposable; `notes.md` said only "all
seven".

| criterion | verdict |
| --- | --- |
| `VH-1` | ✓ T2 — reset, cold start, `fuser` refusal by pid with the unit inactive, already-fresh |
| `VH-2` | ✓ T1a–T1d — both autologins and the ssh row read, two refusals, idle success, gettys back |
| `VH-3` | ✓ T4 — scrub before inject, this host's credentials, fingerprint differs, session survived |
| `VH-4` | ✓ four samples (T0, T2, T4, T5) |
| `VH-5` | ✓ T5 — with the caveat on which half saw a real clone |
| `VH-6` | ✓ T3 (no `.clone`, no marker) + T4 (`microvm:kvm 644`, zero `chown` in the helper) |
| `VH-7` | ✓ STOP condition did not fire; probed in isolation and does not reproduce |

**The research baseline reports drift and was not refreshed, on purpose.**
`doctrine slice research SL-002`'s additions are `design.md`, `plan.toml` and
`plan.md` — research predates design, which is the normal order. Nothing in this
phase load-bears on `research.md`, and its one finding this slice relied on (F4,
that `$HOME` is not contract-derived) was already recorded as **wrong** in
`## Design triage`. Noted rather than silently skipped.

### Terminal state

`a` is a clone of `d` with a scrub marker pending, stopped; its next `start`
scrubs and injects. `d` and `e` are stopped and unchanged — `d`'s image was
restored byte-identical (owner, mode, size, allocated blocks, mtime) and
verified before anything read from it. `c` untouched throughout.

## Audit — RV-006 — 2026-09-17

The closure audit. Thirteen findings, **no blockers**; ledger `done`, every
finding terminal. Reasoning is `RV-006`'s `## Synthesis`, the worklist for
`/reconcile` is its `## Reconciliation Brief`. What is worth keeping here:

- **The deleting held.** Every finding that touches behaviour is about a
  **check**, not a delete: a guard whose call site nothing pins (`RSK-008`), a
  `fuser` test that fails open (`ISS-010`), a probe that answered half its
  question (`CHR-014`). The marker invariant, the name gate and the lock all
  came through unmarked.
- **A second registry defect, not in the handover's list.** PHASE-06's
  `boundaries.toml` row was `421392b..0ab598b` — an unrelated `chore:` commit —
  and excluded `fdfad31`, the phase's own. `justfile` was already delivered by
  PHASE-01..03, so no cell moved and conformance could not see it. Found by
  reading `boundaries.toml` against `git log --reverse`, which is now
  `mem.pattern.oubliette.a-wrong-phase-range-is-invisible-to-conformance`.
- **`review_pass STALE` is real about the snapshot and false about the review.**
  `[review.pass].covered` holds the revision-58 attestation set; the revision-72
  disposal updated the review id beside it and left it. All eight sections carry
  a current attestation and `cpa-design-accepted` covers the current
  fingerprints, so the lock is what it looks like. Recorded as
  `mem.fact.oubliette.review-pass-stale-is-a-snapshot-not-a-gap`; the defect is
  the doctrine CLI's, not this repo's.
- **`docs/contract-target.md` was fixed in the audit** (`F-1`): `volumePath` now
  states the `^/[A-Za-z0-9._/@+-]+$` constraint `vm/guest-path.nix` enforces and
  why, and the `$HOME` row says it is a sibling of the checkout rather than a
  parent. A guard that throws at guest eval is a supply requirement, and the
  contract is where a target reads one.
- **Six design deviations, not five.** The sixth settles `notes.md`'s own
  unverified sub-claim: sec-4 step 5's "re-links the config files" reads as
  though they are in `$HOME`; `vm/capsule.nix:71-76` writes them to
  `${work}/${path}` — for this target `/work/.cargo/config.toml` — so the reset
  `$HOME` holding no symlinks is the expected result, not a gap.
- **`doctrine check gate` does not run in this repo** (`CHR-015`). The gate was
  run directly: `just check` ok, `just` exit 0 over build, `hostModuleUnits`,
  fourteen `*Cases` suites and fmt; `verify-vt` passes every `VT` on
  PHASE-01..05.

## Reconcile — RV-006 — 2026-09-17

`RV-006`'s brief written through. Structured tier first, prose second; no `REV`
(`SL-002` carries no specs and no requirements, and no policy or ADR moved).

- **The registry now delivers what the slice built.** `vm/guest-path.nix` and
  `host/policy-cases.nix` were the two gaps; both are `conformant`.
  `undelivered` is **0**, `conformant` 15 → **17**.
- **PHASE-06's row was replaced** — `0ab598b..fdfad31`, the phase's own evidence
  commit, in place of `421392b..0ab598b`, which covered an unrelated `chore:`
  `justfile` change and excluded `fdfad31`. No conformant cell moved; the whole
  cost had been attribution.
- **PHASE-04's row was widened, and it over-attributes.** `6d101b0..8cb44df`
  brings the eight `RV-004` remediation commits into the registry, which is what
  moves `vm/guest-path.nix`. `record-delta` UPSERTs **one contiguous range per
  phase**, so there is no shape that takes the fixes without the window around
  them. **Six commits in that window (`a9d1396..a12865e`) belong to no slice**,
  and `README.md`, `docs/contract-doctrine.md` and `flake.lock` are in the
  `undeclared` cell because of them, not because `SL-002` touched them. The
  ruling was to widen and write the cost down rather than leave conformance red
  with no record of why — **so the next reader of `boundaries.toml` should read
  PHASE-04's range as a superset, not as a claim**.
- **`undeclared` went 14 → 46**, more than the audit's estimate of +3. The three
  extra non-`.doctrine` paths were predicted exactly; the rest is `.doctrine`
  bookkeeping the wider window sweeps in — four `backlog/`, two `knowledge/`,
  three `review/` and several `memory/` items — and no source selector should
  ever claim any of it. The count is noise, the three paths are the cost.
- **Six design deviations landed in `design.md`** (sec-2 ×2, sec-4, sec-6 ×2,
  sec-7) and `VH-5`'s reset half is now stated at its evidence in exercise 5.
  Details in `RV-006`'s `## Reconciliation Outcome`.
- **The brief's own finding citations are crossed** for three items: `F-2`'s
  *detail* is the PHASE-04 gap, `F-3`'s the PHASE-06 row, `F-4`'s the sec-8
  table, but each finding's *response* — and the brief written from them — names
  the next one along. The work was unambiguous by content; the outcome is
  recorded against the finding whose detail states the defect.

## Harvest
<!-- single-copy: updated in place each harvest; ids only, never restated content -->
fresh-as-of: 2026-09-17 · close · `99d9875` — brief written through; registry repaired, six deviations landed

### Produced
- `design.md` sec-1..sec-8 — materialised from run `dr-01a0a2ae…`; all eight walked with the user, relocked at revision 74/75 after `RV-004`
- `DEC-001`..`DEC-011` — the design's rulings, all accepted
- `plan.toml`, `plan.md` — six phases
- PHASE-01: `host/volume-root.nix`, `host/volume-root-cases.nix`, `capsules.nix` `volumeLock`/`volumeReserve`, the lock's tmpfiles rule — `6f33e38`, `661c13c`
- PHASE-02: `vm/reset-home.nix`, `vm/reset-home-cases.nix`, `vm/capsule.nix` `resetHome` + `scrubPaths` — `87e682b`
- PHASE-03: `host/cli.nix` `volume` verb, `nameFrom`, start lock, `microvms`/`volumeControl`; `host/volume-cases.nix`; `hostPrograms.volumeRootHelper` — `2bd3ddd`, `814970d`
- PHASE-04: `host/cli.nix` `reset-home`, `scrubPending` in `work()`, `guestResetHome`, clone output; `docs/contract-assignment.md` — see `## PHASE-04`
- PHASE-05: `host/cli.nix` `allocOf`/`imageOf`/`volumes` + the `alloc` column; `host/policy-cases.nix`; `docs/probes.md` disk row; `EVD-009` — `f3eec1b`, `7f670dd`
- PHASE-06: the five live exercises, evidence only — `fdfad31`
- `RV-001`..`RV-005` — three design passes, one reopened run, one code review; all concluded. `RV-004`'s fixes landed one commit per finding, `7259d03`..`8cb44df`
- `RV-006` — the closure audit; 13 findings, no blockers, `## Synthesis` + `## Reconciliation Brief` on the ledger
- `docs/contract-target.md` — `volumePath`'s format constraint and `$HOME`'s scope, fixed under `RV-006` `F-1`
- minted this slice: `IMP-008`, `IMP-009`, `IMP-010`, `IMP-011`, `CHR-013`, `RSK-007`
- the reconcile pass — `9f5568e`, `99d9875`: `host/policy-cases.nix` declared
  `design-target`; PHASE-04 and PHASE-06 `record-delta` rows corrected
  (`undelivered` 1 → 0, `conformant` 15 → 17); six design deviations in
  `design.md` sec-2/4/6/7/8; `VH-5`'s reset half restated in `## PHASE-06`;
  `RV-006`'s `## Reconciliation Outcome`; `notes.md` `## Reconcile — RV-006`
- minted at the audit: `RSK-008` — the guest-path guard's call site is unpinned; `CHR-014` — probe `setup`'s `provisionSlot` push against the scrub gate; `ISS-010` — `notHeld` fails open when `fuser` errors; `CHR-015` — declare this project's gate for `doctrine check`

### Learned
- mem.fact.oubliette.design-apply-disposes-through-checkpoints
- mem.fact.oubliette.guest-autologins-agent-on-every-getty
- mem.fact.oubliette.nologin-is-pams-job-under-sshd
- mem.fact.oubliette.image-directories-are-vmm-writable
- mem.pattern.oubliette.a-mutation-must-reach-the-case
- mem.fact.oubliette.errexit-skips-a-captured-function
- mem.pattern.oubliette.fake-guest-tools-on-path
- mem.fact.oubliette.git-checkout-restores-more-than-the-mutation
- mem.fact.oubliette.a-new-file-must-be-git-added-before-nix-sees-it
- mem.fact.oubliette.a-closing-session-lives-as-long-as-its-work
- mem.fact.oubliette.a-detached-baseline-leaves-two-agent-sessions
- mem.fact.oubliette.module-programs-on-path-are-wrappers — extended
- mem.fact.oubliette.fresh-capsule-fresh-host-keys — extended
- mem.pattern.oubliette.a-wrong-phase-range-is-invisible-to-conformance — from the audit
- mem.fact.oubliette.review-pass-stale-is-a-snapshot-not-a-gap — from the audit
- mem.fact.oubliette.reconcile-edits-are-invisible-to-the-design-run — from the
  reconcile; the materialise half is inferred from the verb's contract, unobserved
- `EVD-009` — the disk row, re-measured; supersedes `EVD-005`

### Open
`RV-006`'s brief is **written through** — `F-2`, `F-3`, `F-4`, `F-7` and `F-8`
are recorded in its `## Reconciliation Outcome` and need nothing further. What
leaves the slice as owned work, by id:

- `RSK-008` — the guard is pinned, its call site is not; needs the guest
  evaluated against a hostile `target`
- `CHR-014` — `RV-004` `F-5`'s remaining half: `setup`'s `provisionSlot` push
- `ISS-010` — `notHeld` fails open if `fuser` itself errors
- `CHR-015` — `doctrine check gate` resolves to a recipe this project lacks
- Tolerated, no owner: `RV-006` `F-5` (the doctrine CLI's stale pass snapshot),
  `F-13` (`selector doctor`'s three redundancy findings would break conformance
  if acted on)
- Standing, by ruling rather than by defect: **PHASE-04's recorded range is a
  superset**. `record-delta` takes one contiguous range per phase, so the eight
  `RV-004` fixes could not be brought in without the six unrelated commits around
  them. `## Reconcile — RV-006` names them and the three paths they put in the
  `undeclared` cell
