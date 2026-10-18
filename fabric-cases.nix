# Which names a probe's fabric may not borrow — NOTES item 38, SL-005 sec-2.
#
# The subject is a *library*, not a program: `fabric.nix` is the function its one
# caller (mkfleet.nix) applies to the live declaration and the probe fabric, and
# this suite applies the same function to records built by the real constructors
# (`capsules.nix`, `rooms.nix`) over declarations that are no host's.
#
# **Handed a fixture, and it says so**: the slot `s1`, the room `lounge`, the
# addressing and the probe fabric below are invented, and disjoint from each
# other and from every host's.
#
# `fabric.nix` throws nothing: a borrow is a `reason`, a string mkfleet.nix
# throws when the probe prelude is forced. So every case reads `borrowed` and
# `reason` as values, and there is no `tryEval`. The room branch's hazard — a
# room has no `uplink`, so dereferencing one is "expected a set but found
# null" — is a type error, which `tryEval` cannot catch, so it aborts this
# suite's eval instead of reporting. `borrowed` compares every live name with
# the fabric's values, so every case forces every element and none can pass
# with that dereference left unevaluated.
#
# What it does not prove (STD-001): that mkFleet asserts on `reason` (its
# wiring line), or that any unit, namespace or link exists. It is the
# function's verdicts over fixtures, and nothing more.
{
  pkgs,
  lib,
  # `import ./fabric.nix`, unapplied: the function mkfleet.nix calls.
  fabric,
  # `import ./capsules.nix` and `import ./rooms.nix`, unapplied: the
  # constructors whose records mkfleet.nix hands to `fabric`.
  capsules,
  rooms,
}: let
  apply = fabric {inherit lib;};

  slots = capsules {policies.everything = ["open"];} {
    slots.s1 = {
      index = 0;
      policy = "open";
      policies = ["open"];
    };
    addressing = {
      uplinkNet = "10.130.0.0/16";
      egressAddr = "10.131.0.2";
      egressPeerAddr = "10.131.0.1";
    };
    volumeReserve = 0;
  };

  key = "ssh-ed25519 AAAA fixture";
  lounge =
    (rooms {inherit lib;} {
      rooms.lounge = {
        users = {
          ada = [key];
          bob = [key];
        };
        sizes = {};
      };
      slotNames = ["s1"];
    }).instances;

  probe = rec {
    ns = "fx-egress";
    peerNs = "fx-peer";
    dev = "fx-up";
    peer = "fx-rt";
    addr = "10.141.0.2";
    peerAddr = "10.141.0.1";
    netBase = "10.140";
    net = "${netBase}.0.0/16";
    uplinkNet = "10.141.0.0/30";
    outPrefix = "fx-out";
    wanPrefix = "fx-wan";
  };

  # The probe fabric with its namespace renamed: the only variable per case.
  nsOf = ns:
    apply {
      capsules = slots;
      rooms = lounge;
      fabric = probe // {inherit ns;};
    };

  clean = nsOf probe.ns;
  room = nsOf "room-lounge";
  slot = nsOf "cap-s1";
  noRooms = apply {
    capsules = slots;
    rooms = {};
    fabric = probe;
  };

  # A value's shell form: lists space-joined, null as empty.
  shown = v:
    lib.escapeShellArg (
      if v == null
      then ""
      else toString v
    );
in
  pkgs.runCommand "fabric-cases" {} ''
    fail=0
    log=$out
    : >"$log"
    ck() {
      if [ "$2" = "$3" ]; then echo "ok   $1" >>"$log"
      else echo "FAIL $1: got '$3', wanted '$2'" >&2; fail=1; fi
    }
    has() {
      case "$3" in
        *"$2"*) echo "ok   $1" >>"$log" ;;
        *) echo "FAIL $1: '$3' does not mention '$2'" >&2; fail=1 ;;
      esac
    }

    # 1. A fabric disjoint from the live declaration borrows nothing.
    ck "a disjoint fabric borrows nothing" "" ${shown clean.borrowed}
    ck "  and has no reason to refuse" "" ${shown clean.reason}

    # 2. A fabric naming a room's namespace borrows it, and says so.
    ck "a fabric named for a room's namespace borrows it" room-lounge ${shown room.borrowed}
    has "  naming it" "'room-lounge'" ${shown room.reason}
    has "  and why" "NOTES item 38" ${shown room.reason}

    # 3. The control: a slot's namespace is refused as it always was, so a red
    # in 2 is about rooms and not about the check.
    # (A slot's namespace and its aggregator-side link share the name, so it is
    # borrowed twice: `has`, not `ck`.)
    has "a fabric named for a slot's namespace borrows it" cap-s1 ${shown slot.borrowed}
    has "  naming it" "'cap-s1'" ${shown slot.reason}

    # 4. A room's namespace is live, and it is the only thing a room adds.
    ck "a room's namespace is a live name" true ${lib.boolToString (builtins.elem "room-lounge" clean.liveNames)}
    ck "  and a room adds exactly its namespace" true \
      ${lib.boolToString (clean.liveNames == noRooms.liveNames ++ ["room-lounge"])}

    cat "$log"
    exit "$fail"
  ''
