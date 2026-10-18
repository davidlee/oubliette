<!-- doctrine:section sec-1 -->
## Shape

Two programs find a tool on a `PATH` nothing promises. This slice makes each
carry its own (`IMP-017`, `ISS-013`).

```
room declaration                      vm/room.nix (image)
rooms.<r>.extras = [ <fragment> ]  →  base = buildEnv (floor ++ compose extras)
                                        floor = git bash coreutils-full which
                                        → /etc/room/base          (tree link)
                                        → environment.systemPackages (logins)

session <repo> -- argv:   PATH = /etc/room/repo/<repo>/tools/bin   (repo wins)
                               : /etc/room/base/bin                (room base)
                               : $PATH                             (caller)

host/profile.nix reader:  ${jq} -e …   (a store path in the text)
  → provision, collect, refresh, brief, baseline, room-git, the front end:
    every splice carries jq; profile.inputs is gone
```

`DEC-052` (superseding `DEC-044`) is the room half, `DEC-053` the reader half.
The two share a theme and no code.

<!-- doctrine:section sec-2 -->
## A room's base (`DEC-052`)

**Declaration.** `rooms.<r>.extras`, optional, a list of names from
`fragments.nix`'s vocabulary, on **any** room, with repos or without. Absent
means `[]`: the floor alone. It is a value of the room's own declaration, so
one home per axis (`POL-003`), and convenience stays declared in the one place
a tool that is nobody's project may be named (`docs/contract-flavour.md`).

**`rooms.nix`.** A new `reasons.extras` refuses, with the reason in the
message:
- `extras` that is not a list of strings;
- a name the vocabulary lacks, listing the vocabulary.

`rooms.nix` takes the vocabulary's names as an argument (`fragmentNames`), so
`roomsCases` hands it a fixture list and `mkfleet.nix` hands it
`attrNames fragments.vocabulary`. The record gains `extras` (a list, `[]` when
absent). `instances` throws `reasons.extras` after `reasons.policy`.

**The floor.** `git`, `bash`, `coreutils-full`, `which`: what pi-env needs from a
room (`sh` is `bash`'s, `uname` is coreutils') plus `DEC-043`'s `git`. It is
`vm/room.nix`'s, a fixed list, and a room adds to it and never removes from it.

**The render (`vm/room.nix`).** It takes `flavour` (already in every VM's
`specialArgs`) for `sources`, imports `fragments.nix` as `vm/capsule.nix`
does, and builds:

```nix
base = pkgs.buildEnv {
  name = "room-base";
  paths = fragments.compose { floor = [git bash coreutils-full which]; extras = room.extras; };
};
```

