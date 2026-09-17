# What the guest's one deleting program decides — SL-002 design sec-4.
#
# The third kind of check (CLAUDE.md), over `capsule-reset-home`, and the first
# whose subject ships in the *guest*. Every branch here is one a live guest
# reaches only by deleting a real `$HOME` under a real agent, so the suite is
# where they get exercised at all.
#
# **Handed a fixture home, and it renders its own subject on purpose**, as
# `host/volume-root-cases.nix` does. The program's `home` and `scrubPaths` are
# build-time values, fixed by the guest module that ships it, so the shipped
# store path deletes `/work/home` and nothing else, and a render against a
# sandbox is the only way to run the text. The render differs from the shipped
# one in those values and in `tools` alone. The shipped store path runs too, for
# the one part a render cannot pin: its real session listing, against
# `loginctl` faked on `PATH`, since the guest's own is not in `runtimeInputs`.
# Those cases all refuse before it acts, so its fixed `$HOME` is never reached.
#
# `tools` is what ties the program to a running guest: logind's session list
# and systemd's units. The stubs log each unit act together with what the
# sandbox looks like at that moment (is `$HOME` there, are the scrub paths), so
# a case asserts the *order* sec-4 rests on rather than only the end state. Only
# the session *listing* is stubbed: the rule for which sessions count as work is
# the program's own text, so these cases run it against the sessions a real
# guest reports (sec-2's table).
#
# **And it reads the scrub list off the guest this flake builds**, not a
# recomputation of it: `guest` is the evaluated capsule's `config`, the program
# is found in its `systemPackages` by name, and its `passthru.scrubPaths` is the
# list the image carries. Every expected value comes from `target` or that same
# `config`, so no target value is spelled here (POL-002).
#
# Both rules for writing a case apply: each refusal asserts its reason as well as
# its status, and each case starts from `fresh`.
{
  pkgs,
  lib,
  # The evaluated capsule guest's `config` (flake.nix `capsuleVm`).
  guest,
  target,
}: let
  # The guard over the paths the shipped program is built with (vm/guest-path.nix,
  # called from vm/capsule.nix). It is a `throw` rather than a program, so the
  # verdicts are read at eval and asserted in the shell — `hostModuleUnits`'
  # arrangement one level down (CLAUDE.md, host/profile-cases.nix's precedent).
  guestPath = import ./guest-path.nix {inherit lib;};
  verdicts = lib.mapAttrs (_: p: (builtins.tryEval (guestPath "a scrub path" p)).success) {
    plain = "/work/.env";
    spaced = "/work/a file";
    globbed = "/work/*";
    relative = "work/.env";
    expression = "$(id -u)";
  };

  fixture = import ./reset-home.nix {
    inherit pkgs lib;
    home = ''"$CASE_ROOT/work/home"'';
    agentUid = 1000;
    scrubPaths = [
      ''"$CASE_ROOT/work/.env"''
      ''"$CASE_ROOT/work/ssh/key"''
      ''"$CASE_ROOT/work/ssh/key.pub"''
    ];
    tools = ''
      agentSessions() { cat "$CASE_SESSIONS"; }
      activeGettys() { printf '%s\n' getty@tty1.service serial-getty@ttyS0.service; }
      # What the sandbox looks like when a unit is acted on: whether `$HOME` is
      # there, and whether any scrub path still is.
      observed() {
        local h=absent s=absent p
        if [ -e "$CASE_ROOT/work/home" ] || [ -L "$CASE_ROOT/work/home" ]; then h=present; fi
        for p in .env ssh/key ssh/key.pub; do [ ! -e "$CASE_ROOT/work/$p" ] || s=present; done
        echo "home=$h scrub=$s"
      }
      unitAct() {
        echo "$* $(observed)" >>"$CASE_LOG"
        [ "$*" != "''${CASE_FAIL:-}" ]
      }
      startUnit() { unitAct start "$@"; }
      stopUnit() { unitAct stop "$@"; }
      restartUnit() { unitAct restart "$@"; }
      # One answer per call, from `CASE_ACTIVE`, and inactive once it runs out.
      unitActive() {
        local n answers
        n=$(cat "$CASE_ROOT/active-calls")
        echo $((n + 1)) >"$CASE_ROOT/active-calls"
        read -ra answers <<<"''${CASE_ACTIVE:-}"
        echo "active? $1" >>"$CASE_LOG"
        [ "''${answers[n]:-inactive}" = active ]
      }
    '';
  };

  # And the same guard over the list the *image* carries, read off the evaluated
  # guest rather than recomputed. This says the shipped paths are plain; it does
  # not say vm/capsule.nix would refuse a bad one, which needs a guest evaluated
  # against a hostile target (noted as open on SL-002).
  shippedPlain =
    (builtins.tryEval (
      lib.deepSeq
      (map (guestPath "a shipped scrub path")
        (shipped.scrubPaths ++ [guest.users.users.agent.home]))
      true
    ))
    .success;

  # The program the evaluated guest ships, found by name and never rebuilt here:
  # a check that recomputed the list would agree with itself.
  shipped =
    lib.findFirst (p: lib.getName p == "capsule-reset-home")
    (throw "resetHomeCases: capsule-reset-home is not in the evaluated guest's environment.systemPackages")
    guest.environment.systemPackages;
