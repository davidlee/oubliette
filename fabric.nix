# fabric.nix — which names a probe's egress fabric may not borrow from the live
# declaration. NOTES item 38; SL-005 design sec-2.
#
# Pure: no host values. mkfleet.nix applies it once, to `capsules.nix`'s
# records, `rooms.nix`'s records and the caller's `probe.fabric`, and throws
# `reason` when the probe prelude is forced; fabric-cases.nix applies it to
# fixtures. The reason is a value (`null` when nothing is borrowed) so a suite
# can assert *why* as well as *that* — a `tryEval` verdict carries no message.
#
# `probe.fabric` is the names, links and addressing a probe's egress fabric is
# built from — **and this is the eval-time refusal to share any of them with
# the live declaration**, which is the whole reason it is a value rather than
# four literals in `probe/harness.sh`.
#
# `capsules.nix` copied its map *from* `probe/netns-egress.sh` once that probe
# had verified the shape, so the probe became a borrower of live addressing
# with no line of it changing and nothing to notice: on a module-path host
# `eg-rt` is the live aggregator's uplink to the root namespace, and the
# probe's own teardown deletes that name (NOTES item 38). The rule about not
# borrowing live addressing needs an enforcer, because it is broken by the
# *other* file moving.
{lib}: {
  capsules,
  rooms,
  fabric,
}: let
  # Every string this host's declaration puts on a wire or in `ip netns list`.
  # A probe may reuse none of them.
  liveNames = let
    eg = capsules.egress;
    c = i: [i.ns i.uplink.dev i.uplink.peer i.uplink.addr i.uplink.gw];
  in
    [eg.ns eg.dev eg.peer eg.addr eg.peerAddr capsules.uplinkNet]
    ++ lib.concatMap c (lib.attrValues capsules.instances)
    # A room in a branch of its own: it has no `uplink` to dereference, and its
    # socket is under its own directory, disjoint by prefix (design sec-2).
    ++ map (r: r.ns) (lib.attrValues rooms);

  borrowed = lib.intersectLists (lib.attrValues fabric) liveNames;
in {
  inherit liveNames borrowed;
  reason =
    if borrowed == []
    then null
    else "mkFleet: probeFabric borrows '${builtins.head borrowed}' from the live declaration (capsules.nix, rooms) — a probe's fabric may share no name, link, address or network with the live one (NOTES item 38)";
}
