# Implementation Plan SL-002: Volume verbs, and a clone that does not carry an identity

Prose companion to `plan.toml`. Narrative only — no queried data lives here
(the storage rule); the phase list, criteria, verification, and links are
authored in the TOML. Use this for the plan's rationale and sequencing.

## Overview

Six phases. The first two build the two new programs, each with its own suite
and nothing calling it. The next three grow the front end in three cuts: the
host-side verbs, the guest-side verb and its gate, then status. The last runs the
live exercises no suite can reach.

```
PHASE-01 root helper ──► PHASE-03 volume verb ──┬──► PHASE-04 reset-home + gate ──┐
                                                └──► PHASE-05 status ──────────────┼──► PHASE-06 live
PHASE-02 guest program (independent) ──────────────────────────────────────────────┘
```

## Sequencing & Rationale

**Programs before their caller.** `design.md` sec-1 gives four parts with one
direction of dependency: the front end calls the root helper by store path and
the guest program over the admin door; neither program knows the front end.
Building each program first, pinned by its own suite, means the front end's
phases substitute a program whose exit statuses and refusals are already fixed
rather than designed at the same time as their caller.

**One suite per program, landing with it.** `CLAUDE.md` requires a suite to be
in `just build` in the commit that adds it (`NOTES item 51` step 3), so wiring
and the suite-list edit are exit criteria of the phase that adds the suite, not
a clean-up phase at the end. The same holds for the documents sec-8 names: each
moves in the phase whose behaviour it describes.

**The front end in three cuts.** `host/cli.nix` is 2,200 lines, and the volume
work touches it in four places (the verb, `work()`, `start`, status). PHASE-03 is
the part with no guest in it: parsing, the name rule, the two root sub-verbs and
the start lock. PHASE-04 adds the part that talks to a guest. It stubs the guest
program's exit statuses from sec-4, so it does not wait for PHASE-02; the two
meet only in PHASE-06. PHASE-05 is status, which shares only the `microvms`
argument with the rest.

**Live last, and the user's.** Sec-8's live exercises need root, a rebuilt host
and a slot that can be destroyed. They settle `ASM-001` and `ASM-002`, which the
design carries as assumptions.

**Every render of the front end moves together.** `host/cli.nix` is rendered in
three places today: `flake.nix`'s `capsule-cli` (the devshell copy),
`host/services.nix` (the module copy) and `host/policy-cases.nix`, which
re-renders it against a fixture pool. The helper's store path is a new required
argument, so PHASE-03 threads it from `hostPrograms` to all three at once; missing
the third turns `policyCases` red for a reason unrelated to volumes.

**The eval-level scrub-list check reads what ships.** `scrubPaths` is a `let` in
`vm/capsule.nix`. Recomputing it in the suite would be a second implementation
that agrees with itself. PHASE-02 exposes it on the program as `passthru`, and
the suite finds that program in the evaluated guest's `systemPackages`, failing
when it is not found, so a rename cannot make the check pass vacuously.

## Notes

**Read on slot b, 2026-09-15, read-only over the admin door** (these back
PHASE-02's EN-2 and clear three plan risks):

| session | TTY | `Service` | `Class` |
| --- | --- | --- | --- |
| agent autologin | tty1 | `login` | `user` |
| agent autologin | ttyS0 | `login` | `user` |
| agent's user manager | - | `systemd-user` | `manager` |
| root over the admin door | - | `sshd` | `user` |
| root's user manager | - | `systemd-user` | `manager-early` |

- **The user manager is a logind session.** A filter of "`Service` is not
  `login`" lists it on every guest, so `reset-home` would always refuse. That
  contradicted design sec-2 and sec-4 as first locked. It went back to the design
  as `RV-001` `F-11`: the rule now also excludes `Class` `manager` and
  `manager-early`, and only the session listing is stubbed, so the suite runs
  the filter itself.
- **Cleared:** `/etc/pam.d/runuser` has no `pam_systemd`, so `capsule-seed`'s
  `runuser` opens no session and cannot trip sec-4 step 7. `sshd` has
  `KillMode=process` and `Wants=sshd-keygen.service`, and `sshd-keygen` has
  `RemainAfterExit=no` (sec-4 step 6's premises).
- **Cleared on this host:** `systemd-tmpfiles` 261 creates a missing parent for an
  `f` rule (tried with `--root` in a scratch directory). `/run/capsule` is
  otherwise made only by each relay unit's `RuntimeDirectory`, so the lock file's
  one rule does not need a `d` rule before it.
