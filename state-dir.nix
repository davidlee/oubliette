# state-dir.nix — whether a declared state root is one this host can use.
# SL-008 design sec-2, `DEC-054`, RV-023 F-4.
#
# `mkFleet`'s `stateDir` is where this host keeps its records, quarantines and
# room trust stores, and it reaches places where a path is not just a path:
# ssh's `UserKnownHostsFile`, and the unquoted splices into the front end's text
# and the volume root helper's (host/cli.nix's `moduleState`,
# host/volume-root.nix's `marker`). So it must be an absolute path over a small
# character set, and canonical: after the leading `/`, every component is a
# name — not empty (which is `/` itself, `//` and a trailing slash) and not `.`
# or `..`. One canonical spelling is what lets `hasPrefix "${stateDir}/"`
# (mkfleet.nix's `unparented`) mean "under it".
#
# The predicate — the character set, what a path may not be, and *why* — lives
# in host-path.nix, which states it once for this option and for
# `net.modelDoor.socket` (SL-010 design sec-2 D-4). This file owns the message,
# which is the part that names this option.
#
# Its own file rather than a reason in fleet.nix, which decides slot binding:
# this is a host path, and nothing about it is a slot (design sec-8).
#
# Pure. `reasons.stateDir` is `null` or exactly what `value` throws, so a suite
# can assert *why* as well as *that* (fleet.nix's `reasons`, state-dir-cases.nix).
{lib}: stateDir: let
  inherit (builtins) toJSON;

  hostPath = import ./host-path.nix {inherit lib;};
  inherit (hostPath) allowed;
  why = hostPath.why stateDir;

  reasons.stateDir =
    if why == null
    then null
    else "mkFleet's stateDir ${toJSON stateDir} ${why} — it must be an absolute path over [${allowed}] whose every component is a name, not empty, '.' or '..' (DEC-054, RV-023 F-4)";
in {
  inherit reasons;
  value =
    if reasons.stateDir != null
    then throw reasons.stateDir
    else stateDir;
}
