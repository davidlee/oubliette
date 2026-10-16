# SL-004's instrument: the drvPath of everything a fleet flake builds, so a
# refactor that claims to change nothing can be checked to change nothing.
#
# A function of a flake, so the same text judges oubliette and, from PHASE-06,
# the consumer that calls `lib.mkFleet`. Three families, sibling keys:
#   packages  every packages.x86_64-linux.*
#   runners   every nixosConfigurations.<name>.config.microvm.declaredRunner
#   module    system.build.toplevel of a probe NixOS system importing
#             nixosModules.capsule-perimeter
# Forced with deepSeq, so a throw anywhere is an eval failure, not a gap.
#
# The probe mirrors `hostModule` in oubliette's flake.nix at c4d73dc, and is
# deliberately frozen there: the instrument must not move with the code under
# test. `owner = "nobody"`, as hostModule has it, so no real user's name is in
# the output.
#
# Invocation, from the flake's checkout root (output is never committed):
#   nix eval --json --impure --no-write-lock-file --expr \
#     "import $PWD/.doctrine/slice/004/manifest.nix (builtins.getFlake \"git+file://$PWD\")" \
#     | jq -S .
flake: let
  inherit (flake.inputs.nixpkgs) lib;
  system = "x86_64-linux";
  probe = lib.nixosSystem {
    inherit system;
    modules = [
      flake.nixosModules.capsule-perimeter
      {
        system.stateVersion = "25.05";
        boot.loader.grub.enable = false;
        fileSystems."/" = {
          device = "none";
          fsType = "tmpfs";
        };
        services.resolved.enable = true;
        services.capsule-perimeter = {
          enable = true;
          owner = "nobody";
        };
      }
    ];
  };
  drv = p: p.drvPath;
  manifest = {
    packages = lib.mapAttrs (_: drv) flake.packages.${system};
    runners = lib.mapAttrs (_: c: drv c.config.microvm.declaredRunner) flake.nixosConfigurations;
    module = drv probe.config.system.build.toplevel;
  };
in
  builtins.deepSeq manifest manifest
