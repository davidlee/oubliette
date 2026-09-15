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
  };
in
  pkgs.runCommand "capsule-volume-cases" {nativeBuildInputs = [pkgs.util-linux pkgs.python3];} ''
    export CASE_ROOT=$PWD/root CASE_ROOT_LOG=$PWD/root.log CASE_SUDO_LOG=$PWD/sudo.log
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
    chmod +x stub/sudo
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
    absent() { [ ! -e "$1" ]; }

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
      unset CAPSULE_NAME CASE_ROOT_FAIL
    }
    unit() { echo "$2" > "$CASE_ROOT/unit/$1"; }
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

    [ "$fail" = 0 ] || exit 1
    cp "$log" $out
    cat $out
  ''
