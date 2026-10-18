# `capsule <room> <verb>` — the four verbs a room takes and the refusal every
# other one meets (SL-005 design sec-7, `DEC-041`), and the eval refusal of a
# room whose name is a verb.
#
# The third kind of check (CLAUDE.md), over `capsule`. **Handed a fixture**, for
# `policyCases`' reason — a pool and rooms that are nobody's are the subject —
# so it renders its own front end, with two slots and two rooms built by the
# real constructors (`capsules.instancesOf`, rooms.nix), and a second render
# with a room named `ssh` that must not evaluate. Everything else is the shipped
# values, threaded from the call site.
#
# What it pins is everything **upstream of the first `ssh` or `systemctl`** a
# room runs, since `pkgs.openssh` and `pkgs.systemd` are in the front end's
# `runtimeInputs` and nothing in a sandbox can stub them (RV-014 F-6): that a
# room's name is consumed as a name and not a verb, that a slot's verb on a room
# refuses with exit 2 and its reason, that a two-user room's `ssh` with no user
# refuses before any socket is looked at, that the socket a room's door uses is
# its record's and not the slot convention's (so `doorsOpen` never counts one),
# that status lists rooms after the slot table, and the collide verdict and its
# message.
#
# What it does **not** pin: the argv of a room's `ssh` (`HostKeyAlias`, the
# proxy, `<user>@guest`), its `start` (`systemctl start`, readiness as root) or
# its `stop` — those are the live run's (SL-005 PHASE-09).
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
  # only the user names are read here.
  roomsOf = decl:
    (rooms {inherit lib;} {
      rooms =
        lib.mapAttrs (_: users: {
          users = builtins.listToAttrs (lib.imap1 (i: u: {
              name = u;
              value = {
                uid = 1000 + i;
                keys = ["ssh-ed25519 AAAA fixture-${u}"];
              };
            })
            users);
          sizes = {
            vcpu = 1;
            mem = 1024;
            volume = 1024;
          };
        })
        decl;
      # This suite's rooms declare no repos, so it declares no targets or policies
      # for them — passed, never defaulted (POL-003).
      targets = {byName = {};};
      policies = {everything = [];};
      slotNames = builtins.attrNames fixture.instances;
    }).instances;
  renderRecords = records:
    import ./cli.nix {
      inherit pkgs lib net policies guestSsh;
      inherit observe observeFragment programVerbs profileVerbs stateRefPrefix volumeRootHelper;
      capsules = fixture;
      moduleState = ''"$CASE_STATE"'';
      rooms = records;
    };
  render = roomDecl: renderRecords (roomsOf roomDecl);
  cli = render {
    solo = ["ann"];
    pair = ["ada" "bob"];
  };
  # The same rooms, with `solo`'s socket somewhere a build can bind one: a
  # relative path, read against the directory the suite runs in, since the
  # front end quotes it and a variable would not expand. Only here — the main
  # render pins the record's real path.
  withRoomUp = renderRecords (lib.recursiveUpdate (roomsOf {
    solo = ["ann"];
    pair = ["ada" "bob"];
  }) {solo.socket = "room-up/solo/ssh.sock";});
  # A room named for a verb: `capsule ssh …` could no longer be read either way.
  colliding = render {ssh = ["ann"];};
  collides = builtins.tryEval (builtins.deepSeq colliding.drvPath colliding.drvPath);
  quote = s: lib.escapeShellArg (toString s);
in
  pkgs.runCommand "capsule-room-verbs-cases" {nativeBuildInputs = [pkgs.python3];} ''
    export CASE_STATE=$PWD/state
    mkdir -p "$CASE_STATE"
    capsule=${lib.getExe cli}
    unset CAPSULE_NAME

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
    refusal() { printf "capsule: '%s' is a room; rooms take ssh, start, stop (status lists them)" "$1"; }

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

    # ------------------------------------------------------------ status
    run all status
    ck "status answers with rooms declared" 0 "$rc"
    ckt "  listing every room" grep -qE '^  (solo|pair) ' out
    ckt "  both of them" test "$(grep -cE '^  (solo|pair) +[^ ]+ +no$' out)" = 2
    ckt "  after the slot table" \
      test "$(grep -n '^capsule ' out | cut -d: -f1)" -lt "$(grep -n '^rooms:' out | cut -d: -f1)"

    run --help
    ckt "usage names the rooms" saw "rooms:     pair solo"

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
