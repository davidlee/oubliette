# `capsule <room> <verb>` — the six verbs a room takes and the refusal every
# other one meets (SL-005 design sec-7, `DEC-041`, `DEC-051`), and the eval
# refusal of a room whose name is a verb.
#
# The third kind of check (CLAUDE.md), over `capsule`. **Handed a fixture**, for
# `policyCases`' reason — a pool, rooms, repos and a policy that are nobody's
# are the subject — so it renders its own front end, with two slots and two
# rooms built by the real constructors (`capsules.instancesOf`, rooms.nix): one
# with repos and one without. A second render has a room named `ssh` that must
# not evaluate. Everything else is the shipped values, threaded from the call
# site.
#
# What it pins is everything **upstream of the first `systemctl`** a room runs,
# and the ssh argv as ssh itself resolves it: `pkgs.openssh` and `pkgs.systemd`
# are in the front end's `runtimeInputs` and nothing in a sandbox can stub them
# (RV-014 F-6), but `ssh … -G` prints the configuration it would use and
# connects to nothing. So: that a room's name is consumed as a name and not a
# verb, that a slot's verb on a room refuses with exit 2 and its reason, that a
# two-user room's `ssh` with no user refuses before any socket is looked at,
# that the socket a room's door uses is its record's and not the slot
# convention's (so `doorsOpen` never counts one), that the human's door is the
# strict one over the room's own known_hosts (`DEC-047`), that `push` and
# `collect` resolve the record's repo, user and policy and exec a faked
# `capsule-room-git` with them and with the state it resolved — and refuse a
# repo the room lacks, and every repo of a room with none — that
# `forget-host-key` empties the room's file and makes none, that a state root
# ssh would misread is refused, that status lists rooms after the slot table,
# and the collide verdict and its message.
#
# What it does **not** pin: a real connection through that door (a key
# learned, a changed one refused), the real channel behind `push`/`collect`
# (roomGitCases pins that program), `start` (`systemctl start`, readiness as
# root) or `stop` — those are the live run's — and the readiness probe's argv,
# which runs only after a start, so it is pinned **by text** over the built
# script, the weakest kind of pin.
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
  roomTrust,
  # rooms.nix, unapplied: the fixture's rooms are what it decides.
  rooms,
}: let
  fixture =
    capsules
    // {
      instances = capsules.instancesOf {
        one = {index = 0;};
        two = {index = 1;};
      };
    };
  # A room's keys are strings nobody holds and its uids are numbers in order;
  # only the user names are read here. `repos`, when given, brings the policy
  # and work volume rooms.nix requires beside it (DEC-048).
  roomsOf = decl:
    (rooms {inherit lib;} {
      rooms = lib.mapAttrs (_: {
        users,
        repos ? null,
      }:
        {
          users = builtins.listToAttrs (lib.imap1 (i: u: {
              name = u;
              value = {
                uid = 1000 + i;
                keys = ["ssh-ed25519 AAAA fixture-${u}"];
              };
            })
            users);
          sizes =
            {
              vcpu = 1;
              mem = 1024;
              volume = 1024;
            }
            // lib.optionalAttrs (repos != null) {work = 1024;};
        }
        // lib.optionalAttrs (repos != null) {
          inherit repos;
          policy = "build";
        })
      decl;
      # Targets and a policy vocabulary that are nobody's, for the one room
      # with repos — passed, never defaulted (POL-003). Only `guestPath` and
      # `everything` are read.
      targets.byName = {
        alpha.guestPath = "/work/alpha";
        beta.guestPath = "/work/beta";
      };
      policies.everything = ["build"];
      slotNames = builtins.attrNames fixture.instances;
    }).instances;
  renderRecords = records:
    import ./cli.nix {
      inherit pkgs lib net policies guestSsh;
      inherit observe observeFragment programVerbs profileVerbs stateRefPrefix volumeRootHelper roomTrust;
      capsules = fixture;
      moduleState = ''"$CASE_STATE"'';
      rooms = records;
    };
  render = roomDecl: renderRecords (roomsOf roomDecl);
  # One room with repos and one without, so each verb meets both.
  fixtureRooms = {
    solo = {
      users = ["ann"];
      repos = {
        user = "ann";
        targets = ["alpha" "beta"];
      };
    };
    pair.users = ["ada" "bob"];
  };
  cli = render fixtureRooms;
  # The same rooms, with `solo`'s socket somewhere a build can bind one: a
  # relative path, read against the directory the suite runs in, since the
  # front end quotes it and a variable would not expand. Only here — the main
  # render pins the record's real path.
  withRoomUp = renderRecords (lib.recursiveUpdate (roomsOf fixtureRooms) {solo.socket = "room-up/solo/ssh.sock";});
  # A room named for a verb: `capsule ssh …` could no longer be read either way.
  colliding = render {ssh.users = ["ann"];};
  collides = builtins.tryEval (builtins.deepSeq colliding.drvPath colliding.drvPath);
  quote = s: lib.escapeShellArg (toString s);