`buildEnv` without `ignoreCollisions`, so an extra that ships a file the floor
ships (a second `bin/git`) **fails the build**. `system-path` ignores
collisions (`ISS-025`'s mechanism), so the check has to be here. The base goes
to:
- `environment.etc."room/base".source = base`, for every room (a repo-less room
  has no `session` but the link costs nothing and keeps one rule);
- `environment.systemPackages`, replacing today's `pkgs.git`, so an
  interactive login has the floor and the extras. `session` stays in
  `systemPackages` only for a room with repos.

A repo's tool set is never unioned with the base: `tools` stays its own link,
and it shadows the base on `PATH` rather than colliding with it (the user,
2026-10-19: the repo's package wins).

**What the collision check covers, exactly.** `buildEnv` refuses two
*different* files at one path. It accepts identical ones and a deliberate
priority (`lib.hiPrio`), as `compose` already intends. It checks inside the
base only. `system-path` around it ignores collisions, so against the rest of
the system packages an interactive login gets whichever NixOS picks (`ISS-025`'s
mechanism). `session` does not depend on that: it reads `/etc/room/base`
directly, so the checked set is what a job runs. The floor's `bash` and
`coreutils-full` are the attributes NixOS's required packages use
(`system-path.nix`), so in this image they are the same store paths. Amended
at PHASE-03 (the user, 2026-10-19): the floor first named `coreutils`, which
is a different store path, and the base's default priority (5) beats the
required packages' (8), so it would have shadowed the system's
`coreutils-full` for a login and inside `session`.

**`session` (`vm/session.nix`).** One generic program, one store path
(`DEC-049`), still reading only build-time paths. `root` stays its build
argument, and a second, `base ? "/etc/room/base"`, names the base, so neither
path is derived inside the program and the fixture hands both:

```
PATH = <root>/<repo>/tools/bin   (only when tools exists)
     : <base>/bin                (always)
     : $PATH                     (only when set and non-empty)
```

The caller's half is `${PATH:+:$PATH}` (escaped `''${…}` in the Nix string):
an empty `PATH` must not leave a trailing `:`, which would put the working
directory on `PATH`. An *unset* one never reaches the script as unset: this
bash defaults it to `/no-such-path` (RV-019 note, GPT), which is harmless
behind the base. A caller's relative `PATH` entries resolve against the clone
after `cd -P`, which is today's behaviour too and the caller's to avoid.

`runtimeInputs` stays `[]`: `session` uses builtins only, and anything there
would sit ahead of `tools/bin`. If `<base>/bin` is absent, `session` refuses
with exit 2 ("no base at …"). A room image always renders it, so absence means
a broken image, not a caller's choice.

**Extras in the vocabulary.** `fragments.nix` gains fragments as values, finer
than the slot grain, since each room is its own image anyway: at least
`search` (`ripgrep`, `fd`) and `emacs`. Their exact contents are the user's
call when the consumer declares them. `agents` and `dev-facilities` stay as
they are for slots.

<!-- doctrine:section sec-3 -->
## The profile reader carries its `jq` (`DEC-053`)

`host/profile.nix`'s `validator` calls `jq` seven times (`profileShow`
none; corrected at PHASE-01). Each call becomes the store path, by Nix interpolation:

```nix
jq = lib.getExe pkgs.jq;
…
if ! doc=$(${jq} -e '…' "$file" 2>/dev/null); then
```

No shell name is added to the scope a caller splices into (`host/record.nix`'s
rule), and the text is the same for every caller. `jq` is the only non-builtin
the reader runs, so `inputs` is **deleted**, and with it:
- `++ profile.inputs` in `host/room-git.nix:104`;
- `inherit (hostProfile) inputs` for `snapshotCases`, `observeCases` and
  `profileCases`, whose test programs splice the fragment and so no longer need
  `jq` on their `PATH` for it. Where a suite's own text runs `jq` (fixture
  writing), it says so and keeps one of its own.

`renderDocs` keeps its own `jq -S .` with `nativeBuildInputs = [pkgs.jq]`: it is
a build step, not the reader.

`host/record.nix`'s identical convention stays: its one caller (`host/cli.nix`)
is correct. The front end currently gets the reader's `jq` from
`record.inputs` by accident; after this, it no longer depends on that.

<!-- doctrine:section sec-4 -->
## Verification

| suite | what it pins (`STD-001`: the verb each covers) |
| --- | --- |
| `sessionCases` | over a fixture tree with `repo/` and `base/`: with a set, `PATH` is `tools/bin : base/bin : caller`; without, `base/bin : caller`; a base `git` marker resolves inside `session` when the caller's `PATH` has none; a repo's `git` marker shadows the base's; no `base/bin` → exit 2 with the reason; an empty caller `PATH` gives `…base/bin` with no trailing `:`, and an unset one does not abort. The image case: the shipped tree's `room/base` holds `bin/git`, `bin/bash`, `bin/which` and a coreutils binary. Runs `session`'s text, not a room |
| `roomsCases` | `extras` not a list, and an unknown name, are refused with the reason (and the vocabulary in it); absent gives `extras = []` on the record |
| `profileCases` | the reader loads a document in a `runCommand` with **no `jq` on `PATH`**. One text, so this covers every splice |
| `hostModuleUnits` (or the nearest suite holding the programs) | each shipped program that splices the reader (`capsule-provision`, `capsule-collect`, `capsule-refresh`, `capsule-brief`, `capsule-baseline`, `capsule-room-git`, `capsule`) has `jq`'s store path in its text. That proves the splice is the shared text, not that the program runs; `profileCases` proves the text runs (RV-019 note, GPT) |
| `gitChannelCases`, `wrapCases` | `jq` leaves the `nativeBuildInputs` that hid `ISS-013`; a suite-owned `jq` stays only where the suite itself writes fixtures, and is named as such |
| build | a fixture room declares one extra, so `just build` renders a base with extras. A base whose extras put a *different* file at a floor path is not cased: it is `buildEnv`'s behaviour, observed once by hand while building. Collisions against the rest of `system-path` are not checked anywhere (sec-2) |

