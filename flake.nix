{
  description = "microvm.nix spike — firecracker capsule for agent confinement";

  # microvm.nix's own cache; saves compiling hypervisors + guest kernel.
  # Only honoured if you are in nix.settings.trusted-users, else nix asks.
  nixConfig = {
    extra-substituters = ["https://microvm.cachix.org"];
    extra-trusted-public-keys = ["microvm.cachix.org-1:oXnBc6hRE3eX5rSYdRyMYXnfzcCxC7yKPTbZXALsqys="];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    microvm = {
      url = "github:microvm-nix/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # The repo this capsule confines, as a flake: the source of the guest's tool
    # set (targets/doctrine.nix's `toolsPackage`), one list shared with that repo's own
    # devshell so the guest cannot drift from it. Everything else about the
    # target is described in ./targets/doctrine.nix — this must name the same repo as
    # `path` there, and nix cannot check that for you (NOTES item 16). An input
    # url has to be a literal, hence the duplication; `--override-input target
    # path:/…` switches it for one build.
    #
    # A published url, not a checkout on one desktop (ISS-015): the lock is
    # committed, so whatever it pins is what a stranger's clone has to fetch. A
    # doctrine change therefore needs a *push* before `nix flake update target`
    # sees it. To try an unpushed one, override a build — never `nix flake lock`
    # with an override, which writes the local path back into the lock.
    target.url = "github:davidlee/doctrine/edge";

    # goad-walk's tool set (targets/goad-walk.nix): goad's binaries plus ruby and
    # jq, and not goad's source. Same rules as `target` above. Deliberately no
    # `follows`: goad-walk has no nixpkgs input of its own (it builds with goad's),
    # and like `target` it keeps its own pin so the guest cannot drift from the
    # tool set's own devshell.
    goad-walk.url = "github:davidlee/goad-walk";

    doctrine.url = "github:davidlee/doctrine/edge";

    # The one tool source this host registers beyond nixpkgs and the target:
    # where the agent CLIs come from (`fragments.nix`'s `agents`). A fragment is
    # code in the guest closure, so its source is a flake input of *this* repo,
    # pinned in a lock this host owns and updated only by a deliberate
    # `nix flake update` (NOTES item 26, docs/contract-flavour.md). The literal
    # is per *source* rather than per project, which is why this list stays
    # short as the fleet grows.
    #
    # Deliberately not `follows = "nixpkgs"`: these are prebuilt in numtide's
    # cache against their own pin, and re-pointing nixpkgs rebuilds them here
    # for no gain.
    llm-agents.url = "github:numtide/llm-agents.nix";
  };

  # This host's fleet: oubliette's builder (mkfleet.nix), applied to this
  # host's declarations, one argument per owner (design sec-10). The builder is
  # bound once, so the fleet below and `lib.mkFleet` are the same function.
  outputs = inputs: let
    inherit (inputs.nixpkgs) lib;
    mkFleet = import ./mkfleet.nix {inherit (inputs) nixpkgs microvm doctrine;};
    policies = import ./policies.nix;
  in
    mkFleet {
      # The repos this host confines, each paired with its own flake: the hand
      # list. A flake input's url must be a literal, so a target's file cannot
      # carry its flake; pairing them here, beside the inputs, means the targets
      # and their flakes cannot name different sets, so there is nothing to
      # refuse (fleet.nix). `inputs.target` keeps its name: ~/flakes follows it.
      targets = {
        doctrine = {
          decl = import ./targets/doctrine.nix;
          flake = inputs.target;
        };
        goad-walk = {
          decl = import ./targets/goad-walk.nix;
          flake = inputs.goad-walk;
        };
      };
      fleet = import ./host-capsules.nix {inherit policies;};
      inherit policies;
      net = import ./net.nix;
      flavour = {
        # The host operator's half of every guest's tool set: which fragments
        # of `fragments.nix`'s vocabulary this fleet composes into its image.
        # One list for the fleet — so every slot arrives at the same
        # composition and stays one image (NOTES item 21), and a per-slot list
        # is a field this value moves into rather than a mechanism anything has
        # to grow (Plan D D7, docs/contract-flavour.md).
        #
        # The floor is *not* here: that is the target's, and `vm/capsule.nix`
        # reads it out of the target's file (targets/). Two owners, two files,
        # one composition.
        extras = ["agents" "dev-facilities"];
        sources = {inherit (inputs) llm-agents;};
      };
      access = {
        adminKeys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAgvwY62NVQgQkVkp5YbOKv26avHLypGNPdrOqKFtwjl david@Sleipnir"
        ];
        # The public half of this host's capsule stop key (what it is for:
        # vm/capsule.nix, where root's keys are set). Required: a missing one
        # fails the eval rather than leaving a guest that can only be
        # power-cut.
        stopKey =
          if builtins.pathExists ./vm/stop-key.pub
          then lib.removeSuffix "\n" (builtins.readFile ./vm/stop-key.pub)
          else throw "vm/stop-key.pub is missing: generate this host's capsule stop key and commit its public half (README, 'Host requirements').";
        injections = import ./setup.nix;
      };
      probe = {
        # The one real target the probes are about, named once. A probe is
        # evidence about the real capsule on this host, so it may know this
        # host's target — `probe/netns-boot.sh` is the standing exception.
        # `.#capsule` is this target's image.
        target = "doctrine";
        # A separate /16 and /30 is what keeps every per-index address off the
        # live fabric without asserting each one — the harness derives
        # `<base>.<i>.{1,2}` the same way `capsules.nix` does. mkFleet refuses
        # any value here that the live fabric also uses (NOTES item 38).
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
      fleetPath = "/home/david/dev/microvm-spike";
    }
    // {
      # The builder and the two functions it applies, unapplied, for a flake
      # that declares its own fleet.
      lib = {
        inherit mkFleet;
        capsules = import ./capsules.nix;
        targets = import ./targets;
      };
    };
}
