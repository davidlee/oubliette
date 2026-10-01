# fleet.nix — from this host's declarations to its VMs. SL-003 design sec-3.
#
# Pure: no host values. flake.nix applies it once, to this host's targets, flakes,
# slots and probe subject, and is the one binding site; fleet-cases.nix applies
# it to a stub `mkVm` and fixtures. This is also what IMP-015's exported builder
# grows from, so it is named for the fleet rather than for this host.
#
# One image per declared target, every one hostName `capsule` (DEC-020): the
# hostname is in the closure and is the process name `microvm@capsule`, so
# keeping it one word keeps "a VMM is identified by its namespace, never by its
# name" the only rule anything relies on. A slot boots the image its profile
# names (DEC-017), and two slots with one profile resolve to one value, so "one
# image per target, N slots" is structural rather than a claim.
#
# Each refusal's message is a value in `reasons` (`null` when there is none) and
# is exactly what the matching attribute throws, so a suite can assert *why* as
# well as *that* — a `tryEval` verdict carries no message.
{
  lib,
  mkVm,
}: {
  targets,
  # A flake input's url must be a literal, so the target values cannot carry their
  # own flake; flake.nix holds this map beside the inputs (DEC-019). Complete, not
  # optional: a target with `toolsPackage = null` still has an entry, so no
  # consumer has to decide what a missing key means.
  targetFlakes,
  capsules,
  probeTarget,
}: let
  inherit (builtins) attrNames concatStringsSep mapAttrs;
  names = attrNames targets.byName;
  flakeNames = attrNames targetFlakes;
  missing = lib.subtractLists flakeNames names;
  extra = lib.subtractLists names flakeNames;

  # A declared slot must name a declared target. Checked here, at the binding,
  # and not in capsules.nix, which does not import targets/ (DEC-012 alt B).
  # capsules.nix's own `misprofiled` shape check runs first and independently.
  unbound =
    lib.filterAttrs
    (_: c: c.profile == null || !(targets.byName ? ${c.profile}))
    capsules.instances;

  reasons = {
    images =
      if missing == [] && extra == []
      then null
      else
        "fleet.nix: targetFlakes must name exactly the targets in targets/"
        + lib.optionalString (missing != []) "; no flake for ${concatStringsSep ", " missing}"
        + lib.optionalString (extra != []) "; a flake for no target: ${concatStringsSep ", " extra}"
        + " (DEC-019)";
    slotImages =
      if unbound == {}
      then null
      else "capsules.nix: a slot boots the image its profile names (DEC-017), and these slots name no target in targets/, or no profile at all: ${concatStringsSep ", " (attrNames unbound)}";
  };

  images =
    if reasons.images != null
    then throw reasons.images
    else
      mapAttrs (name: target:
        mkVm "capsule" ./vm/capsule.nix {
          inherit target;
          targetFlake = targetFlakes.${name};
        })
      targets.byName;

  slotImages =
    if reasons.slotImages != null
    then throw reasons.slotImages
    else mapAttrs (_: c: images.${c.profile}) capsules.instances;
in {
  inherit images slotImages reasons;
  # `capsule` is the probe target's image under the name its process carries:
  # every probe builds `.#capsule` and matches `microvm@capsule`.
  vms = {capsule = images.${probeTarget};} // slotImages;
}
