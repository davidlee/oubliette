# A path that will be spliced into a guest program's text unquoted, checked
# where it is *built* — SL-002 `RV-004` F-4.
#
# `capsule-reset-home` runs `rm -rf` as root over `home` and `scrubPaths`
# (vm/reset-home.nix), and both come from `target.nix`'s `volumePath` by way of
# `setup.nix`. Under POL-002 a different target supplies only a different value,
# so a `volumePath` carrying a space or a glob character would still build,
# still pass shellcheck, and word-split inside `rm -f -- "''${scrubPaths[@]}"`
# into paths nobody named. This is the check that a value which changes *which
# files are deleted* cannot arrive silently.
#
# It lives here rather than in vm/reset-home.nix because that file's fixture
# passes double-quoted shell expressions on purpose, and here rather than inline
# in vm/capsule.nix because a suite must be able to take it as an argument
# instead of re-rendering it (CLAUDE.md).
{lib}: let
  # Absolute, and nothing a shell reads as anything but a path.
  plain = "^/[A-Za-z0-9._/@+-]+$";
in
  # `what` says which declaration the path came from, since the throw is all the
  # reader gets.
  what: path:
    if builtins.match plain path != null
    then path
    else throw "vm/capsule.nix: ${what} ${lib.strings.escapeNixString path} is not a plain absolute path (${plain}), and it is spliced unquoted into capsule-reset-home's rm as root"
