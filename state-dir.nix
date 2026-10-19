# state-dir.nix — whether a declared state root is one this host can use.
# SL-008 design sec-2, `DEC-054`, RV-023 F-4.
#
# `mkFleet`'s `stateDir` is where this host keeps its records, quarantines and
# room trust stores, and it reaches places where a path is not just a path:
#
#   - ssh's `UserKnownHostsFile` reads its value as a whitespace-separated list
#     and expands `%` tokens in it, so a space or a `%` names a different file;
#   - it is spliced **unquoted** into the front end's text and the volume root
#     helper's (host/cli.nix's `moduleState`, host/volume-root.nix's `marker`),
#     because `moduleState` is a shell expression by contract — so a `$(…)` or
#     a quote in it is code.
#
# So it must be an absolute path over a small character set, and canonical:
# after the leading `/`, every component is a name — not empty (which is `/`
# itself, `//` and a trailing slash) and not `.` or `..`. One canonical spelling
# is what lets `hasPrefix "${stateDir}/"` (mkfleet.nix's `unparented`) mean
# "under it".
#
# Its own file rather than a reason in fleet.nix, which decides slot binding:
# this is a host path, and nothing about it is a slot (design sec-8).
#
# Pure. `reasons.stateDir` is `null` or exactly what `value` throws, so a suite
# can assert *why* as well as *that* (fleet.nix's `reasons`, state-dir-cases.nix).
{lib}: stateDir: let
  inherit (builtins) match toJSON;

  # The one spelling of the set: the whole-value test and the list of offenders
  # both read it. `-` last, so it is a literal in a bracket.
  allowed = "A-Za-z0-9._+/-";
  refused = c: match "[${allowed}]" c == null;

  offenders = lib.unique (lib.filter refused (lib.stringToCharacters stateDir));
  unnamed =
    lib.filter (c: c == "" || c == "." || c == "..")
    (lib.splitString "/" (lib.removePrefix "/" stateDir));

  why =
    if !(lib.hasPrefix "/" stateDir)
    then "is not absolute"
    else if offenders != []
    then "contains ${toJSON (lib.concatStrings offenders)}"
    else if unnamed != []
    then "has a component that is not a name: ${toJSON (lib.head unnamed)}"
    else null;

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