in
  pkgs.runCommand "capsule-reset-home-cases" {} ''
    fail=0
    ck() {
      if [ "$2" = "$3" ]; then echo "ok   $1" >>"$log"
      else echo "FAIL $1: got '$3', wanted '$2'" >&2; fail=1; fi
    }
    ckt() {
      if "''${@:2}"; then echo "ok   $1" >>"$log"
      else echo "FAIL $1" >&2; fail=1; fi
    }
    log=$PWD/log
    : >"$log"

    export CASE_ROOT=$PWD/root CASE_LOG=$PWD/units CASE_SESSIONS=$PWD/sessions
    prog=${fixture}/bin/capsule-reset-home
    home=$CASE_ROOT/work/home

    run() { rc=0; "$prog" "$@" >out 2>err || rc=$?; }
    acts() { tr '\n' ',' <"$CASE_LOG" | sed 's/,$//'; }

    # sec-2's table: what a running guest reports with nobody connected.
    idle() {
      printf '%s\n' \
        '1 tty1 login user active' \
        '2 ttyS0 login user active' \
        '3 - systemd-user manager active' >"$CASE_SESSIONS"
    }
    # A `$HOME` with something in it, the three scrub paths, and a file beside
    # them that no declaration names.
    fresh() {
      rm -rf "$CASE_ROOT"
      mkdir -p "$home/.claude" "$CASE_ROOT/work/ssh"
      echo token >"$home/.claude/.credentials.json"
      echo 'export K=v' >"$CASE_ROOT/work/.env"
      echo key >"$CASE_ROOT/work/ssh/key"
      echo pub >"$CASE_ROOT/work/ssh/key.pub"
      echo keep >"$CASE_ROOT/work/ssh/keep"
      echo 0 >"$CASE_ROOT/active-calls"
      : >"$CASE_LOG"
      idle
      unset CASE_ACTIVE CASE_FAIL
    }
    gettys="getty@tty1.service serial-getty@ttyS0.service"

    # ------------------------------------------------------------------ premises
    ckt "premise: the sandbox is not root" test "$(id -u)" != 0

    # --------------------------------------------------------------------- usage
    fresh
    run --force
    ck "an unknown argument is a usage error" 2 "$rc"
    ckt "  and says so" grep -q '^usage: capsule-reset-home' err
    ck "  before any unit is touched" "" "$(acts)"
    run --scrub --scrub
    ck "two arguments are a usage error" 2 "$rc"

    # ------------------------------------------------------------------ sessions
    #
    # The program's `workingSessions` (sec-2's rule) over a stubbed listing.
    fresh
    run
    ck "the gettys' autologins and the agent's user manager are not work" 0 "$rc"

    fresh
    echo '4 - sshd user active' >>"$CASE_SESSIONS"
    run
    ck "an ssh login is work, and refuses as busy" 3 "$rc"
    ckt "  as working" grep -q 'agent is working' err
    ckt "  listing that session" grep -qx '4 - sshd user active' err
    ckt "  and not the ones that are not work" test -z "$(grep -E '^[123] ' err)"
    ck "  stopping nothing" "" "$(acts)"
    ckt "  and deleting nothing" test -e "$home/.claude/.credentials.json"

    fresh
    echo '5 - systemd-user background active' >>"$CASE_SESSIONS"
    run
    ck "a class nobody has seen on this guest refuses" 3 "$rc"
    ckt "  listing it" grep -qx '5 - systemd-user background active' err

    fresh
    echo '6 - ? ? ?' >>"$CASE_SESSIONS"
    run
    ck "a session that could not be read refuses" 3 "$rc"

    fresh
    # `Service=systemd-user`, not `login`: a real manager-early session is root's
    # user manager (plan.md's slot-b table), and a row spelled `login` is passed
    # by the getty exclusion whatever the manager-early clause does (RV-004 F-3).
    echo '7 - systemd-user manager-early active' >>"$CASE_SESSIONS"
    run
    ck "a manager-early session is not work" 0 "$rc"

    # --------------------------------------------------------------------- order
    fresh
    run
    ck "a reset of an idle agent succeeds" 0 "$rc"
    ck "  stopping the gettys, then the slice, before \$HOME goes; reseeding after; gettys back last" \
      "stop $gettys home=present scrub=present,stop user-1000.slice home=present scrub=present,active? user-1000.slice,restart capsule-seed home=absent scrub=present,active? user-1000.slice,start $gettys home=absent scrub=present" \
      "$(acts)"
    ckt "  and \$HOME is gone" test ! -e "$home"
    ckt "  and nothing but \$HOME" test -e "$CASE_ROOT/work/.env" -a -e "$CASE_ROOT/work/ssh/key"

    fresh
    export CASE_ACTIVE=active
    run
    ck "a slice still active after its stop cannot keep the agent out" 4 "$rc"
    ckt "  by reason" grep -q 'still active after its stop' err
    ckt "  and \$HOME is untouched" test -e "$home/.claude/.credentials.json"
    ck "  and the gettys were started again" "start $gettys home=present scrub=present" "$(tail -n 1 "$CASE_LOG")"

    fresh
    export CASE_ACTIVE="inactive active"
    run
    ck "a login arriving during the reset cannot keep the agent out" 4 "$rc"
    ckt "  by reason" grep -q 'login arrived during the reset' err
    ckt "  asking for a rerun" grep -q 'run it again' err
    ck "  and the gettys were started again" "start $gettys home=absent scrub=present" "$(tail -n 1 "$CASE_LOG")"

    fresh
    export CASE_FAIL="restart capsule-seed"
    run
    ckt "a failure after the gettys stopped is neither success nor a named refusal" \
      test "$rc" != 0 -a "$rc" != 3 -a "$rc" != 4
    ck "  and the gettys were started again" "start $gettys home=absent scrub=present" "$(tail -n 1 "$CASE_LOG")"

    fresh
    export CASE_FAIL="stop user-1000.slice"
    run
    ckt "a slice that will not stop fails" test "$rc" != 0
    ckt "  and \$HOME is untouched" test -e "$home/.claude/.credentials.json"
    ck "  and the gettys were started again" "start $gettys home=present scrub=present" "$(tail -n 1 "$CASE_LOG")"

    # ------------------------------------------------------------------- symlink
    fresh
    rm -rf "$home"
    mkdir -p "$CASE_ROOT/elsewhere"
    echo precious >"$CASE_ROOT/elsewhere/file"
    ln -s "$CASE_ROOT/elsewhere" "$home"
    run
    ck "a \$HOME that is a symlink resets" 0 "$rc"
    ckt "  removing the link" test ! -L "$home" -a ! -e "$home"
    ckt "  and not what it pointed at" grep -qx precious "$CASE_ROOT/elsewhere/file"

    # --------------------------------------------------------------------- scrub
    fresh
    run --scrub
    ck "a scrub succeeds" 0 "$rc"
    ck "  removing the scrub paths after the reseed, then making host keys, then restarting sshd" \
      "stop $gettys home=present scrub=present,stop user-1000.slice home=present scrub=present,active? user-1000.slice,restart capsule-seed home=absent scrub=present,start sshd-keygen home=absent scrub=absent,restart sshd home=absent scrub=absent,active? user-1000.slice,start $gettys home=absent scrub=absent" \
      "$(acts)"
    ckt "  and a file beside them that nothing names survives" grep -qx keep "$CASE_ROOT/work/ssh/keep"

    fresh
    run
    ckt "without --scrub the scrub paths survive" \
      test -e "$CASE_ROOT/work/.env" -a -e "$CASE_ROOT/work/ssh/key" -a -e "$CASE_ROOT/work/ssh/key.pub"
    ckt "  and neither host keys nor sshd are touched" test -z "$(grep -E 'sshd' "$CASE_LOG")"

    # ---------------------------------------------------------------- the image
    #
    # Verdicts about this host's scrub list, from the values the guest was built
    # with. The expected values are read from `target` and the guest's `config`,
    # and nothing target-shaped is spelled here.
    shippedPaths=(${lib.escapeShellArgs shipped.scrubPaths})
    agentHome=${lib.escapeShellArg guest.users.users.agent.home}
    listed() { printf '%s\n' "''${shippedPaths[@]}" | grep -qxF -- "$1"; }

    ckt "every path the image carries passes the same guard" \
      test ${lib.boolToString shippedPlain} = true
    ckt "the shipped scrub list is not empty" test "''${#shippedPaths[@]}" -gt 0
    ck "  and has nothing under \$HOME, which the reset already removes" "" \
      "$(printf '%s\n' "''${shippedPaths[@]}" | grep -F -- "$agentHome/" || true)"
    ckt "  and has the target volume's .env" listed ${lib.escapeShellArg "${target.volumePath}/.env"}
    for key in ${lib.escapeShellArgs (map (k: k.path) guest.services.openssh.hostKeys)}; do
      ckt "  and has the declared host key $key" listed "$key"
      ckt "  and its public half" listed "$key.pub"
    done

    # The guard that stands between a target's `volumePath` and a root `rm`. Each
    # verdict was taken at eval; the shell only reads them out (CLAUDE.md).
    ckt "a plain absolute path is built" test ${lib.boolToString verdicts.plain} = true
    ckt "  a path with a space is refused at eval" test ${lib.boolToString verdicts.spaced} = false
    ckt "  and one with a glob character" test ${lib.boolToString verdicts.globbed} = false
    ckt "  and a relative one, which would resolve against root's cwd" \
      test ${lib.boolToString verdicts.relative} = false
    ckt "  and a shell expression, which is what the fixture passes on purpose" \
      test ${lib.boolToString verdicts.expression} = false

    # ------------------------------------------------------ the shipped listing
    #
    # The shipped program, run as the guest runs it, with `loginctl` and
    # `systemctl` faked on `PATH`. That works because neither is in its
    # `runtimeInputs`: it uses the running guest's. So these cases run the real
    # `agentSessions` against logind's output shape, where the fixture above
    # stubs the listing whole. Each one refuses before the shipped program could
    # reach its fixed `$HOME`, and the fake `systemctl` refuses every act anyway.
    fakes=$PWD/fakes
    mkdir -p "$fakes/bin" "$fakes/sessions"
    cat >"$fakes/bin/loginctl" <<'FAKE'
    #!${pkgs.runtimeShell}
    # list-sessions: logind's columns, of which only the first is read.
    # show-session <id> -p …: the session's key=value file, or an error.
    case "$1" in
      list-sessions)
        [ -z "''${CASE_LIST_FAIL:-}" ] || { echo "Failed to list sessions" >&2; exit 1; }
        for f in "$CASE_FAKES"/sessions/*; do
          [ -e "$f" ] && echo "$(basename "$f") 1000 agent - 1 user - no -"
        done ;;
      show-session) cat "$CASE_FAKES/sessions/$2" 2>/dev/null || { echo "No session '$2' known" >&2; exit 1; } ;;
      *) exit 1 ;;
    esac
    FAKE
    cat >"$fakes/bin/systemctl" <<'FAKE'
    #!${pkgs.runtimeShell}
    echo "$*" >>"$CASE_FAKES/systemctl"
    exit 1
    FAKE
    sed -i 's/^    //' "$fakes/bin/loginctl" "$fakes/bin/systemctl"
    chmod +x "$fakes/bin/loginctl" "$fakes/bin/systemctl"
    export CASE_FAKES=$fakes
    session() { printf 'Name=%s\nTTY=%s\nService=%s\nClass=%s\nState=active\n' "$2" "$3" "$4" "$5" >"$fakes/sessions/$1"; }
    shippedFresh() {
      rm -f "$fakes/sessions/"* "$fakes/systemctl"
      : >"$fakes/systemctl"
      session 1 agent tty1 login user
      session 2 agent ttyS0 login user
      session 3 agent "" systemd-user manager
      session 8 root "" sshd user
      unset CASE_LIST_FAIL
    }
    runShipped() { rc=0; PATH="$fakes/bin:$PATH" ${shipped}/bin/capsule-reset-home "$@" >out 2>err || rc=$?; }

    shippedFresh
    session 4 agent "" sshd user
    runShipped
    ck "the shipped listing reads an agent ssh login out of logind as work" 3 "$rc"
    ckt "  printed as the rule reads it, with no tty" grep -qx '4 - sshd user active' err
    ckt "  and not root's session, nor the ones that are not work" test -z "$(grep -E '^[1238] ' err)"
    ck "  stopping nothing" "" "$(cat "$fakes/systemctl")"

    shippedFresh
    export CASE_LIST_FAIL=1
    runShipped
    ckt "a shipped listing that fails is not read as nobody working" test "$rc" != 0 -a "$rc" != 3
    ck "  stopping nothing" "" "$(cat "$fakes/systemctl")"

    shippedFresh
    touch "$fakes/sessions/9"
    chmod 000 "$fakes/sessions/9"
    runShipped
    ck "a session the shipped listing cannot read refuses" 3 "$rc"
    ckt "  listed as unknown" grep -qx '9 - ? ? ?' err

    # The one store path a guest runs, read with comments dropped so a sentence
    # cannot satisfy it; referencing it also builds it, which is what shellchecks
    # the real `tools`.
    code=$(grep -v '^[[:space:]]*#' ${shipped}/bin/capsule-reset-home)
    ckt "the shipped program removes \$HOME with no trailing slash" \
      grep -qxF "rm -rf -- \"\$home\"" <<<"$(sed 's/^[[:space:]]*//' <<<"$code")"
    ckt "  names the agent's slice by its uid" \
      grep -qxF ${lib.escapeShellArg "slice=user-${toString guest.users.users.agent.uid}.slice"} <<<"$code"
    ckt "  and asks logind, not a stub" grep -qF 'loginctl show-session' <<<"$code"

    [ "$fail" = 0 ] || exit 1
    cp "$log" $out
    cat $out
  ''
