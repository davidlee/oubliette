# This host's capsules: the declaration oubliette's `capsules.nix` is applied to
# (DEC-026). A *value*, and only this host's choices — what each field means,
# and every refusal of a bad one, is oubliette's capsules.nix.
#
# One slot. A slot is a name, an index and a target: the index places the
# slot's namespace and addresses on `uplinkNet` below, and the target is a key
# of `targets` in flake.nix. More slots are more lines; every slot bound to one
# target runs that target's one image (NOTES item 21). A slot moved to another
# target takes its volume reset before its first start under it (`ISS-009`): a
# provision resets tracked files only.
#
# The literal repeats a target's `name` (its key in `targets`) on purpose
# (`DEC-012`): renaming the target fails the build, naming these slots.
#
# `everything` lets a slot take any policy in policies.nix — a dev host saying
# so out loud. A slot that should only ever be sealed declares `["sealed"]`.
#
# A function of the policy vocabulary, applied in flake.nix with the one
# `policies` this host hands mkFleet.
{policies}: let
  slot = index: profile: {
    inherit index profile;
    # The policy a slot starts under, and the set it may be switched among.
    policy = "build";
    policies = policies.everything;
  };
in {
  slots = {
    a = slot 0 "doctrine";
  };

  addressing = {
    # A /16 written a.b.0.0/16: each slot gets the /30 a.b.<index>.0, so the
    # aggregator's route and NAT cover every capsule without enumerating them.
    uplinkNet = "10.100.0.0/16";
    # The aggregator's end of its link to the root namespace, and the root
    # namespace's: the host's default route, NAT for `uplinkNet`, and the
    # address the host's resolver stub has to answer on for a capsule to keep
    # the host's DNS (docs/plan-c-implementation.md). The host's NixOS config
    # has to agree with these.
    egressAddr = "10.101.0.2";
    egressPeerAddr = "10.101.0.1";
  };

  # Bytes a volume clone must leave free on the filesystem the images live on,
  # because running guests grow their sparse images into that space
  # (oubliette's capsules.nix, `volumeReserve`): 20 GiB.
  volumeReserve = 20 * 1024 * 1024 * 1024;
}
