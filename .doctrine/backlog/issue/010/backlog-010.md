# ISS-010: notHeld fails open when fuser itself errors

`host/volume-root.nix:91-97`:

```sh
notHeld() {
  local pids
  [ -e "$1" ] || return 0
  if pids=$(fuser "$1" 2> /dev/null); then
    refuse "$1 is held open by pid$pids; stop whatever holds it first"
  fi
}
```

`fuser` exits non-zero both for *nothing holds it* and for *it could not
answer*, and `2> /dev/null` discards the difference. So any error reads as
**free**, and the caller proceeds to `rm` or `cp` over an image somebody may be
using — as root.

This is the check design sec-2 calls **"the real guarantee"**, the one that
backs up the front end's cheap `unitState` stand-in, and the reason the helper
identifies a *file* rather than a process name
(`mem.fact.oubliette.dead-guest-is-not-a-dead-vm`). Fail-open is the wrong
direction for it.

**Bounded, not theoretical-free.** The `[ -e "$1" ] || return 0` above it
removes the common error — a missing file. What remains is `/proc` unreadable to
root, which is not a state this host is in. That is why it was reasoned through
at `SL-002` PHASE-01 and left; it was never filed, which is the actual defect in
the record.

**Fix shape:** distinguish the two exits. `fuser` returns 1 for "no process
found" and other non-zero values for its own failures; capture status and
stderr, refuse by reason on anything that is not the clean empty answer, and
add a `volumeRootCases` case with a stubbed `fuser` that exits non-zero *and*
writes to stderr. `fuser` is in the helper's `runtimeInputs`, so the stub goes
on `PATH` the way `mem.pattern.oubliette.fake-guest-tools-on-path` describes —
check that the stub is actually reached before trusting the case.

Raised at `SL-002`'s closure audit as `RV-006` `F-11`, disposed follow-up.
