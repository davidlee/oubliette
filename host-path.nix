# host-path.nix — the one spelling of a path this host can splice.
# SL-010 design sec-2 D-4; the test is state-dir.nix's, moved out intact.
#
# Two consumers, one predicate: state-dir.nix asks it of `mkFleet`'s `stateDir`,
# model-door.nix of `net.modelDoor.socket`. Each keeps its own message, because
# a refusal that cannot say which option it is about is not a reason.
#
# The character set is small because the value does not stay a value:
#
#   - ssh's `UserKnownHostsFile` reads its value as a whitespace-separated list
#     and expands `%` tokens in it, so a space or a `%` names a different file;
#   - it is spliced **unquoted** into the front end's text and the volume root
#     helper's (host/cli.nix's `moduleState`, host/volume-root.nix's `marker`),
#     because `moduleState` is a shell expression by contract — so a `$(…)` or
#     a quote in it is code;
#   - socat parses `,` as an option separator and `:` as an address separator in
#     its address text, and the set excludes both, so a path that passes is one
#     socat reads as one path.
#
# So it must be an absolute path over that set, and canonical: after the leading
# `/`, every component is a name — not empty (which is `/` itself, `//` and a
# trailing slash) and not `.` or `..`. One canonical spelling is what lets
# `hasPrefix "${stateDir}/"` (mkfleet.nix's `unparented`) mean "under it".
#
# Pure. `why` is `null` when the path is fine, otherwise exactly the text a
# caller splices into its own refusal; a suite can assert *why* as well as
# *that* (state-dir-cases.nix, model-door-cases.nix).
{lib}: let
  inherit (builtins) match toJSON;

  # The one spelling of the set: the whole-value test and the list of offenders
  # both read it. `-` last, so it is a literal in a bracket.
  allowed = "A-Za-z0-9._+/-";
  refused = c: match "[${allowed}]" c == null;

  why = path: let
    offenders = lib.unique (lib.filter refused (lib.stringToCharacters path));
    unnamed =
      lib.filter (c: c == "" || c == "." || c == "..")
      (lib.splitString "/" (lib.removePrefix "/" path));
  in
    if !(lib.hasPrefix "/" path)
    then "is not absolute"
    else if offenders != []
    then "contains ${toJSON (lib.concatStrings offenders)}"
    else if unnamed != []
    then "has a component that is not a name: ${toJSON (lib.head unnamed)}"
    else null;
in {
  inherit allowed why;
}
