~/flakes/hosts.nix:112 builds home-manager with
`inputs.home-manager.lib.homeManagerConfiguration`, not the NixOS module, so
`osConfig` does not exist there. HM modules receive `inputs` (e.g.
~/flakes/features/satan/runner.nix:32), so a flake output of the fleet
(`inputs.fleet.packages.<sys>.<x>`) is reachable and a module option is not.
That is why DEC-054 moved the state root to a `mkFleet` declaration rather than
exposing room-client bundles as a module option.
