# `session`: run a command in one repo of a room, with that repo's tools over
# the room's base (SL-006 design sec-3, `DEC-049`; SL-007 `DEC-052`).
#
#   session <repo> -- <argv...>
#
# Looks `<repo>` up in the tree a room's image renders under `root`, one
# directory per repo: `clone` links to its checkout and, for a target with a
# tool set, `tools` links to that package. The `PATH` it hands on is
# `tools/bin` (only with `tools`), then `<base>/bin` — the room's floor and its
# extras, so a repo's set shadows the base and the base shadows the caller —
# then the caller's `PATH`, if it has one, with no trailing `:`. Then it moves
# to the clone's *physical* path and `exec`s the argv untouched, so the command
# and everything it starts inherit that `PATH`.
#
# A malformed call (no `--`, or nothing after it), a name that is not
# repo-safe, a repo the tree lacks, or a `base` with no `bin` is refused on
# stderr with exit 2, in that order. It prints nothing to stdout, and sources no
# profile: a non-login caller gets the same `PATH` a login one would
# (`environment.variables` is login-shell scope).
#
# **It holds no repo table** — which repos exist, where they live and which have
# tools is the tree's answer, so nothing here learns what a target is
# (POL-002). Convenience inside the guest, not a boundary (POL-001).
#
# `root` and `base` are the seam (POL-004): build-time values, so a room ships
# the defaults and `vm/session-cases.nix` renders copies over a fixture tree.
# `runtimeInputs` stays empty, since any entry would sit ahead of `tools/bin`
# and the base, which are the only things `session` puts on the `PATH`.
{
  pkgs,
  root ? "/etc/room/repo",
  base ? "/etc/room/base",
}:
pkgs.writeShellApplication {
  name = "session";
  runtimeInputs = [];
  text = ''
    root=${pkgs.lib.escapeShellArg root}
    base=${pkgs.lib.escapeShellArg base}

    if [ "$#" -lt 3 ] || [ "$2" != -- ]; then
      echo "usage: session <repo> -- <argv...>" >&2
      exit 2
    fi
    repo=$1
    shift 2

    case $repo in
    "" | . | .. | *[!A-Za-z0-9._-]*)
      echo "session: '$repo' is not a repo name ([A-Za-z0-9._-]+, and not . or ..)" >&2
      exit 2
      ;;
    esac
    if [ ! -d "$root/$repo" ]; then
      echo "session: no such repo: $repo (no $root/$repo)" >&2
      exit 2
    fi

    if [ ! -d "$base/bin" ]; then
      echo "session: no base at $base" >&2
      exit 2
    fi

    tools=
    if [ -d "$root/$repo/tools" ]; then
      tools="$root/$repo/tools/bin:"
    fi
    PATH="$tools$base/bin''${PATH:+:$PATH}"
    cd -P "$root/$repo/clone"
    exec "$@"
  '';
}