Each new case is mutated once to watch it go red: `session` without the base
line, the reader with a bare `jq`, `rooms.nix` without `reasons.extras`.

**Live, the user's rebuild first.** In the assistant room:
`capsule assistant ssh agent -- env -i /run/current-system/sw/bin/session <repo> -- sh -c 'command -v git'`
prints the base's `git` with no `PATH` at all from the caller; an interactive
login has a declared extra on `PATH`.

Not exercised: a collision between two extras (same mechanism as the floor);
`capsule-refresh`, `capsule-brief` and `capsule-baseline` live with no system
`jq` (the reader's text is theirs, and `profileCases` runs it).

<!-- doctrine:section sec-5 -->
## Contracts and records

- `docs/contract-target.md`: the `toolsPackage` absent path (`:95`) and the room
  tools row (`:359`) say `session` supplies the base (floor plus the room's
  extras, `DEC-052`), and drop "until `IMP-017`" and "no fleet extras".
- `docs/contract-flavour.md`: a room selects extras per room from the same
  vocabulary; the floor is the room's, not a target's.
- `docs/contract-assignment.md`: the room row gains `extras`.
- `DEC-043`: its "git joins the room's base tools" now points to `DEC-052`.
- `templates/fleet/flake.nix`: the commented room example shows `extras`.
- `CLAUDE.md`: the "tool set has two owners" paragraph gains the room's case
  in one sentence.
- SL-006's design is closed and stays as written.
- Backlog: `IMP-017` and `ISS-013` resolve at close.

<!-- doctrine:section sec-6 -->
## Risks and what is out of scope

- **A running room's `PATH` changes** at the user's next rebuild: every satan
  job gets the base's `git` ahead of whatever the caller's `PATH` held. Same
  store path as today's system `git`, so no behaviour change is expected. Flagged,
  not designed around.
- **Image size.** Each room grows by its extras. `emacs` is the large one.
- **Out:** a room user's login shell (`users.users.<u>.shell`, a follow-up);
  shell or editor *configuration* (never copied from `$HOME`; `~/.config/emacs`
  is a repo on `CHR-018`'s list); `ISS-025`; `host/record.nix`'s convention; a
  repo's tool set beyond `PATH` (no devshell, no `shellHook`, no environment
  variables, as today).
- **satan.** `session` is still called by absolute path. One relay line: base
  tools are now `session`'s, so the runner's `PATH` no longer matters inside it.

<!-- doctrine:section sec-7 -->
## Code impact

| path | change |
| --- | --- |
| `vm/session.nix` | `base` argument; `base/bin` on `PATH` after `tools/bin`; refuse without it |
| `vm/session-cases.nix` | fixture `base/`; the order, shadowing and refusal cases; image case reads `room/base` |
| `vm/room.nix` | take `flavour`, import `fragments.nix`; render `base`; `/etc/room/base`; base in `systemPackages` instead of `git` |
| `rooms.nix` | `fragmentNames` argument; `reasons.extras`; record `extras` |
| `rooms-cases.nix` | the two refusals and the absent default |
| `fragments.nix` | finer fragments as values (`search`, `emacs`) |
| `mkfleet.nix` | hand `rooms.nix` the vocabulary's names; `sessionCases`' new argument; drop `inputs` from three suites |
| `fixture/default.nix` | the repo room declares one extra |
| `host/profile.nix` | `${jq}` in the reader; delete `inputs` |
| `host/room-git.nix` | drop `++ profile.inputs` |
| `host/profile-cases.nix` | the no-`jq` case; stop taking `inputs` |
| `host/state-snapshot-cases.nix`, `host/observe-cases.nix` | stop taking `inputs` |
| `host/git-channel-cases.nix`, `host/wrap-cases.nix`, `host/room-git-cases.nix` | drop the masking `jq`, or name the suite's own; fix the comment |
| `docs/contract-target.md`, `docs/contract-flavour.md`, `docs/contract-assignment.md` | sec-5 |
| `templates/fleet/flake.nix`, `CLAUDE.md` | sec-5 |

