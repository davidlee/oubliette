# Whether the template's own wiring still fits the builder — SL-004 design
# sec-5, DEC-030, RV-012 F-8.
#
# The subject is `templates/fleet/flake.nix` itself, not a copy of its
# declarations: its `outputs` is called with stub inputs, so the template's own
# `mkFleet` call — which file goes to which argument — is what is evaluated. A
# template that drifts from the builder's argument surface fails oubliette's
# build here, instead of failing the first `nix flake init` after it.
#
# **Its inputs are never fetched**, which is what keeps oubliette's lock free of
# any target (DEC-030): `nixpkgs` and `llm-agents` are oubliette's own pins,
# `oubliette` carries this tree's `lib` and nothing else the template does not
# read, and `doctrine` is a stub flake whose tool set is empty. A template that
# grows an input this suite has no stub for fails with that input's name rather
# than with a missing attribute somewhere inside the builder.
#
# What is forced is every slot runner's `drvPath`, with `deepSeq`, so a throw
# inside an attrset is seen (CLAUDE.md, "force what you pin"); and the devshell's,
# which carries every host program and the shellHook. Forcing proves the
# template *evaluates*; nothing here is built, booted or locked, and the
# template's justfile, `.envrc` and README are not run at all. **Only names
# reach the output**: a drvPath string carries its derivation as context, and
# putting one in the text would make every runner a build input of this suite,
# turning an eval check into a full guest build
# (`mem.pattern.oubliette.forcing-is-not-building`).
{
  pkgs,
  lib,
  # `./templates/fleet`: the subject, as a path, so this suite reads the same
  # files `nix flake init` copies.
  template,
  # The stubs this suite cannot make itself: oubliette's own `nixpkgs` and
  # `llm-agents`, and `oubliette`, a flake-shaped value carrying this tree's
  # `lib`. `doctrine` is made below, from the template's own declaration.
  inputs,
}: let
  flake = import (template + "/flake.nix");

  # The doctrine stub carries exactly the package the template's target reads
  # out of it (vm/capsule.nix's floor), named by that target's `toolsPackage`
  # rather than spelled here a second time. Empty: a tool set is the target's to
  # build, and this suite asks only whether the template's wiring evaluates.
  inherit (import (template + "/targets/doctrine.nix")) toolsPackage;
  doctrine.packages.${pkgs.stdenv.hostPlatform.system}.${toolsPackage} = pkgs.buildEnv {
    name = "template-stub-tools";
    paths = [];
  };

  stubs = inputs // {inherit doctrine;};
  unstubbed = lib.subtractLists (builtins.attrNames stubs) (builtins.attrNames flake.inputs);
  unread = lib.subtractLists (builtins.attrNames flake.inputs) (builtins.attrNames stubs);

  outputs =
    if unstubbed != []
    then throw "templateCases: the template declares inputs this suite has no stub for: ${toString unstubbed}"
    else if unread != []
    then throw "templateCases: stubs the template does not declare as inputs: ${toString unread}"
    else flake.outputs stubs;

  runners = lib.mapAttrs (_: c: c.config.microvm.declaredRunner.drvPath) outputs.nixosConfigurations;
  forced = {
    inherit runners;
    devShell = outputs.devShells.${pkgs.stdenv.hostPlatform.system}.default.drvPath;
  };
in
  # An empty fleet would force nothing and pass.
  if runners == {}
  then throw "templateCases: the template declares no slot, so no runner was forced"
  else
    builtins.deepSeq forced (pkgs.runCommand "template-cases" {} ''
      echo "templateCases: the template's flake.nix evaluates through mkFleet; runners forced: ${toString (builtins.attrNames runners)}"
      touch "$out"
    '')
