# The declarations oubliette builds itself over: the nine `mkFleet` arguments,
# with values that are nobody's (POL-002, NOTES item 51). Not this host's and
# not any target's. A real host's declarations live in its own consumer flake,
# which calls the same `lib.mkFleet` (SL-004 design sec-3).
#
# Every optional target field is absent, spelled as its absent value
# (docs/contract-target.md, "Configuration"), so the build exercises each
# absent path. Two slots, because two is what makes "one image per target, N
# slots" something a build can show. Every address is off the live fabric
# (10.100/10.101) and off the probe fabric (10.110/10.111).
#
# `llm-agents` is the one flake input the fixture needs: the source of the
# `agents` fragment it composes, so the composition path is exercised too.
{llm-agents}: let
  # Two policies, named `build` and `sealed`: mkfleet.nix's probe prelude reads
  # both by name (SL-004 PHASE-07 F-1). `dir` is relative to CAPSULE_ROOT.
  policies = rec {
    dir = "fixture/perimeter";
    policies = {
      build = {
        allowlist = "egress-allow.txt";
        collectMaxPackBytes = 1048576;
        mayCollect = true;
      };
      sealed = {
        allowlist = "egress-none.txt";
        collectMaxPackBytes = 1048576;
        mayCollect = false;
      };
    };
    everything = builtins.attrNames policies;
  };

  slot = index: profile: {
    inherit index profile;
    policy = "build";
    policies = policies.everything;
  };
in {
  targets.fixture = {
    # Each required field at its minimum, each optional one absent.
    decl = {
      path = "/nonexistent/fixture";
      toolsPackage = null;
      extraTools = [];
      caches = {};
      guestConfig = {};
      commands = "";
      baseline = null;
      refresh = null;
      sizes = {
        vcpu = 1;
        mem = 1024;
        volume = 1024;
      };
    };
    flake = import ./stub-flake.nix;
  };

  fleet = {
    slots = {
      alpha = slot 0 "fixture";
      beta = slot 1 "fixture";
    };
    addressing = {
      uplinkNet = "10.120.0.0/16";
      egressAddr = "10.121.0.2";
      egressPeerAddr = "10.121.0.1";
    };
    volumeReserve = 20 * 1024 * 1024 * 1024;
  };

  # Two rooms, nobody's: `lounge` is Plan E's shape (several people on one
  # box) and `assistant` Plan F's door (one agent). No addressing — a room has
  # no uplink — and off the probe fabric by its `room-` prefix. The keys are
  # strings nobody holds.
  rooms = let
    sizes = {
      vcpu = 1;
      mem = 1024;
      volume = 1024;
    };
  in {
    lounge = {
      users = {
        ada = {
          uid = 1001;
          keys = ["ssh-ed25519 AAAA fixture-ada"];
        };
        bob = {
          uid = 1002;
          keys = ["ssh-ed25519 AAAA fixture-bob"];
        };
      };
      inherit sizes;
    };
    assistant = {
      users.agent = {
        uid = 1001;
        keys = ["ssh-ed25519 AAAA fixture-agent"];
      };
      inherit sizes;
    };
  };

  inherit policies;

  # The host<->guest link. Platform shape rather than a host's choice: every
  # capsule's link is identical inside its own namespace.
  net = {
    tap = "vm-capsule";
    host = "10.99.0.1";
    guest = "10.99.0.2";
    prefix = 30;
    mac = "02:00:00:00:99:02";
    proxyPort = 3128;
  };

  flavour = {
    extras = ["agents" "dev-facilities"];
    sources = {inherit llm-agents;};
  };

  access = {
    # Nobody may log in as root.
    adminKeys = [];
    # A real ed25519 public key whose private half was discarded at generation,
    # so the stop-key unit parses a key that no one holds.
    stopKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICoofzFAInVftyrO13VpKn0kSQTA2I0fVmC8xCZRM4nw fixture-stop-key";
    # One injection, outside `$HOME`, so the guest's scrub list is not vacuous
    # (vm/capsule.nix, vm/reset-home-cases.nix).
    injections = {volumePath}: [
      {
        name = "fixture-env";
        dest = "${volumePath}/.env";
        produce = "printf 'FIXTURE=1\\n'";
        tools = [];
        optional = true;
      }
    ];
  };

  probe = {
    target = "fixture";
    # mkFleet refuses any value here that the fixture's fleet also uses (NOTES
    # item 38).
    fabric = rec {
      ns = "probe-egress";
      peerNs = "probe-peer";
      dev = "pr-up";
      peer = "pr-rt";
      addr = "10.111.0.2";
      peerAddr = "10.111.0.1";
      netBase = "10.110";
      net = "${netBase}.0.0/16";
      uplinkNet = "10.111.0.0/30";
      outPrefix = "pr-out";
      wanPrefix = "pr-wan";
    };
  };

  fleetPath = "/nonexistent/fixture-fleet";
}
