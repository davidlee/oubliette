# The front end's `volume` verb, and the lock `start` shares with it — SL-002
# design sec-2, sec-7.
#
# The third kind of check (CLAUDE.md), over `capsule`. Each branch here guards
# an act a live host reaches only by deleting or overwriting a real slot's
# volume, or by racing a start against a running clone, so this suite is the
# only place those refusals run at all. What it pins is the part upstream of
# the root step: where the name came from, the sub-verb, the checks that need
# no root, the record directory the operator makes, and the lock a start takes.
#
# **Handed a fixture pool, and it renders its own subject**, for `policyCases`'
# reason: the pool is the subject, and `microvms` and `moduleState` are the
# arguments that put a slot's `tap-up` and record directory in the sandbox.
# `volumeControl` is substituted whole. The root step is logged rather than
# run, and so is the unit state that gates it, because `pkgs.systemd` is in the
# front end's `runtimeInputs` and a sandbox reads every unit as `--`. The one
# line the substitution hides, the shipped `sudo -k`, is read off the shipped
# store path.
#
# `sudo` is **not** in the front end's `runtimeInputs`, so the stub on `PATH` is
# what `start` runs. It records whether the volume lock was held at the moment
# of the call, which is the only way to see that the lock is *around* the start
# rather than beside it.
#
# What this does not pin: the password prompt, the helper's own refusals
# (volumeRootCases), a real unit's state, and the module copy of the front end,
# which is the same store path.
{
  pkgs,
  lib,
  net,
  capsules,
  policies,
  guestSsh,
  observe,
  observeFragment,
  programVerbs,
  profileVerbs,
  stateRefPrefix,
  volumeRootHelper,
  # The front end every real call site builds, for the `volumeControl` default.
  shipped,
}: let
  # Three slots, none of them this host's: a destination, a source, and one
  # never created. Sockets and the lock live under the sandbox, so a slot can be
  # made to read as up and the lock can be held and removed.
  fixture =
    capsules
    // {
      instances = capsules.instancesOf {
        dst = {index = 0;};
        src = {index = 1;};
        bare = {index = 2;};
      };
      socketOf = name: ''"$CASE_ROOT"/run/${name}/ssh.sock'';
      volumeLock = ''"$CASE_ROOT/run/volume.lock"'';
    };
  cli = import ./cli.nix {
    inherit pkgs lib net policies guestSsh;
    inherit observe observeFragment programVerbs profileVerbs stateRefPrefix volumeRootHelper;
    capsules = fixture;
    microvms = ''"$CASE_ROOT/microvms"'';
    moduleState = ''"$CASE_ROOT/state"'';
    # The root step logs its argv, and for a clone whether the destination's
    # record directory already existed when it was called: the operator makes
    # it, and the helper refuses rather than make it as root (design sec-3).
    volumeControl = ''
      volumeRoot() {
        echo "$*" >> "$CASE_ROOT_LOG"
        if [ "$1" = clone ] && [ -d "$CASE_ROOT/state/slot/$3" ]; then
          echo "record directory $3 existed" >> "$CASE_ROOT_LOG"
        fi
        if [ -n "''${CASE_ROOT_FAIL:-}" ]; then
          echo "$CASE_ROOT_FAIL" >&2
          return 1
        fi
      }
      vmmState() { cat "$CASE_ROOT/unit/$1" 2> /dev/null || echo inactive; }
    '';
    # The guest program is logged rather than run, with whether the slot's scrub
    # marker existed at the moment of the call, into the log `capsule-inject`'s
    # stub writes too, so the order of scrub and inject is one file. Nothing
    # here reaches the other three.
    guestControl = ''
      guestHead() { return 1; }
      guestStages() { return 1; }
      guestDropState() { return 1; }
      guestResetHome() {
        local m=absent
        [ ! -e "$CASE_ROOT/state/slot/$1/scrub-pending" ] || m=present
        echo "reset-home $* marker=$m" >> "$CASE_GUEST_LOG"
        return "''${CASE_GUEST_RC:-0}"
      }
    '';
  };