in
  pkgs.runCommand "capsule-room-verbs-cases" {nativeBuildInputs = [pkgs.python3];} ''
    export CASE_STATE=$PWD/state
    mkdir -p "$CASE_STATE"
    capsule=${lib.getExe cli}
    unset CAPSULE_NAME CAPSULE_STATE

    # The channel a room's push and collect hand on to, faked: `capsule-room-git`
    # is deliberately not in the front end's `runtimeInputs`, so the one found
    # is the one on the inherited PATH, and this prints what it was given.
    mkdir -p fakes/bin
    cat > fakes/bin/capsule-room-git <<'STUB'
    #!${pkgs.runtimeShell}
    echo argv:
    for a in "$@"; do echo "$a"; done
    echo "CAPSULE_STATE=$CAPSULE_STATE"
    exit "''${STUB_RC:-0}"
    STUB
    chmod +x fakes/bin/capsule-room-git
    export PATH="$PWD/fakes/bin:$PATH"

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
    refusal() { printf "capsule: '%s' is a room; rooms take ssh, start, stop, push, collect, forget-host-key (status lists them)" "$1"; }
    # What the fake channel prints for a room's push or collect on `solo`:
    # the record's values, in the channel's order, then the state it was given.
    channelSaw() {
      printf '%s\n' argv: --room solo --profile "$2" --user ann --policy build "$1" "$3" \
        "CAPSULE_STATE=''${4:-$CASE_STATE}"
    }
    exactly() { [ "$(cat out)" = "$(channelSaw "$@")" ]; }
    channelRan() { saw "argv:"; }

    # ------------------------------------------------------------ the name
    # A room's name is a name: a slot's verb after it is refused *as a room's*,
    # which is only possible if the word was consumed as one.
    run pair status
    ck "a slot's question on a room refuses" 2 "$rc"
    ckt "  naming it as a room" saw "$(refusal pair)"

    run pair provision
    ck "a program's verb on a room refuses" 2 "$rc"
    ckt "  naming it as a room" saw "$(refusal pair)"

    run solo frobnicate
    ck "an unknown word after a room refuses" 2 "$rc"
    ckt "  as a room's, before the verb is looked up" saw "$(refusal solo)"
    ckt "  and not as a word nobody knows" unsaw "neither a verb nor a capsule"

    run solo fetch
    ck "a slot's verb a room lacks refuses" 2 "$rc"
    ckt "  naming it as a room" saw "$(refusal solo)"

    run pair
    ck "a room with no verb refuses" 2 "$rc"
    ckt "  naming the room" saw "what should pair do?"

    # From the other side: a verb is still a verb with rooms declared, and an
    # unnamed one still means a slot — never a room.
    run ssh
    ck "an unnamed ssh is a slot's, with rooms declared" 1 "$rc"
    ckt "  resolved from the slots that are up" saw "no capsule is up, so an unnamed 'ssh'"
    ckt "  and not a room's" unsaw "is a room"

    # ------------------------------------------------------------ ssh
    run pair ssh
    ck "a two-user room's ssh with no user refuses" 2 "$rc"
    ckt "  naming the users it declares" saw "ada bob"
    ckt "  before any socket is looked at" unsaw "/run/capsule-room/pair/ssh.sock"

    run pair ssh -- true
    ck "  and with only a command, too" 2 "$rc"
    ckt "  naming the users it declares" saw "ada bob"

    run solo ssh
    ck "a one-user room's ssh with no socket refuses" 1 "$rc"
    ckt "  defaulting its one user rather than asking" unsaw "declares"
    ckt "  naming the record's socket, which no slot glob reaches" \
      saw "/run/capsule-room/solo/ssh.sock"
    ckt "  and how to bring it up" saw "capsule solo start"
    ckt "  with no devshell fallback" unsaw "module path owns this host"

    run pair ssh bob
    ck "a named user goes on to the socket" 1 "$rc"
    ckt "  which is the record's" saw "/run/capsule-room/pair/ssh.sock"

    CAPSULE_NAME=one run solo ssh
    ck "a room on argv wins over CAPSULE_NAME" 1 "$rc"
    ckt "  reaching the room's door" saw "/run/capsule-room/solo/ssh.sock"

    # ------------------------------------------------------------ push / collect
    # The front end resolves the repo, its user and the room's policy from the
    # record and execs the channel with them (DEC-051); the channel's status is
    # the front end's, since it is an exec (DEC-050).
    run solo push alpha main
    ck "a room's push execs the channel" 0 "$rc"
    ckt "  with the record's room, repo, user and policy, in order" exactly push alpha main

    run solo collect beta job/x
    ck "a room's collect execs the channel" 0 "$rc"
    ckt "  with the record's values and the branch as given" exactly collect beta job/x

    STUB_RC=75 run solo push alpha main
    ck "the channel's 75 is the front end's" 75 "$rc"
    STUB_RC=1 run solo collect alpha main
    ck "  and its 1" 1 "$rc"

    CAPSULE_STATE=$PWD/elsewhere run solo collect alpha main
    ck "a room's collect under CAPSULE_STATE" 0 "$rc"
    ckt "  hands the channel that state, so both read one trust store" \
      exactly collect alpha main "$PWD/elsewhere"

    CAPSULE_NAME=one run solo push alpha main
    ck "a room on argv wins over CAPSULE_NAME for a push" 0 "$rc"
    ckt "  and the channel is told the room" exactly push alpha main

    run solo push gamma main
    ck "a repo the room does not declare refuses" 2 "$rc"
    ckt "  naming it" saw "room 'solo' declares no repo 'gamma'"
    ckt "  and the room's repos" saw "its repos: alpha beta"
    ckt "  before the channel runs" unsaw "argv:"

    for args in "alpha" "alpha main extra" "--room x main"; do
      read -ra words <<< "$args"
      run solo push "''${words[@]}"
      ck "a push of '$args' refuses" 2 "$rc"
      ckt "  with the usage" saw "capsule solo push <repo> <branch>"
      ckt "  before the channel runs" unsaw "argv:"
    done

    for v in push collect; do
      run pair "$v" alpha main
      ck "a repo-less room's $v refuses" 2 "$rc"
      ckt "  saying it declares no repos" saw "room 'pair' declares no repos"
      ckt "  before the channel runs" unsaw "argv:"
    done
    run pair push
    ck "a repo-less room's bare push refuses" 2 "$rc"
    ckt "  for the room, not the arguments" saw "room 'pair' declares no repos"
    ckt "  so no usage" unsaw "<repo> <branch>"

    # ------------------------------------------------------------ forget-host-key
    # The room's own file, the one its door and its channel check (DEC-047),
    # emptied and kept; nothing made where there is none.
    mkdir -p "$CASE_STATE/room/solo"
    printf 'room-solo ssh-ed25519 AAAA one\nroom-solo ssh-rsa AAAA two\n' > "$CASE_STATE/room/solo/known_hosts"
    run solo forget-host-key
    ck "a room's forget-host-key, room down" 0 "$rc"
    ckt "  keeps the room's file" test -e "$CASE_STATE/room/solo/known_hosts"
    ckt "  and empties it" test ! -s "$CASE_STATE/room/solo/known_hosts"
    ckt "  saying which file it emptied" saw "forgot the room's host key ($CASE_STATE/room/solo/known_hosts)"

    run pair forget-host-key
    ck "a room with no file forgets nothing" 0 "$rc"
    ckt "  and says so" saw "nothing to forget"
    ckt "  making nothing" test ! -e "$CASE_STATE/room/pair"

    run solo forget-host-key x
    ck "a room's forget-host-key with an argument refuses" 2 "$rc"
    ckt "  saying it takes none" saw "takes no arguments"

    mkdir -p "$PWD/odd dir/room/solo"
    echo 'room-solo ssh-ed25519 AAAA one' > "$PWD/odd dir/room/solo/known_hosts"
    CAPSULE_STATE="$PWD/odd dir" run solo forget-host-key
    ck "a state root ssh would misread refuses" 2 "$rc"
    ckt "  naming why" saw "holds whitespace or '%'"
    ckt "  and leaves its file" test -s "$PWD/odd dir/room/solo/known_hosts"
    CAPSULE_STATE="$PWD/odd dir" run solo ssh
    ck "  and so does the door over it" 2 "$rc"
    ckt "  for the same reason" saw "holds whitespace or '%'"

    # ------------------------------------------------------------ status
    run all status
    ck "status answers with rooms declared" 0 "$rc"
    ckt "  listing every room" grep -qE '^  (solo|pair) ' out
    ckt "  both of them" test "$(grep -cE '^  (solo|pair) +[^ ]+ +no$' out)" = 2
    ckt "  after the slot table" \
      test "$(grep -n '^capsule ' out | cut -d: -f1)" -lt "$(grep -n '^rooms:' out | cut -d: -f1)"

    run --help
    ckt "usage names the rooms" saw "rooms:     pair solo"
    ckt "  and their six verbs" grep -qE '^  rooms: .*push <repo> <branch> \| collect <repo> <branch> \| forget-host-key' out

    # An unnamed status is the one unnamed verb a room can answer (design
    # sec-7, PHASE-10): with no slot up it falls through to every guest's
    # status, so a refused probe's reader sees which room holds the host. A
    # bound socket outlives its process, which is all `-S` asks.
    run status
    ck "an unnamed status with nothing up still refuses" 1 "$rc"
    ckt "  as an unnamed verb with no capsule up" saw "no capsule is up, so an unnamed 'status'"

    mkdir -p room-up/solo
    python3 -c 'import socket,sys; socket.socket(socket.AF_UNIX).bind(sys.argv[1])' room-up/solo/ssh.sock
    capsule=${lib.getExe withRoomUp} run status
    ck "an unnamed status with only a room up lists it" 0 "$rc"
    ckt "  without refusing" unsaw "no capsule is up"
    ckt "  after every slot, all down" test "$(grep -cE '^(one|two) ' out)" = 2
    ckt "  with the room that is up" grep -qE '^  solo +[^ ]+ +yes$' out
    ckt "  and the one that is not" grep -qE '^  pair +[^ ]+ +no$' out

    capsule=${lib.getExe withRoomUp} run ssh
    ck "  while an unnamed ssh still means a slot" 1 "$rc"
    ckt "  and refuses as one" saw "no capsule is up, so an unnamed 'ssh'"

    # ------------------------------------------------------------ the doors
    # The human's door, through the real program and the real ssh: `-G` after
    # the destination prints the configuration it resolved and connects to
    # nothing, so this is the argv a room's ssh runs (DEC-047).
    capsule=${lib.getExe withRoomUp} run solo ssh ann -- -G
    ck "a room's ssh door resolves" 0 "$rc"
    ckt "  accepting a new key and refusing a changed one" saw "stricthostkeychecking accept-new"
    ckt "  filed under the room's alias" saw "hostkeyalias room-solo"
    ckt "  in the room's own file" saw "userknownhostsfile $CASE_STATE/room/solo/known_hosts"
    ckt "  through the record's socket" grep -qE '^proxycommand .*room-up/solo/ssh\.sock' out
    ckt "  and never the slot relaxation" unsaw "userknownhostsfile /dev/null"
    ckt "  nor a batch probe's" unsaw "batchmode yes"

    # The probe's door, by text and only by text — the weakest kind of pin —
    # since its ssh runs only after `sudo systemctl start` (DEC-050).
    ckt "the room's probe door is still the slot's probe" grep -qF 'probe) doorVia probe "$1"' "$capsule"
    ckt "  which keeps the relaxation" grep -qE "^ +probe\) ssh_argv=\(.*StrictHostKeyChecking=no.*UserKnownHostsFile=/dev/null.*BatchMode=yes" "$capsule"

    # ------------------------------------------------------------ collide
    # A verdict carries no message, so the reason is read off the render.
    : > out
    ckt "a room named for a verb does not evaluate" test ${lib.boolToString (!collides.success)} = true
    ckt "  and says it is a room that collided" \
      test ${quote colliding.reasons.verbs or ""} = ${quote "host/cli.nix: 'ssh' is both a room and a verb (or `all`), so `capsule ssh …` cannot be read either way"}
    ckt "  while the fixture's own rooms do not collide" test ${quote (cli.reasons.verbs or "missing")} = ""

    [ "$fail" = 0 ] || exit 1
    cp "$log" $out
    cat $out
  ''
