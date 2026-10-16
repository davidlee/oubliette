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

  outputs = inputs: import ./mkfleet.nix inputs;
}
