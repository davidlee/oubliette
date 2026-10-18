# `capsule-room-git`: the room channel (SL-006 design sec-4, `DEC-045`). One
# program and one store path for every room, which pushes a host branch into a
# room's clone of a repo or collects one branch of it back into this host's
# quarantine:
#
#   capsule-room-git --room <r> --profile <repo> --user <u> --policy <p> push    <branch>
#   capsule-room-git --room <r> --profile <repo> --user <u> --policy <p> collect <branch>
#
# It learns the room and the repo at run time and nothing else: it holds no table
# of rooms or repos, and whether `<repo>` is one of the room's is the front end's
# question, never this program's (`DEC-051`, POL-002).
#
# **Exit statuses** (`DEC-050`), and their order is the contract:
#
#   2   every caller error, decided on this host before the room is asked
#       anything — usage, a token, the user, the policy and its permission, the
#       branch, the profile document, and for a push the branch in the host
#       checkout. So none of them can read as 75.
#   75  the room is not answering: no socket, or no `SSH-2.0-` banner through it.
#       Transport, and only transport — a stopped room is a caller's routine.
#   1   anything after the banner: authentication, a changed host key, the push,
#       the fetch. Trust failures are failures, never downtime.
#
# Nothing is written before the banner, so a 2 or a 75 leaves this host's state
# as it found it. Stdout is the answer and nothing else: push prints `<oid>`,
# collect `<oid>\t<ref>` — git's `ls-remote` order, split on the tab. That line
# is outward-facing (satan's runner reads it, SL-023), so change it there too.
#
# **Its trust store is per room and strict** (`DEC-047`): `$state/room/<r>/known_hosts`,
# `HostKeyAlias=room-<r>`, `StrictHostKeyChecking=accept-new`. Accept-new is sound
# because the path is a socket this host created into a VM this host booted;
# it learns an unknown key and refuses a changed one. Never the slot
# relaxation (`guestSsh.args`), which checks nothing (POL-001). `door` below is
# those words, so the front end's door (PHASE-05) checks the same file.
#
# **Wrapped on the module path** (host/services.nix), like `capsule-collect`:
# bare, `$state` falls back to `$root/.vm/host` and `profileDir()` to the store's
# documents (design sec-4, RV-015 F-3, `ISS-004`). So it is not in the devshell,
# where it would keep a second trust store for the same room.
#
# Three readings of the design, one line each:
#   - `--profile` is `profileLoad`, not `select`: `select` exits 1 and falls
#     back to `CAPSULE_PROFILE`, and here every caller error is 2 and argv is
#     the only source. The design names `select`; this keeps its rule.
#   - the branch passes `check-ref-format --branch` *and* the full refname
#     form, since inside a repository `--branch` expands `@{-1}`.
#   - push resolves `refs/heads/<branch>`, exactly, so a tag of the same name is
#     never what it sends.
#
# A push runs the host repo's `pre-push` hook, as `capsule-provision` does; not
# handled. The human's ssh config still applies to options not given here (an
# identity, say); the trust options are given here, and ssh takes the first.
#
# `CAPSULE_STATE` with whitespace or `%` in it is refused (2): ssh reads
# `UserKnownHostsFile` as a whitespace-separated list and expands `%` tokens in
# it, so such a path would name a different trust store.
{
  pkgs,
  lib,
  quarantine,
  profile,
  policies,
  guestSsh,
  # Where room `<name>`'s socket is, given a shell expression — `rooms.socketOf`
  # for the shipped copy, a sandbox path for `roomGitCases` (POL-004).
  socketOf,
  # `rooms.stateDirOf`: the room's host-side state directory (DEC-047).
  stateDirOf,
}: let
  socat = lib.getExe pkgs.socat;

  # The strict ssh words every door to a room uses (`DEC-047`), as shell words
  # for an argv array. Each argument is a shell expression that expands inside
  # double quotes (`$room`, `$sock`), as `proxyThrough`'s `socket` is.
  door = {
    room,
    socket,
    knownHosts,
  }: ''-o StrictHostKeyChecking=accept-new -o "HostKeyAlias=room-${room}" -o "UserKnownHostsFile=${knownHosts}" ${guestSsh.proxyThrough {inherit socat socket;}}'';

  # The room's trust store, the file `door` names (DEC-047): the one spelling
  # of its name, for this program, the front end's door and its
  # `forget-host-key`. `knownHostsIn` takes the room's directory, which this
  # program makes; `knownHostsOf` the state root and the room, for a caller
  # that makes nothing. Shell expressions, as `stateDirOf`'s are.
  knownHostsIn = roomDir: "${roomDir}/known_hosts";
  knownHostsOf = state: room: knownHostsIn (stateDirOf state room);

  # ssh reads `UserKnownHostsFile` as a whitespace-separated list and expands
  # `%` tokens in it, so a state root holding either would name a different
  # trust store: refused, by every reader of the file. `state` is a shell
  # expression, `refuse` the caller's function that prints its lines and exits 2.
  refuseOddState = state: refuse: ''
    case "${state}" in
      *[[:space:]%]*)
        ${refuse} "this host's state directory '${state}' holds whitespace or '%'," \
          "  which ssh would read as a list or a token in UserKnownHostsFile, so it" \
          "  would check a different trust store. CAPSULE_STATE chooses it."
        ;;
    esac'';

  program = pkgs.writeShellApplication {
    name = "capsule-room-git";
    runtimeInputs = [pkgs.git pkgs.openssh pkgs.coreutils pkgs.socat];
    text = ''
      ${quarantine.fragment}
      ${profile.fragment}
      ${quarantine.policyLimits policies}
      ${quarantine.boundedFetch}

      me=capsule-room-git
      usage() {
        echo "$me: $1" >&2
        echo "usage: $me --room <r> --profile <repo> --user <u> --policy <p> push|collect [--] <branch>" >&2
        exit 2
      }
      refuse() {
        for line in "$@"; do echo "$me: $line" >&2; done
        exit 2
      }

      # Argv only (`DEC-041`): no `CAPSULE_NAME`, no `CAPSULE_PROFILE`, no
      # `CAPSULE_REPO` — a default ahead of the argument is a second answer
      # (`ISS-008`). Space form only, each flag once.
      room="" profile="" user="" policy="" given=" "
      positional=()
      while [ "$#" -gt 0 ]; do
        case "$1" in
          --room | --profile | --user | --policy)
            [ "$#" -ge 2 ] || usage "$1 needs a value"
            case "$given" in *" $1 "*) usage "$1 is given twice" ;; esac
            given+="$1 "
            case "$1" in
              --room) room=$2 ;;
              --profile) profile=$2 ;;
              --user) user=$2 ;;
              --policy) policy=$2 ;;
            esac
            shift 2
            ;;
          --)
            shift
            positional+=("$@")
            break
            ;;
          -*) usage "'$1' is not an option of this program; a room is named by --room, on argv only" ;;
          *)
            positional+=("$1")
            shift
            ;;
        esac
      done
      for flag in --room --profile --user --policy; do
        case "$given" in *" $flag "*) ;; *) usage "no $flag" ;; esac
      done
      [ "''${#positional[@]}" -eq 2 ] || usage "a verb and one branch, and nothing else"
      verb=''${positional[0]} branch=''${positional[1]}
      case "$verb" in push | collect) ;; *) usage "no verb '$verb'" ;; esac

      ${refuseOddState "$state" "refuse"}

      ${quarantine.refuseToken 2 ''"$room"'' "'--room $room'"}
      ${quarantine.refuseToken 2 ''"$profile"'' "'--profile $profile'"}

      # It goes into the URL's userinfo, so it is a login name: rooms.nix's
      # `userSafe`, and never a leading `-` an ssh argv could take for an option.
      if [[ ! "$user" =~ ^[a-z_][a-z0-9_-]*$ ]] || [ "''${#user}" -ge 32 ]; then
        refuse "'--user $user' is not a login name: it goes into the URL," \
          "  so it is [a-z_][a-z0-9_-]*, under 32 characters — the room's repos.user."
      fi

      policyLimits "$policy" ||
        refuse "no policy named '$policy'." "  declared: ${quarantine.policyNames policies}"
      # Both verbs (SL-006 design sec-4 step 1): a room the policy may not collect
      # from is not a room this channel works.
      [ "$may" = yes ] ||
        refuse "policy '$policy' does not permit collecting, so this channel does not" \
          "  run under it for room '$room', in either direction (DEC-046)."

      if ! { git check-ref-format --branch "$branch" >/dev/null 2>&1 &&
        git check-ref-format "refs/heads/$branch"; }; then
        refuse "'$branch' is not a branch name git accepts (check-ref-format), so it" \
          "  cannot be one ref on either end — and never a pattern."
      fi

      profileLoad "$profile" || exit 2

      if [ "$verb" = push ]; then
        oid=$(git -C "$profile_path" rev-parse --verify --quiet "refs/heads/$branch^{commit}" 2>/dev/null) || oid=""
        [ -n "$oid" ] ||
          refuse "$profile_path has no branch '$branch', so there is nothing to push" \
            "  to room '$room'. A push sends a host branch: make it there first."
      fi

      # The pre-flight: the socket, and an ssh banner through it. `readbytes=8`
      # stops at `SSH-2.0-`, since sshd says nothing more until the client
      # speaks, so a healthy room costs a round trip and not the timeout.
      # `$room` holds no `,` or `:` (the token check above), so the socket path
      # is one socat address. Both conventions are spliced on the right of an
      # assignment, which does not word-split, so they take bare expansions.
      sock=${socketOf "$room"}
      notAnswering() {
        echo "$me: room '$room' is not answering: $1." >&2
        echo "  That is the transport, not a verdict on the room's trust:" >&2
        echo "  is it started? systemctl status capsule-ssh-relay-$room" >&2
        exit 75
      }
      [ -S "$sock" ] || notAnswering "$sock is not a socket"
      banner=$(timeout 5 socat -u UNIX-CONNECT:"$sock",readbytes=8 STDOUT 2>/dev/null) || true
      # A prefix, not the eight bytes exactly: what the check is about is whose
      # banner it is, and how much of it arrives is socat's business.
      case "$banner" in
        SSH-2.0-*) ;;
        *) notAnswering "no ssh banner through $sock" ;;
      esac

      # After the banner, every failure is 1, and each act says so itself: under
      # plain errexit a failed `git init` would exit 128.
      roomDir=${stateDirOf "$state" "$room"}
      knownHosts=${knownHostsIn "$roomDir"}
      # Every directory it makes is the owner's alone; one that is there (the
      # module's tmpfiles made it) is left as it is.
      (umask 077 && mkdir -p "$roomDir") || exit 1
      ssh_cmd=(ssh ${door {
        room = "$room";
        socket = "$sock";
        knownHosts = "$knownHosts";
      }} -o BatchMode=yes -o ConnectTimeout=10)
      GIT_SSH_COMMAND=$(printf '%q ' "''${ssh_cmd[@]}")
      export GIT_SSH_COMMAND
      url="ssh://$user@room-$room$profile_guest_path"

      case "$verb" in
        push)
          git -C "$profile_path" push "$url" "+$oid:refs/host/$branch" >&2 || {
            echo "$me: push of $branch ($oid) to room '$room' failed (see above)." >&2
            exit 1
          }
          printf '%s\n' "$oid"
          ;;
        collect)
          quarantine=${quarantine.repoOf "$room/$profile"}
          if [ ! -d "$quarantine" ]; then
            mkdir -p "$(dirname "$quarantine")" || exit 1
            git init --bare --quiet "$quarantine" || exit 1
          fi
          ref=${quarantine.codeRefsOf "$room"}/$branch
          boundedFetch "$quarantine" "$maxBytes" "$url" "+refs/heads/$branch:$ref" >&2 || {
            echo "$me: collect of $branch from room '$room' failed: the room, its" >&2
            echo "  host key, a malformed object, or a pack over $maxBytes bytes" >&2
            echo "  (policy $policy's collectMaxPackBytes)." >&2
            exit 1
          }
          oid=$(git -C "$quarantine" rev-parse --verify --quiet "$ref^{commit}") || exit 1
          [ -n "$oid" ] || exit 1
          printf '%s\t%s\n' "$oid" "$ref"
          ;;
      esac
    '';
  };
in {
  inherit program door knownHostsOf refuseOddState;
}