in
  pkgs.runCommand "capsule-volume-cases" {nativeBuildInputs = [pkgs.util-linux pkgs.python3];} ''
    export CASE_ROOT=$PWD/root CASE_ROOT_LOG=$PWD/root.log CASE_SUDO_LOG=$PWD/sudo.log
    export CASE_GUEST_LOG=$PWD/guest.log
    capsule=${lib.getExe cli}
    lock=$CASE_ROOT/run/volume.lock

    mkdir stub
    cat > stub/sudo <<'EOF'
    #!/bin/sh
    lock=$CASE_ROOT/run/volume.lock
    if [ ! -e "$lock" ]; then held=nolock
    elif flock -n -x "$lock" true; then held=free
    else held=held; fi
    echo "$held $*" >> "$CASE_SUDO_LOG"
    EOF
    # Not in the front end's `runtimeInputs`, and `program` answers the bare name
    # when this host has no module copy, so this is what `work` execs.
    cat > stub/capsule-inject <<'EOF'
    #!/bin/sh
    m=absent
    [ ! -e "$CASE_ROOT/state/slot/$2/scrub-pending" ] || m=present
    echo "inject $* marker=$m" >> "$CASE_GUEST_LOG"
    EOF
    chmod +x stub/sudo stub/capsule-inject
    export PATH=$PWD/stub:$PATH

    log=$PWD/log
    : > "$log"
    fail=0
    run() { rc=0; "$capsule" "$@" > out 2>&1 || rc=$?; }
    ck() {
      if [ "$2" = "$3" ]; then echo "ok   $1" >> "$log"
      else echo "FAIL $1: exit $3, wanted $2" >&2; sed 's/^/    /' out >&2; fail=1; fi
    }
    ckt() {
      if "''${@:2}"; then echo "ok   $1" >> "$log"
      else echo "FAIL $1" >&2; sed 's/^/    /' out >&2; fail=1; fi
    }
    saw() { grep -qF -- "$1" out; }
    unsaw() { ! grep -qF -- "$1" out; }
    rootLog() { tr '\n' ',' < "$CASE_ROOT_LOG" | sed 's/,$//'; }
    quietRoot() { [ ! -s "$CASE_ROOT_LOG" ]; }
    quietSudo() { [ ! -s "$CASE_SUDO_LOG" ]; }
    guestLog() { tr '\n' ',' < "$CASE_GUEST_LOG" | sed 's/,$//'; }
    quietGuest() { [ ! -s "$CASE_GUEST_LOG" ]; }
    absent() { [ ! -e "$1" ]; }
    present() { [ -e "$1" ]; }

    # Every case starts here, so none inherits the last one's record directory,
    # unit state or lock holder (NOTES item 37).
    fresh() {
      rm -rf "$CASE_ROOT"
      for s in dst src; do
        mkdir -p "$CASE_ROOT/microvms/$s/current/bin"
        printf '#!/bin/sh\n' > "$CASE_ROOT/microvms/$s/current/bin/tap-up"
        chmod +x "$CASE_ROOT/microvms/$s/current/bin/tap-up"
      done
      mkdir -p "$CASE_ROOT/run" "$CASE_ROOT/state" "$CASE_ROOT/unit"
      : > "$lock"
      : > "$CASE_ROOT_LOG"
      : > "$CASE_SUDO_LOG"
      : > "$CASE_GUEST_LOG"
      unset CAPSULE_NAME CASE_ROOT_FAIL CASE_GUEST_RC
    }
    unit() { echo "$2" > "$CASE_ROOT/unit/$1"; }
    # What the root helper leaves on a clone without --identity (design sec-5).
    markerOf() { printf '%s/state/slot/%s/scrub-pending' "$CASE_ROOT" "$1"; }
    mark() {
      mkdir -p "$CASE_ROOT/state/slot/$1"
      echo "source=src at=2026-09-15T00:00:00Z" > "$(markerOf "$1")"
    }
    # A bound socket file stays after its process exits, which is all `-S` asks.
    up() {
      mkdir -p "$CASE_ROOT/run/$1"
      python3 -c 'import socket, sys; socket.socket(socket.AF_UNIX).bind(sys.argv[1])' \
        "$CASE_ROOT/run/$1/ssh.sock"
    }

    # ------------------------------------------------------------ the name
    # A destructive verb on a slot nobody named is the failure this gate is for.
    # CAPSULE_NAME is ambient to a shell working in a capsule, which is exactly
    # where someone types a volume command meaning a different slot.
    for sub in reset "clone-from src" reset-home; do
      fresh
      CAPSULE_NAME=dst run volume $sub
      ck "volume $sub refuses a CAPSULE_NAME name" 1 "$rc"
      ckt "  because the name was not on the command line" saw "named on the command line"
      ckt "  and says where it came from" saw "CAPSULE_NAME"
      ckt "  and nothing reached the root step" quietRoot
    done

    fresh
    up dst
    run volume reset
    ck "volume refuses the name of the one slot that is up" 1 "$rc"
    ckt "  because the name was not on the command line" saw "named on the command line"
    ckt "  and says it was only the one that is up" saw "is up"
    ckt "  and nothing reached the root step" quietRoot

    fresh
    CAPSULE_NAME=src run dst volume reset
    ck "an argv name wins over CAPSULE_NAME and is accepted" 0 "$rc"
    ckt "  and reaches the root step for that slot" test "$(rootLog)" = "reset dst"

    fresh
    run all volume reset
    ck "all volume is refused" 1 "$rc"
    ckt "  as an action on every capsule" saw "is an action on every capsule"
    ckt "  and nothing reached the root step" quietRoot

    fresh
    run dst volume
    ck "volume with no sub-verb is refused" 1 "$rc"
    ckt "  naming the sub-verbs" saw "clone-from <src>"

    fresh
    run dst volume frobnicate
    ck "an unknown sub-verb is refused" 1 "$rc"
    ckt "  naming it" saw "'frobnicate' is not a volume sub-verb"
    ckt "  and nothing reached the root step" quietRoot

    # ------------------------------------------------------------ reset
    fresh
    run dst volume reset
    ck "reset of a stopped, created slot runs" 0 "$rc"
    ckt "  as the root step's reset of that slot alone" test "$(rootLog)" = "reset dst"

    fresh
    unit dst failed
    run dst volume reset
    ck "a failed unit counts as stopped" 0 "$rc"

    for state in running auto-restart --; do
      fresh
      unit dst "$state"
      run dst volume reset
      ck "reset refuses a unit that is $state" 1 "$rc"
      ckt "  naming the way out" saw "capsule dst stop"
      ckt "  and the state it read" saw "'$state'"
      ckt "  and the root step's log stays empty" quietRoot
    done

    fresh
    run bare volume reset
    ck "reset refuses a slot never created here" 1 "$rc"
    ckt "  saying so" saw "never been created"
    ckt "  and nothing reached the root step" quietRoot

    fresh
    run dst volume reset now
    ck "reset refuses an argument" 1 "$rc"
    ckt "  and nothing reached the root step" quietRoot

    fresh
    CASE_ROOT_FAIL="capsule-volume-root: another volume operation is running" run dst volume reset
    ck "a refusal from the root step is the verb's exit status" 1 "$rc"
    ckt "  and its message passes through unchanged" saw "another volume operation is running"

    # ------------------------------------------------------------ clone-from
    fresh
    run dst volume clone-from src
    ck "clone-from of two stopped, created slots runs" 0 "$rc"
    ckt "  making the destination's record directory before the root step" \
      test "$(rootLog)" = "clone src dst,record directory dst existed"
    ckt "  and not the source's" absent "$CASE_ROOT/state/slot/src"

    fresh
    run dst volume clone-from src --identity
    ck "clone-from --identity runs" 0 "$rc"
    ckt "  and hands --identity to the root step" \
      test "$(rootLog)" = "clone src dst --identity,record directory dst existed"

    # Each refusal leaves no record directory: the directory is made only once
    # every check has passed (design sec-2, "nothing is written before the last
    # check passes").
    refuses() {
      local what="$1" why="$2"
      shift 2
      run "$@"
      ck "clone-from refuses $what" 1 "$rc"
      ckt "  saying $why" saw "$why"
      ckt "  and the root step's log stays empty" quietRoot
      ckt "  and makes no record directory" absent "$CASE_ROOT/state/slot/dst"
    }
    fresh
    refuses "no source" "clone-from <src>" dst volume clone-from
    fresh
    refuses "a source that is not a slot" "'nowhere' is not a capsule" dst volume clone-from nowhere
    fresh
    refuses "itself" "from itself" dst volume clone-from dst
    fresh
    refuses "a source never created" "'bare' has never been created" dst volume clone-from bare
    fresh
    rm -r "$CASE_ROOT/microvms/dst"
    refuses "a destination never created" "'dst' has never been created" dst volume clone-from src
    fresh
    unit src running
    refuses "a running source" "capsule src stop" dst volume clone-from src
    fresh
    unit dst running
    refuses "a running destination" "capsule dst stop" dst volume clone-from src
    fresh
    refuses "an argument it does not know" "'--force'" dst volume clone-from src --force

    # What a clone leaves the operator to do. The cost is the helper's own line
    # (volumeRootCases), measured under its lock; the rest is the front end's.
    fresh
    run dst volume clone-from src
    ckt "a clone says its first inject scrubs the source's identity" saw "scrubs src's credentials"
    ckt "  that nobody checked the source was clean" saw "not checked: whether src was a clean source"
    ckt "  how to check that by hand" saw "capsule src record"
    ckt "  that the human's door needs its host key forgotten" saw "just reset-known-hosts dst"
    ckt "  and the commands that come next" saw "capsule dst start"
    ckt "  including the setup a clone's commits may force" saw "--force"

    fresh
    run dst volume clone-from src --identity
    ckt "a clone with --identity says the source's identity was kept" saw "kept src's credentials"
    ckt "  and not that anything will scrub it" unsaw "scrubs"

    fresh
    CASE_ROOT_FAIL="capsule-volume-root: another volume operation is running" run dst volume clone-from src
    ck "a clone the root step refused fails" 1 "$rc"
    ckt "  and tells nobody what to do next" unsaw "reset-known-hosts"

    # ------------------------------------------------------------ reset-home
    # The guest decides and the front end names the way out. The door here is the
    # fixture's socket; whether a guest answers behind it is ssh's to report.
    fresh
    up dst
    run dst volume reset-home
    ck "reset-home on a slot with a door runs" 0 "$rc"
    ckt "  the guest program, then an inject, and nothing else" \
      test "$(guestLog)" = "reset-home dst marker=absent,inject --capsule dst marker=absent"
    ckt "  and never the root step" quietRoot

    # What a refusal must say for one guest status — its reason *and* its way
    # out — and, for 127, the way out it must not name. Both call sites read
    # this one table, because a gate that answers a status differently from the
    # `reset-home` branch is a second program telling the operator a second
    # thing about the same failure (design sec-5, sec-8).
    refusal() {
      notWant=""
      case "$1" in
        # Only `microvm -u` moves a slot's `current`, so stop-then-start boots
        # the same image and meets 127 again: a loop, not a remedy (RV-004 F-1).
        127)
          want=("this slot's image predates" "just refresh-build dst")
          notWant="stop, then start"
          ;;
        3) want=("the agent is busy" "capsule dst stop, then start") ;;
        4) want=("an agent login arrived" "run it again") ;;
        255) want=("ssh to the admin door failed" "run it again once capsule dst status") ;;
        *) want=("capsule-reset-home exited $1") ;;
      esac
    }
    # Asserts the table for the status `refusal` was last called with.
    saidWhy() {
      local why
      for why in "''${want[@]}"; do
        ckt "  saying $why" saw "$why"
      done
      [ -z "$notWant" ] || ckt "  and not $notWant" unsaw "$notWant"
    }

    # homeRefuses <guest status> <what the guest found>
    homeRefuses() {
      local status="$1" what="$2"
      fresh
      up dst
      CASE_GUEST_RC=$status run dst volume reset-home
      ck "reset-home refuses when the guest $what (status $status)" 1 "$rc"
      refusal "$status"
      saidWhy
      ckt "  and injects nothing" test "$(guestLog)" = "reset-home dst marker=absent"
    }
    homeRefuses 127 "has no capsule-reset-home"
    homeRefuses 3 "finds the agent working"
    homeRefuses 4 "sees a login arrive"
    homeRefuses 255 "cannot be reached over the door"
    homeRefuses 1 "fails otherwise"

    fresh
    run dst volume reset-home
    ck "reset-home refuses a slot with no door" 1 "$rc"
    ckt "  naming the start" saw "capsule dst start"
    ckt "  and asks the guest nothing" quietGuest

    fresh
    up dst
    run dst volume reset-home now
    ck "reset-home refuses an argument" 1 "$rc"
    ckt "  and asks the guest nothing" quietGuest

    # ------------------------------------------------------------ the scrub gate
    # Every inject the front end runs passes `work()`, and `scrubPending` there is
    # the one place a cloned volume is kept from receiving credentials before its
    # scrub (sec-5).
    fresh
    mark dst
    run dst inject
    ck "inject onto a cloned volume runs" 0 "$rc"
    ckt "  scrubbing first, then injecting once the marker is gone" \
      test "$(guestLog)" = "reset-home dst --scrub marker=present,inject --capsule dst marker=absent"
    ckt "  and says why" saw "scrubbing before inject"
    ckt "  leaving no marker" absent "$(markerOf dst)"

    # The gate answers a failed scrub with the same table `reset-home` reads, so
    # the operator meeting 127 here — the likeliest place to meet it, since a
    # clone needs both slots created rather than refreshed — is told the same
    # way out (design sec-5, RV-004 F-2).
    for status in 1 3 4 127 255; do
      fresh
      mark dst
      CASE_GUEST_RC=$status run dst inject
      ck "inject onto a cloned volume whose scrub fails ($status) refuses" 1 "$rc"
      refusal "$status"
      saidWhy
      ckt "  saying the marker stays" saw "marker stays"
      ckt "  and injects nothing" test "$(guestLog)" = "reset-home dst --scrub marker=present"
      ckt "  and keeps the marker" present "$(markerOf dst)"
    done

    fresh
    run dst inject
    ck "inject onto an unmarked volume runs" 0 "$rc"
    ckt "  without scrubbing" test "$(guestLog)" = "inject --capsule dst marker=absent"

    fresh
    mark dst
    run dst inject --capsule dst
    ck "an inject refused for its arguments" 1 "$rc"
    ckt "  is refused before any scrub" quietGuest
    ckt "  and keeps the marker" present "$(markerOf dst)"

    fresh
    up dst
    mark dst
    run dst volume reset-home
    ck "reset-home on a cloned volume runs" 0 "$rc"
    ckt "  and its inject passes the gate too" \
      test "$(guestLog)" = "reset-home dst marker=present,reset-home dst --scrub marker=present,inject --capsule dst marker=absent"

    # ------------------------------------------------------------ start's lock
    # A start past the lock goes on to a unit no sandbox has and fails there, so
    # these read what reached `sudo`, not the exit status.
    fresh
    flock -x "$lock" sleep 30 &
    holder=$!
    while flock -n -s "$lock" true; do :; done
    run dst start
    kill "$holder"; wait "$holder" 2> /dev/null || true
    ck "start refuses while a volume operation holds the lock" 1 "$rc"
    ckt "  by reason" saw "a volume operation is running on this host"
    ckt "  before systemctl is asked anything" quietSudo

    fresh
    flock -s "$lock" sleep 30 &
    holder=$!
    while flock -n -x "$lock" true; do :; done
    run dst start
    kill "$holder"; wait "$holder" 2> /dev/null || true
    ckt "a start beside another start's shared hold is not refused" unsaw "a volume operation is running"
    ckt "  and reaches systemctl start" grep -qF "systemctl start microvm@dst" "$CASE_SUDO_LOG"

    fresh
    run dst start
    ckt "start holds the lock across systemctl start" \
      grep -qxF "held systemctl start microvm@dst" "$CASE_SUDO_LOG"

    fresh
    rm "$lock"
    run dst start
    ckt "start with no lock file warns" saw "no volume lock"
    ckt "  and still reaches systemctl start" \
      grep -qxF "nolock systemctl start microvm@dst" "$CASE_SUDO_LOG"
    ckt "  and creates no lock file" absent "$lock"

    # ------------------------------------------------------------ shipped
    # The one line the fixture's `volumeControl` replaces, read off the store
    # path every real call site builds. Comments stripped, so a comment that
    # quotes the line cannot satisfy it.
    grep -v '^[[:space:]]*#' ${shipped}/bin/capsule > shipped.txt
    ckt "the shipped front end runs the helper through sudo -k" \
      grep -qF 'sudo -k ${volumeRootHelper}/bin/capsule-volume-root "$@"' shipped.txt
    ckt "the shipped front end runs the guest's reset of \$HOME as root" \
      grep -qF '"root@${net.guest}" capsule-reset-home "$@"' shipped.txt

    [ "$fail" = 0 ] || exit 1
    cp "$log" $out
    cat $out
  ''
