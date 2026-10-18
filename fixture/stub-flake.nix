# A tool-set flake that is nobody's, as a plain value: every fixture target's
# `flake`. `fixture` declares `toolsPackage = null`, so it reads nothing out of
# it; `tooled` reads `tools`, one marker binary, so a room's image can show one
# repo with a set beside one without. A value rather than a flake input, so
# nothing reaches oubliette's lock beyond the `nixpkgs` it already has.
{pkgs}: {
  packages.x86_64-linux.tools = pkgs.writeShellScriptBin "fixture-tool" "echo fixture-tool";
}
