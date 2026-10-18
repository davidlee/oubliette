# The guard's verdicts, asserted at build time against a stubbed kernel.
#
# This is the third kind of check here and it earns its own kind: a `probe/`
# needs root and asserts against the real host, `hostModuleUnits` evaluates
# what the module *says*, and this runs a real host-side program's logic with
# its tools replaced. The guard is the thing it is for — its branches decide
# whether a broken slot degrades or denies the fleet, and reaching them on a
# live host means unnaming a namespace under a running guest.
#
# It is not a second implementation of the guard: `host/guard.nix` takes
# `tools` as an argument, and this builds that same text with stubs where
# iproute2 and systemd would be. `writeShellApplication` prepends
# `runtimeInputs` to `PATH`, which is exactly why the seam has to be an
# argument — a stub directory prepended by a test would lose to the real
# `ip` every time.
#
# The stubs live here rather than beside the guard because this is their only
# caller: a substitute for a kernel is the suite's, not the program's.
{
  pkgs,
  lib,
  net,
  capsules,
  # rooms.nix, unapplied: the room in the fixture below is built by the same
  # constructor a host's are, so its namespace and socket are a room's rather
  # than a spelling of one.
  rooms,
}: let
  guardStubs = let
    # The kernel and systemd, as far as the guard can tell. Each reads the
    # case's environment: `NS_FILE` names the namespaces that exist (a file,
    # not a variable, because `sleep` rewrites it to make a slot arrive or
    # leave mid-hold), `VMS` is `slot:pid` per *active* unit, and `PIDS_IN` is
    # `ns:pid` — where those pids actually are, which is the only way the two
    # can disagree.
    ip = pkgs.writeShellScriptBin "ip" ''
      case "$1 $2" in
        "netns list") for n in $(cat "$NS_FILE"); do echo "$n (id: 0)"; done ;;
        "netns pids")
          grep -qw "$3" "$NS_FILE" || exit 1
          for p in ''${PIDS_IN:-}; do
            case "$p" in "$3":*) echo "''${p#*:}" ;; esac
          done ;;
        "netns exec")
          shift 3
          case "$1" in
            *sysctl) echo "''${FORWARD:-0}" ;;
            *nft) printf '%s\n' "$NFT_RULES" ;;
          esac ;;
      esac
    '';
    systemctl = pkgs.writeShellScriptBin "systemctl" ''
      unit=''${*: -1}
      slot=''${unit#microvm@}
      slot=''${slot%.service}
      pid=""
      for v in ''${VMS:-}; do
        case "$v" in "$slot":*) pid=''${v#*:} ;; esac
      done
      case "$1" in
        is-active) [ -n "$pid" ] ;;
        show) echo "$pid" ;;
      esac
    '';
    # Holds the loop `LOOPS` times instead of forever, and applies `NS_THEN` on
    # the first cycle — which is how a slot arriving late is tested at all.
    sleep = pkgs.writeShellScriptBin "sleep" ''
      n=$(cat count 2>/dev/null || echo 0)
      [ "$n" -lt "''${LOOPS:-0}" ] || exit 1
      echo $((n + 1)) >count
      [ -z "''${NS_THEN:-}" ] || echo "$NS_THEN" >"$NS_FILE"
    '';
  in [ip systemctl sleep pkgs.gnugrep pkgs.coreutils];

  # Two slots and a room, and not this host's. The cases below assert a property
  # that holds at any fleet size — one absent slot is a smaller fleet, one
  # present-and-wrong slot is a breach — so following `capsules.nix` would
  # make widening the pool an edit to eleven expected strings and would test
  # today's declaration rather than the guard. Everything else is the cases
  # fabric (`casesCapsules`, mkfleet.nix): the capsules function applied to a
  # declaration that is no host's, so the aggregator, the uplink net and the
  # drop pattern the cases grep for are oubliette's constructions over
  # fixture addressing. Only `instances` is substituted here.
  fixture =
    capsules
    // {
      instances = capsules.instancesOf {
        a = {index = 0;};
        b = {index = 1;};
      };
    };
  # One room, `room-lounge`: a guest with a namespace and no uplink, which the
  # guard holds exactly as it holds a slot (`DEC-039`). So every count below is
  # out of three, the guests, and not out of the two slots.
  roomFixture =
    (rooms {inherit lib;} {
      rooms.lounge = {
        users.ada = {
          uid = 1001;
          keys = ["ssh-ed25519 AAAA fixture"];
        };
        sizes = {};
      };
      # This suite's rooms declare no repos, so it declares no targets, policies or
      # vocabulary for them — passed, never defaulted (POL-003).
      targets = {byName = {};};
      policies = {everything = [];};
      fragmentNames = [];
      slotNames = lib.attrNames fixture.instances;
    }).instances;
  stubbed = import ./guard.nix {
    inherit pkgs lib net;
    capsules = fixture;
    guests = lib.attrValues fixture.instances ++ lib.attrValues roomFixture;
    netns = import ./netns.nix {
      inherit pkgs lib net;
      capsules = fixture;
    };
    tools = guardStubs;
  };

  # Both limbs, and the count. `want` is the exit status: 0 is a verdict of
  # intact — the stubbed `sleep` ends the hold loop, so a passing guard
  # returns rather than running forever — and 1 is a refusal. `expect` is a
  # fixed string that has to appear, because a refusal for the wrong reason
  # is not the same check.
  cases = [
    # --- limb one: declared ∩ present ---
    {
      name = "both present, nothing running";
      ns = "cap-egress cap-a cap-b";
      want = 0;
      expect = "2 of 3 declared";
    }
    {
      # The whole point of item 30: one slot short is a smaller fleet, not a
      # dead one.
      name = "a slot that never came up degrades";
      ns = "cap-egress cap-a";
      want = 0;
      expect = "1 of 3 declared";
    }
    {
      name = "no slot present at all";
      ns = "cap-egress";
      want = 0;
      expect = "0 of 3 declared";
    }
    {
      # One per host, and every capsule leaves through it.
      name = "the aggregator is not degradable";
      ns = "cap-a cap-b";
      want = 1;
      expect = "namespace cap-egress is gone";
    }
    {
      # Present and wrong is a breach, and absence is not breakage.
      name = "a present namespace that forwards";
      ns = "cap-egress cap-a cap-b";
      env = {FORWARD = "1";};
      want = 1;
      expect = "the guest's confinement is gone";
    }
    # --- limb two: a running VMM is inside its own namespace ---
    {
      name = "a running slot beside one that never started";
      ns = "cap-egress cap-a";
      env = {
        VMS = "a:4242";
        PIDS_IN = "cap-a:4242";
      };
      want = 0;
      expect = "1 of 3 declared";
    }
    {
      # The hole limb one would open on its own: `ip netns del` unnames a
      # namespace and the guest keeps running inside it.
      name = "a live guest in a namespace that has been unnamed";
      ns = "cap-egress cap-b";
      env = {
        VMS = "a:4242";
        PIDS_IN = "cap-a:4242";
      };
      want = 1;
      expect = "is not a named namespace";
    }
    {
      # A union-membership test calls this healthy: one slot's guest behind
      # another slot's perimeter.
      name = "a VMM bound to the wrong namespace";
      ns = "cap-egress cap-a cap-b";
      env = {
        VMS = "a:4242";
        PIDS_IN = "cap-b:4242";
      };
      want = 1;
      expect = "is not in cap-a";
    }
    {
      name = "an active unit with no MainPID";
      ns = "cap-egress cap-a";
      env = {VMS = "a:0";};
      want = 1;
      expect = "no MainPID";
    }
    # --- a room is a guest: both limbs, and the count ---
    {
      name = "a declared room's namespace is audited";
      ns = "cap-egress room-lounge";
      want = 0;
      expect = "1 of 3 declared";
    }
    {
      # The stub's forwarding switch is every namespace's, and no slot's is
      # present here, so only the room's can be the one refused.
      name = "a room namespace that forwards";
      ns = "cap-egress room-lounge";
      env = {FORWARD = "1";};
      want = 1;
      expect = "the guest's confinement is gone";
    }
    {
      # Limb two over a room: its VMM is running in a slot's namespace.
      name = "a running room VMM outside its namespace";
      ns = "cap-egress cap-a room-lounge";
      env = {
        VMS = "lounge:4242";
        PIDS_IN = "cap-a:4242";
      };
      want = 1;
      expect = "is not in room-lounge";
    }
    # --- the count is part of the safety property, so it has to move ---
    {
      name = "a slot arriving during the hold is reported";
      ns = "cap-egress cap-a";
      env = {
        LOOPS = "2";
        NS_THEN = "cap-egress cap-a cap-b";
      };
      want = 0;
      expect = "2 of 3 declared";
    }
    {
      name = "a slot leaving during the hold is reported";
      ns = "cap-egress cap-a cap-b";
      env = {
        LOOPS = "2";
        NS_THEN = "cap-egress cap-a";
      };
      want = 0;
      expect = "1 of 3 declared";
    }
  ];

  # Every case runs, and a red one is recorded rather than ending the suite: a
  # mutation is only legible if it shows *which* cases it turned red, and
  # stopping at the first shows one of them.
  runCase = i: c: ''
    mkdir -p case-${toString i} && cd case-${toString i}
    printf '%s\n' ${lib.escapeShellArg c.ns} >ns
    rc=0
    env NS_FILE="$PWD/ns" \
      ${lib.concatStringsSep " " (lib.mapAttrsToList
        (k: v: "${k}=${lib.escapeShellArg v}") (c.env or {}))} \
      ${lib.getExe stubbed} >out 2>&1 || rc=$?
    if [ "$rc" != ${toString c.want} ]; then
      fail ${lib.escapeShellArg c.name} "exit $rc, wanted ${toString c.want}"
    elif ! grep -qF -- ${lib.escapeShellArg c.expect} out; then
      fail ${lib.escapeShellArg c.name} ${lib.escapeShellArg "nothing matching ${c.expect}"}
    else
      echo "ok (${toString c.want}) ${c.name}" >>"$log"
    fi
    cd ..
  '';
in
  pkgs.runCommand "capsule-guard-cases" {} ''
    log=$PWD/log
    : >"$log"
    failed=0
    fail() {
      echo "FAIL $1: $2" >&2
      sed 's/^/    /' out >&2
      failed=1
    }
    # nft's rendering, as the guard's `ns_rule` greps it. Every case has an
    # intact ruleset: a missing rule is `ns_rule`'s own test and not this
    # program's.
    export NFT_RULES='iifname "${capsules.egress.linkPattern}" oifname "${capsules.egress.linkPattern}" drop
    ip saddr ${capsules.uplinkNet}
    iifname "${net.tap}" ip daddr != ${net.host} drop'
    ${lib.concatStrings (lib.imap0 runCase cases)}
    [ "$failed" = 0 ] || exit 1
    cp "$log" $out
    cat $out
  ''
