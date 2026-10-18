# Programs bring their own tools: session's base tools and the profile reader's jq

## Context

Two programs find a tool on whatever `PATH` they inherit, and nothing promises
that `PATH`. Both work on this host only because the `PATH` they inherit
happens to hold the tool.

```
room guest                              this host
──────────                              ─────────
session <repo> -- argv                  capsule-provision, capsule-collect,
  PATH = tools/bin : $PATH                capsule-refresh, capsule-brief,
              │         │                 capsule-baseline
     repo's set   caller's                 splice profileSelect → calls jq
                  (git, bash here only     runtimeInputs lack jq
                   because NixOS sshd      → jq from the caller's PATH
                   gives a non-login       (system jq here; none →
                   command sw/bin)          "not a readable JSON object")
```

- **`IMP-017`** (from SL-006 audit `RV-018` F-1). `session` (`vm/session.nix`)
  prepends a repo's `tools/bin` to the inherited `PATH` and runs the argv. Its
  base tools, `git` above all (`DEC-043`: "git joins the room's base tools"),
  come from the caller's `PATH`. SL-006's design sec-6 tells satan's runner that
  a non-login ssh command's `PATH` is *not* promised, while
  `docs/contract-target.md` relies on it. The user chose (2026-10-19, RV-018
  F-1 option b): **`session` supplies the base tools itself, behind `tools/bin`
  and ahead of the caller's `PATH`.**
- **`ISS-013`** (from SL-001 PHASE-05). `host/profile.nix`'s reader calls `jq`
  and exports `inputs = [pkgs.jq pkgs.coreutils]` for callers to add to their
  `runtimeInputs`. Callers that splice `profileSelect` (`host/programs.nix:98`)
  without them: `capsule-provision` and `capsule-collect`
  (`host/git-channel.nix:96`, `:358`), and, by the same reading,
  `capsule-refresh` (`host/refresh.nix:253`), `capsule-brief`
  (`host/brief.nix:525`) and `capsule-baseline` (`host/baseline.nix:207`).
  `gitChannelCases` and `wrapCases` put `jq` in `nativeBuildInputs` and so hide
  it. `capsule-room-git` adds `profile.inputs` and is right.
- **`ISS-023`** names the same defect for two of those programs and has no body:
  a duplicate of `ISS-013`.

## Scope & Objectives

1. `session` runs every argv with a fixed base tool set ahead of the caller's
   `PATH` and behind the repo's `tools/bin`, so what `git` resolves to inside
   a room no longer depends on how the caller logged in.
2. Every program that splices the profile reader carries the reader's tools,
   and it should be impossible to splice one without the other.
3. The suites stop hiding (2): `jq` leaves the `nativeBuildInputs` that exist to
   supply it, and a case shows each affected program reading a document with
   no `jq` on the caller's `PATH`. For (1), `sessionCases` says what `PATH` is
   with and without a tool set.
4. The binding sources say one thing: `docs/contract-target.md` (absent path,
   room tools row), SL-006 design sec-3/sec-6's "until `IMP-017`", and
   `DEC-043`'s "base tools".

## Non-Goals

- Which tools a repo's tool set carries (the target's `toolsPackage`, POL-002).
- The slot guest's `PATH` and its colliding `git` (`ISS-025`).
- Fleet extras inside a room (`DEC-044`, provisional).
- Any other program's reliance on an ambient tool, beyond the profile reader's
  callers. If design finds more of them, it records them as backlog items,
  not scope.
- The satan runner's code. If the "call `session` by absolute path" guidance
  changes, that goes to satan as a relay, delivered by the user.

## Summary

Affected surface:

| path | why |
| --- | --- |
| `vm/session.nix`, `vm/session-cases.nix` | the base tool set and its order on `PATH`; the cases |
| `vm/room.nix` | whether `git` stays in the room's system packages once `session` carries it |
| `host/profile.nix`, `host/programs.nix` | the reader and its tools as one thing to splice |
| `host/git-channel.nix`, `host/refresh.nix`, `host/brief.nix`, `host/baseline.nix` | callers that lack the reader's tools |
| `host/*-cases.nix` (`git-channel`, `wrap`, and any others found) | stop supplying `jq`; add the no-ambient-`jq` case |
| `docs/contract-target.md`, `DEC-043`, `.doctrine/slice/006/design.md` | the promise, stated once |

Open questions, for design:
- **OQ-1:** what the base tool set is. Candidates: `git` alone (`DEC-043`);
  `git`, `bash`, `coreutils` and `which` (SL-006 design sec-3); or a declared
  list.
- **OQ-2:** the order and the shadowing rule. `writeShellApplication`'s
  `runtimeInputs` prepends ahead of everything, including `tools/bin`, so the
  base set has to be added in the program's text, not through `runtimeInputs`.
  Does the base set also shadow the caller's `git` when the repo has no tool
  set? It does under option (b).
- **OQ-3:** the shape that keeps the reader's text and its tools together:
  `profileSelect` carrying its inputs, a builder that adds them, or a
  build-time check. Each has a different coupling cost.
- **OQ-4:** whether `refresh`, `brief` and `baseline` actually reach the reader
  at run time. Their suites carry no `jq`, which suggests their cases never
  read a document, or read one some other way.

Risks: the `session` change alters `PATH` for every satan job in a running
room. The user's standing direction is to design forward and flag disruption
rather than design around it. Changing `session` needs a room rebuild before
it takes effect live, and the user does that.

Closure intent: `just` green with `jq` gone from the suites that only had it to
mask the bug; one case per affected program reading a document under `env -i`
(or an equivalent with no `jq` on `PATH`), each mutated once to watch it go
red; `sessionCases` pinning the `PATH` order; a live check that `git` inside
`session` is the base set's, after the user's rebuild; `ISS-013` and
`IMP-017` resolved, and `ISS-023` closed as a duplicate.

## Follow-Ups

- `ISS-025` (slot `git` collision): the same question on the slot side, not
  taken here.
- A satan relay if the absolute-path guidance for `session` changes.
