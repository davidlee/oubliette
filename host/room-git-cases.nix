# `capsule-room-git`, the room channel (host/room-git.nix, SL-006 design sec-4),
# at its exit-status contract: **2** for a caller error, decided on this host
# before the room is asked anything; **75** for a room that is not answering;
# **1** for anything after the banner (`DEC-050`).
#
# The third kind of check (CLAUDE.md), and the second over a program that talks
# to a guest, after `gitChannelCases`. Like that one, **what it can reach is
# everything upstream of the door**: the program has `pkgs.openssh` in its
# `runtimeInputs`, so `writeShellApplication` puts it on `PATH` ahead of anything
# a sandbox could stub, and there is no faking a guest here. Upstream of the door
# is most of this program — the argv, the token, user, policy and branch
# refusals, the profile, push's resolution of its branch in the host checkout —
# and every one of them must refuse with 2 *before* the pre-flight, which is the
# ordering a sandbox can see: a build sandbox has no `/run/capsule-room`, so the
# shipped copy can only ever stop at the pre-flight with 75, and a caller error
# decided too late reads as 75 here (EX-4).
#
# **Not reachable by any case**: ssh past an identification string, so an
# authentication or host-key failure, an actual push landing `refs/host/<b>`, an
# actual collect landing in `collect/<r>/<repo>.git`, accept-new writing the
# room's `known_hosts`. Those are the live rung's (design sec-8, `STD-001`).
#
# **Handed a fixture door** as well as the shipped program, and it is the
# fixture this suite says it has: the same text built against a socket path
# under the sandbox (`roomGitOf`, host/programs.nix), since the shipped path is
# fixed at build under `/run`. A socket nobody's, a listener this suite runs,
# and nothing of this host's. That reaches the two branches the pre-flight
# exists for — a relay that accepts and says nothing, or says something that is
# not ssh, is **75**; a banner that is ssh's and then a failed key exchange is
# **1** — and the pre-flight's own speed (`readbytes`).
#
# **No `jq` on this suite's `PATH`**, on purpose: the profile reader needs it,
# and calls it by store path (`DEC-053`), so a program that splices the reader
# carries it. The fixture documents here are written with `printf`.
#
# The policies are picked from the caller's vocabulary rather than named: one
# that permits collecting and one that does not. A vocabulary lacking either
# skips that half and says so in the log.
{
  pkgs,
  lib,
  # The store path this host ships (host/programs.nix's `roomGit`).
  roomGit,
  # The host's policy vocabulary (the fleet's `policies`).
  policies,
  # The same program built with room `<r>`'s socket at `$CASE_RUN/<r>.sock`.
  fixtureDoor,
}: let
  firstWhere = p: lib.findFirst p "" policies.everything;
  permits = firstWhere (n: policies.policies.${n}.mayCollect);
  forbids = firstWhere (n: !policies.policies.${n}.mayCollect);
