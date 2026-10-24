In a NixOS module, `pkgs` is `config._module.args.pkgs`, and `imports` is read before `config` exists. So an `imports` list computed from anything that forces `pkgs`, even only `pkgs.lib`, is `error: infinite recursion encountered` ("you probably reference `config` in `imports`").

Hit in SL-009 PHASE-03. `vm/room.nix` imports `fragments.modules room.extras`, and `fragments.nix` read `pkgs.lib`. The fix is to make `lib` a required argument of `fragments.nix` (17d6ef2), so `vm/room.nix` passes its module `lib` (from `lib/` and specialArgs, not from `pkgs`). An unforced `pkgs` in the argument attrset is fine; only forcing it recurses. A default of `lib ? pkgs.lib` brings the recursion back for any module caller that omits it, which is why the argument has no default.

To diagnose: `nix eval .#nixosConfigurations.<room>.config.networking.hostName`. The trace names `imports`.
