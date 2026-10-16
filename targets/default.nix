# The targets a host declares, from its hand list — the axis's one home
# (POL-003). The list is the host's (mkfleet.nix's `targetPairs` here), and it
# stays a list **by hand**: a `readDir` would make a stray or untracked file a
# target.
#
# This file is the one place that derives what is a function of a target's
# name, so every target spells only what is its own (SL-003 design sec-2,
# DEC-018). Only mkfleet.nix applies it; everything generic takes the result as
# an argument, which is the seam IMP-015 needs.
byName:
# The hand list: `<name> = <the target's file>`. What follows is derived from it.
let
  # Where every capsule's volume is mounted in the guest. The capsule's, not a
  # target's: identical for every target, and read host-side as well as
  # guest-side (`caches`, `cachePaths` and `guestConfig` are all relative to it).
  # Guarded by vm/guest-path.nix.
  volumePath = "/work";

  # A target's name is its key here, spelled once.
  derive = name: t:
    t
    // {
      inherit name volumePath;
      # The guest's checkout, absolute. `vm/capsule.nix` creates it on the volume,
      # and the host's git channel pushes to it and fetches from it.
      guestPath = "${volumePath}/${name}";
      # The caches, absolute: what the guest's seed creates and chowns, and what
      # `capsule-baseline` sizes before and after a run.
      cachePaths = map (dir: "${volumePath}/${dir}") (builtins.attrValues t.caches);
    };
in {
  inherit volumePath;
  byName = builtins.mapAttrs derive byName;
}
