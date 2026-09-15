From SL-002 PHASE-02 (`vm/reset-home-cases.nix`, commit `87e682b`).

CLAUDE.md's rule is that `runtimeInputs` go ahead of `PATH`, so a suite cannot
shadow them, and a program takes a `tools` argument instead. The converse is
also useful. **A tool that deliberately is *not* in `runtimeInputs` is found on
the inherited `PATH`, so a suite can fake it and run the shipped store path.**

`capsule-reset-home` takes `systemctl` and `loginctl` from the guest's `PATH` on
purpose: they must be the running systemd's, not a second copy. So the suite does
this:

```bash
mkdir -p "$fakes/bin"   # loginctl: list-sessions / show-session <id> from files
                        # systemctl: log argv, exit 1 (so nothing ever acts)
PATH="$fakes/bin:$PATH" ${shipped}/bin/capsule-reset-home
```

- It runs the real `tools` default (the real parser, the real error handling),
  which a fixture render replaces wholesale. This is what found
  [[mem.fact.oubliette.errexit-skips-a-captured-function]].
- `shipped` is found in the evaluated guest's `environment.systemPackages` by
  `lib.getName`, with a `throw` when absent, so the case cannot pass vacuously.
- **The shipped program's paths are fixed** (`/work/home`). Only write cases that
  refuse before any act, and make the fake `systemctl` fail every call as a
  second fence.
- The fake's output format is an assumption until it is read live. Say so in
  the commit.
- Does not apply to a program whose `runtimeInputs` carry the tool (e.g.
  `pkgs.openssh` in the git channel). That is still a `tools` seam, or a
  boundary.
