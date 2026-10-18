{
  description = "oubliette — a builder for fleets of firecracker capsules that confine coding agents";

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

    # The governance CLI the devshell carries (mkfleet.nix closes over it). Not a
    # target: oubliette confines no repo of its own, and a host's targets are
    # declared in its consumer flake (SL-004).
    doctrine.url = "github:davidlee/doctrine/edge";

    # The fixture's fragment source: where the agent CLIs of its `agents`
    # fragment come from (fixture/, fragments.nix). A real fleet's sources are
    # its consumer's inputs, pinned in the consumer's lock (NOTES item 26,
    # docs/contract-flavour.md); oubliette pins this one only so its own build
    # exercises the composition path (SL-004 design sec-3).
    #
    # Deliberately not `follows = "nixpkgs"`: these are prebuilt in numtide's
    # cache against their own pin, and re-pointing nixpkgs rebuilds them here
    # for no gain.
    llm-agents.url = "github:numtide/llm-agents.nix";
  };

  # Oubliette's own fleet: its builder (mkfleet.nix) applied to the fixture,
  # declarations that are nobody's (fixture/, SL-004 design sec-3). A host's real
  # fleet is the same builder called by its consumer flake. The builder is bound
  # once, so the fleet below and `lib.mkFleet` are the same function.
  outputs = inputs: let
    system = "x86_64-linux";
    mkFleet = import ./mkfleet.nix {inherit (inputs) nixpkgs microvm doctrine;};

    # The builder and the two functions it applies, unapplied, for a flake that
    # declares its own fleet. One value: exported below, and the `lib` the
    # template is evaluated against, so the suite tests what a consumer gets.
    oublietteLib = {
      inherit mkFleet;
      capsules = import ./capsules.nix;
      targets = import ./targets;
    };

    fleet = mkFleet (import ./fixture {inherit (inputs) llm-agents nixpkgs;});

    # The template's own flake.nix, evaluated against stub inputs and nothing
    # fetched (templates/template-cases.nix). Oubliette's own check, so here
    # rather than in mkFleet: every consumer builds mkFleet's outputs, and none
    # of them has this template.
    templateCases = import ./templates/template-cases.nix {
      pkgs = inputs.nixpkgs.legacyPackages.${system};
      inherit (inputs.nixpkgs) lib;
      template = ./templates/fleet;
      inputs = {
        inherit (inputs) nixpkgs llm-agents;
        oubliette.lib = oublietteLib;
      };
    };
  in
    fleet
    // {
      lib = oublietteLib;

      # Merged into mkFleet's set rather than beside it: a top-level `//` would
      # replace the whole `packages` attribute.
      packages.${system} = fleet.packages.${system} // {inherit templateCases;};

      # `nix flake init -t github:davidlee/oubliette`: a consumer confining
      # doctrine, every file commented as the reference for its field (DEC-030).
      templates.default = {
        path = ./templates/fleet;
        description = "a capsule fleet confining doctrine: the declarations a consumer hands lib.mkFleet";
      };
    };
}