in
  pkgs.runCommand "capsule-room-git-cases" {
    # socat for the fixture door's listeners only; the program carries its own.
    nativeBuildInputs = [pkgs.git pkgs.socat];
  } ''
    export HOME=$PWD
    git config --global user.email c@example.invalid
    git config --global user.name cases
    git config --global init.defaultBranch main
    here=$PWD

    fail=0
    log=$here/log
    : >"$log"
    shown() { sed 's/^/    out: /' "$here/out" >&2; sed 's/^/    err: /' "$here/err" >&2; }
    ck() {
      if [ "$2" = "$3" ]; then echo "ok   $1" >>"$log"
      else echo "FAIL $1: got '$3', wanted '$2'" >&2; shown; fail=1; fi
    }
    saw() {
      if grep -qF -- "$1" "$here/err"; then echo "ok   ...and says '$1'" >>"$log"
      else echo "FAIL missing reason '$1'" >&2; shown; fail=1; fi
    }
    never() {
      if grep -qF -- "$1" "$here/err"; then echo "FAIL said '$1' and should not have" >&2; shown; fail=1
      else echo "ok   ...and never says '$1'" >>"$log"; fi
    }
    # Stdout is the answer and nothing else, so a run that answered
    # nothing printed nothing.
    quiet() {
      if [ -s "$here/out" ]; then echo "FAIL printed on stdout" >&2; shown; fail=1
      else echo "ok   ...and prints nothing on stdout" >>"$log"; fi
    }
    # Nothing is written before the banner: a refused or 75 run leaves
    # this host's state as it found it.
    untouched() {
      if [ -n "$(ls -A "$here/state")" ]; then
        echo "FAIL wrote into state/ before the banner:" >&2; find "$here/state" >&2; fail=1
      else echo "ok   ...and writes nothing under state/" >>"$log"; fi
    }
    # A refusal: its status, its reason, no answer, no state.
    refused() { ck "$1" "$2" "$rc"; saw "$3"; quiet; untouched; }
    run() { rc=0; "$@" >"$here/out" 2>"$here/err" || rc=$?; }

    # The premise every 75 below rests on: no room's socket exists here, so the
    # shipped copy cannot get past the pre-flight.
    if [ -e /run/capsule-room ]; then
      echo "FAIL /run/capsule-room exists in the sandbox, so nothing here means what it says" >&2
      exit 1
    fi

    # The host checkout: `main`, a second branch entered and left so `@{-1}`
    # resolves inside it, and a tag with no branch of its name.
    git init -q src
    git -C src commit -q --allow-empty -m first
    git -C src switch -q -c other
    git -C src switch -q main
    git -C src tag onlytag
    # A second repository that *has* a branch `src` lacks, for CAPSULE_REPO.
    git init -q elsewhere
    git -C elsewhere commit -q --allow-empty -m first
    git -C elsewhere branch nosuch

    mkdir -p profiles state
    export CAPSULE_PROFILE_DIR=$here/profiles CAPSULE_STATE=$here/state
    doc() {
      printf '{"schema":1,"name":"%s","path":"%s","guestPath":"/vol/%s","volumePath":"/vol",' "$1" "$2" "$1"
      printf '"cachePaths":[],"baseline":null,"refresh":null,"statePaths":[],"stateMaxBytes":0,'
      printf '"sizes":{"vcpu":1,"mem":1,"volume":1}}\n'
    }
    doc alpha "$here/src" >profiles/alpha.json
    doc beta /nowhere/beta >profiles/beta.json

    rg=${lib.getExe roomGit}
    permits=${lib.escapeShellArg permits}
    forbids=${lib.escapeShellArg forbids}
    sock=/run/capsule-room/nobody-room/ssh.sock
    # Every flag, well-formed; a case changes the one it is about.
    base=(--room nobody-room --profile alpha --user agent --policy "$permits")
    as() { run "$rg" "''${base[@]}" "$@"; }

    # ---------------------------------------------------------------- usage, 2
    #
    # argv only, space form only, each flag once (DEC-041).
    run "$rg"
    refused "no arguments is usage" 2 "usage:"
    for i in 0 2 4 6; do
      kept=("''${base[@]:0:$i}" "''${base[@]:$((i + 2))}")
      run "$rg" "''${kept[@]}" push main
      refused "no ''${base[$i]} is usage" 2 "no ''${base[$i]}"
    done
    run "$rg" "''${base[@]:2}" push main --room
    refused "--room as the last word is usage" 2 "--room needs a value"
    as --room other-room push main
    refused "--room twice is usage" 2 "--room is given twice"
    as --capsule x push main
    refused "--capsule is not this program's" 2 "'--capsule'"
    run "$rg" --room=nobody-room "''${base[@]:2}" push main
    refused "--room=x is not the form" 2 "'--room=nobody-room'"
    as fetch main
    refused "a verb that is not push or collect" 2 "no verb 'fetch'"
    as push
    refused "a verb with no branch" 2 "usage:"
    as push main extra
    refused "a third positional" 2 "usage:"
    as push -x
    refused "a dash word after the verb is still an option" 2 "'-x'"
    # The environment names nothing (DEC-041, ISS-008).
    run env CAPSULE_NAME=nobody-room CAPSULE_PROFILE=alpha "$rg" "''${base[@]:4}" push main
    refused "CAPSULE_NAME and CAPSULE_PROFILE are not flags" 2 "no --room"

    # A state directory ssh would read as two trust stores, or expand.
    for bad in "$here/st ate" "$here/st%date"; do
      run env CAPSULE_STATE="$bad" "$rg" "''${base[@]}" push main
      refused "CAPSULE_STATE '$bad' cannot hold a known_hosts" 2 "whitespace or '%'"
    done

    # ------------------------------------------------------- tokens and user, 2
    for r in .. a/b ""; do
      run "$rg" --room "$r" "''${base[@]:2}" push main
      refused "--room '$r' is not an opaque name" 2 "'--room $r'"
      saw "opaque name"
    done
    run "$rg" --room nobody-room --profile .. "''${base[@]:4}" push main
    refused "--profile .. is not an opaque name" 2 "'--profile ..'"
    run "$rg" --room nobody-room --profile nosuch "''${base[@]:4}" push main
    refused "a profile this host has not rendered" 2 "no profile named 'nosuch'"
    for u in -oProxyCommand=x a@b; do
      run "$rg" "''${base[@]:0:4}" --user "$u" "''${base[@]:6}" push main
      refused "--user '$u' is not a login name" 2 "'--user $u' is not a login name"
    done

    # ------------------------------------------------------------ policy, 2
    for verb in push collect; do
      run "$rg" "''${base[@]:0:6}" --policy nosuch "$verb" main
      refused "$verb under a policy nobody declared" 2 "no policy named 'nosuch'"
      saw "declared: ${lib.concatStringsSep " " policies.everything}"
    done
    if [ -n "$forbids" ]; then
      for verb in push collect; do
        run "$rg" "''${base[@]:0:6}" --policy "$forbids" "$verb" main
        refused "$verb under '$forbids', which may not collect, refuses both verbs" 2 "does not permit"
      done
    else
      echo "skip every policy here permits collecting, so no may != yes case" >>"$log"
    fi

    if [ -z "$permits" ]; then
      echo "skip no policy here permits collecting, so nothing past the policy is reached" >>"$log"
    else
      # ------------------------------------------------------------ branch, 2
      #
      # `check-ref-format --branch` (the design's) and the full refname form, which
      # reads no repository.
      for verb in push collect; do
        for b in '*' a..b; do
          as "$verb" "$b"
          refused "$verb of branch '$b' (check-ref-format)" 2 "is not a branch name"
        done
        as "$verb" -- -x
        refused "$verb of branch '-x' after --" 2 "is not a branch name"
        # Inside a repository `--branch` expands `@{-1}` and succeeds.
        run env -C "$here/src" "$rg" "''${base[@]}" "$verb" '@{-1}'
        refused "$verb of '@{-1}' from inside a checkout" 2 "is not a branch name"
      done

      # ----------------------------------------- push's branch, 2, before the door
      #
      # EX-4: decided on this host before the pre-flight, so a branch the host
      # checkout lacks is a refusal and never "the room is not answering".
      as push nosuch
      refused "push of a branch the host checkout lacks" 2 "has no branch 'nosuch'"
      never "$sock"
      as push onlytag
      refused "a tag is not a branch" 2 "has no branch 'onlytag'"
      run env CAPSULE_REPO="$here/elsewhere" "$rg" "''${base[@]}" push nosuch
      refused "CAPSULE_REPO does not move a room push" 2 "has no branch 'nosuch'"
      run "$rg" --room nobody-room --profile beta "''${base[@]:4}" push main
      refused "a push resolves in the document's checkout" 2 "/nowhere/beta"

      # ------------------------------------------------------------ the door, 75
      as push main
      refused "push with no socket is not answering" 75 "$sock"
      saw "not answering"
      as collect main
      refused "collect with no socket is not answering" 75 "$sock"

      # ------------------------------------------------- the fixture door, 75 and 1
      #
      # Past the socket test, on a door nobody's: a listener per room under
      # `$CASE_RUN`, each running one script per connection.
      export CASE_RUN=$here/run
      mkdir -p "$CASE_RUN"
      door=${lib.getExe fixtureDoor}
      listeners=()
      # Killed by pid and waited by pid, so a failing case cannot hang the build
      # on one.
      stopListeners() {
        for p in "''${listeners[@]}"; do kill "$p" 2>/dev/null || true; done
        for p in "''${listeners[@]}"; do wait "$p" 2>/dev/null || true; done
      }
      trap stopListeners EXIT
      listen() {
        printf '#!${pkgs.runtimeShell}\n%s\n' "$2" >"$CASE_RUN/$1.sh"
        chmod +x "$CASE_RUN/$1.sh"
        socat UNIX-LISTEN:"$CASE_RUN/$1.sock",fork EXEC:"$CASE_RUN/$1.sh" &
        listeners+=("$!")
        for _ in $(seq 50); do [ -S "$CASE_RUN/$1.sock" ] && return 0; sleep 0.1; done
        echo "FAIL listener $1 never made its socket" >&2
        exit 1
      }
      at() { run "$door" --room "$1" "''${base[@]:2}" "''${@:2}"; }

      # A relay that accepts and says nothing: the room stopped, the relay up
      # (DEC-050). The pre-flight's timeout is what ends it.
      listen silent 'sleep 30'
      at silent collect main
      refused "a door that says nothing is not answering" 75 "no ssh banner"
      # Something that answers, and is not ssh.
      listen noise 'printf "HTTP/1.1 400\r\n"'
      at noise collect main
      refused "a door that is not ssh is not answering" 75 "no ssh banner"

      # An ssh banner, then nothing until it closes: what sshd does until the
      # client speaks, so the pre-flight must stop at the banner rather than
      # wait for the close. Every connection is timestamped.
      listen talker "date +%s%N >>$CASE_RUN/talker.conns; printf 'SSH-2.0-fixture\r\n'; sleep 4"
      at talker push main
      ck "a push past the banner that fails is 1, not 75" 1 "$rc"
      quiet
      never "not answering"
      saw "push of main"
      ck "  and reached the door twice, the pre-flight's and ssh's" 2 "$(wc -l <"$CASE_RUN/talker.conns")"
      mapfile -t t <"$CASE_RUN/talker.conns"
      ms=$(( (t[1] - t[0]) / 1000000 ))
      echo "figure: pre-flight to ssh's connection, $ms ms (timeout 5 s)" >>"$log"
      ck "  and the pre-flight stopped at the banner (readbytes), $ms ms < 3000" yes "$([ "$ms" -lt 3000 ] && echo yes || echo no)"
      # Made after the banner and not before, and the owner's alone.
      ck "  and made the room's state directory, 0700" 700 "$(stat -c %a "$here/state/room/talker" 2>/dev/null)"
      : >"$CASE_RUN/talker.conns"

      at talker collect main
      ck "a collect past the banner that fails is 1, not 75" 1 "$rc"
      quiet
      never "not answering"
      saw "collect of main"
      ck "  and made the room's quarantine, bare" true \
        "$(git -C "$here/state/collect/talker/alpha.git" rev-parse --is-bare-repository 2>/dev/null)"
    fi

    [ "$fail" = 0 ] || exit 1
    cp "$log" $out
    cat $out
  ''
