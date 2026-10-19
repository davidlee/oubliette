{
  description = "a capsule fleet: this host's declarations, handed to oubliette's lib.mkFleet";

  # A consumer of oubliette, created by `nix flake init -t github:davidlee/oubliette`.
  # Every file here is a declaration a host owns, commented as the reference for
  # its fields; README.md is the first steps. Comments cite oubliette's tree
  # (`NOTES item N`, `docs/...`, `vm/capsule.nix`, `mkfleet.nix`): those
  # citations resolve in github.com/davidlee/oubliette, not here.

  # microvm.nix's own cache; saves compiling hypervisors + guest kernel.
  # Only honoured if you are in nix.settings.trusted-users, else nix asks.
  nixConfig = {
    extra-substituters = ["https://microvm.cachix.org"];
    extra-trusted-public-keys = ["microvm.cachix.org-1:oXnBc6hRE3eX5rSYdRyMYXnfzcCxC7yKPTbZXALsqys="];
  };

  inputs = {
    # This fleet's own nixpkgs, so a host config can `follows` it into the
    # module.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # The builder. Its nixpkgs is this one.
    oubliette = {
      url = "github:davidlee/oubliette";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # The repo targets/doctrine.nix confines, as a flake: the source of the
    # guest's tool set (that file's `toolsPackage`). Must name the same repo as
    # `path` in targets/doctrine.nix, and nothing checks that they agree.
    # A published url, since the lock is committed: never `nix flake lock` with
    # a git+file override, which writes a local path into the lock.
    doctrine.url = "github:davidlee/doctrine/edge";

    # Agent CLIs (oubliette's `fragments.nix`, the `agents` fragment) come from
    # oubliette's pin, so this lock and oubliette's cannot disagree about them.
    llm-agents.follows = "oubliette/llm-agents";
  };

  # This host's fleet: oubliette's builder applied to this host's declarations,
  # one argument per owner (mkfleet.nix's header says what each one is). All
  # nine are required: omit one and the eval fails naming it.
  outputs = inputs: let
    inherit (inputs.nixpkgs) lib;
    policies = import ./policies.nix;
  in
    inputs.oubliette.lib.mkFleet {
      # The repos this host confines, each paired with its own flake: the hand
      # list, and the only one. A flake input's url must be a literal, so a
      # target's file cannot carry its flake; pairing them here, beside the
      # inputs, means the targets and their flakes cannot name different sets.
      # A second target is a second input, a second file in targets/, and a
      # second entry here.
      targets = {
        doctrine = {
          decl = import ./targets/doctrine.nix;
          flake = inputs.doctrine;
        };
      };

      # Which slots exist and the fabric they sit on (capsules.nix).
      fleet = import ./capsules.nix {inherit policies;};

      # Rooms: guests that are not slots, each reached only through its
      # host-local door. `{}` declares none. Each user declares its uid, which
      # owns its files on the room's volume and so must never change.
      #
      # A room may also hold repos: `repos`, `policy` and `sizes.work`, all
      # three or none (DEC-048). `repos.targets` are names in `targets` above;
      # each becomes one clone at that target's `guestPath`, on a second volume
      # at `/work` (`sizes.work` MiB, sparse), `git init`ed on the unborn `work`
      # branch and owned by `repos.user`, one of the room's declared users. A
      # repo's tool set is its target's `toolsPackage`, reached only through
      # `session <repo> -- <cmd>` in the room, never on its base PATH. Every
      # room has a base: the floor `git bash coreutils-full which` plus its
      # `extras` (names from the fragment vocabulary), on a login's PATH and
      # behind a repo's tools in `session` (DEC-052). `policy`
      # names one in policies.nix; it bounds and permits what
      # `capsule assistant collect <repo> <branch>` fetches back, into
      # /var/lib/capsule/collect/assistant/<repo>.git, and its allowlist is
      # inert, since a room has no uplink. `capsule assistant push <repo>
      # <branch>` sends a branch of the target's `path` checkout. A room without
      # repos needs none of this. For example:
      #
      #   rooms.assistant = {
      #     users.agent = {
      #       uid = 1001;
      #       keys = ["ssh-ed25519 AAAA... you@host"];
      #     };
      #     repos = {
      #       user = "agent";
      #       targets = ["doctrine"];
      #     };
      #     policy = "build";
      #     extras = ["search"];
      #     sizes = {
      #       vcpu = 2;
      #       mem = 4096;
      #       volume = 40960;
      #       work = 32768;
      #     };
      #   };
      rooms = {};

      # What a slot may talk to and what may come back out of it (policies.nix).
      inherit policies;

      # The host<->guest link, read by the guest and the host module alike
      # (net.nix).
      net = import ./net.nix;

      flavour = {
        # The host operator's half of every guest's tool set: which fragments
        # of oubliette's `fragments.nix` vocabulary this fleet composes into its
        # image. One list for the fleet, so every slot arrives at the same
        # composition and stays one image per target (NOTES item 21,
        # docs/contract-flavour.md).
        #
        # The floor is *not* here: that is the target's, read out of its file
        # (targets/doctrine.nix, `toolsPackage`). Two owners, two files, one
        # composition.
        extras = ["agents" "dev-facilities"];
        # The flake inputs those fragments come from, pinned in this lock.
        sources = {inherit (inputs) llm-agents;};
      };

      access = {
        # Public keys that may log into every guest as root, over ssh from this
        # host. Empty is a working value and means nobody can: put your own
        # `ssh-ed25519 ... you@host` line here to administer a guest.
        adminKeys = [];

        # The public half of this host's capsule stop key: what a
        # `microvm@<name>` unit presents to ask its guest to reboot, the only
        # clean stop firecracker leaves (vm/capsule.nix, NOTES item 11).
        # Required: a missing file fails the eval rather than leaving a guest
        # that can only be power-cut. The file this template ships is a
        # placeholder nobody holds the private half of, and `just check`
        # refuses it until you replace it (README.md).
        stopKey =
          if builtins.pathExists ./keys/stop-key.pub
          then lib.removeSuffix "\n" (builtins.readFile ./keys/stop-key.pub)
          else throw "keys/stop-key.pub is missing: generate this host's capsule stop key and commit its public half (README.md).";

        # What a fresh capsule is handed before you work in it (setup.nix).
        injections = import ./setup.nix;
      };

      probe = {
        # The one real target the probes are about, named once. A probe is
        # evidence about the real capsule on this host, so it may know this
        # host's target. `.#capsule` is this target's image.
        target = "doctrine";
        # The names and addressing a probe's egress fabric is built from. A
        # separate /16 and /30 is what keeps every per-index address off the
        # live fabric (capsules.nix) without asserting each one. mkFleet
        # refuses any value here that the live fabric also uses (NOTES item 38).
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

      # Where this checkout lives on the host, as an absolute path: edit it if
      # you cloned somewhere else. Threaded to the host module and read by
      # nothing yet (RV-012 F-11); it is where the module's policy allowlists
      # (`policies.dir` under it) are meant to be found.
      fleetPath = "/srv/fleet";
    };
}
