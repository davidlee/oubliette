# This host's capsules: the declaration `capsules.nix` is applied to (DEC-026,
# SL-004 design sec-2). A *value*, and only this host's choices — what each
# field means, and every refusal of a bad one, is capsules.nix's.
#
# Ten slots, which is Plan D D2's pool (docs/plan-d-fleet.md). It waited for the
# guard to stop making one broken slot the whole host's problem: the audit set
# is declared ∩ present now, so a slot that never came up is capacity that does
# not exist rather than a refusal, and only a *present and wrong* namespace is
# fleet-wide (NOTES item 30, run on this host).
#
# `everything` is this host being a dev host out loud, rather than by nobody
# having thought about it.
#
# Every slot but `j` declares `doctrine`; `j` serves `goad-walk` (SL-003 design
# sec-5), chosen as the highest index and for nothing else. A slot moved to
# another target takes its volume reset before its first start under it
# (`ISS-009`): a provision resets tracked files only. The literal repeats a
# target's `name` (its key in `targets/`) on purpose (`DEC-012`): renaming the
# target fails the build, naming these slots.
#
# A function of the policy vocabulary, applied in flake.nix with the one
# `policies` this host hands mkFleet.
{policies}: let
  slot = index: profile: {
    inherit index profile;
    policy = "build";
    policies = policies.everything;
  };
in {
  slots = {
    a = slot 0 "doctrine";
    b = slot 1 "doctrine";
    c = slot 2 "doctrine";
    d = slot 3 "doctrine";
    e = slot 4 "doctrine";
    f = slot 5 "doctrine";
    g = slot 6 "doctrine";
    h = slot 7 "doctrine";
    i = slot 8 "doctrine";
    j = slot 9 "goad-walk";
  };

  addressing = {
    uplinkNet = "10.100.0.0/16";
    # The aggregator's end of its link to the root namespace, and the root
    # namespace's: the host's default route, NAT for `uplinkNet`, and the
    # address the host's resolver stub has to answer on for a capsule to keep
    # the host's DoT chain (docs/plan-c-implementation.md; a `~/flakes` edit).
    egressAddr = "10.101.0.2";
    egressPeerAddr = "10.101.0.1";
  };

  # 20 GiB left free by a clone (capsules.nix, `volumeReserve`).
  volumeReserve = 20 * 1024 * 1024 * 1024;
}
