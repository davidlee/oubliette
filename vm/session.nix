# `session`: run a command in one repo of a room, with that repo's tools (SL-006
# design sec-3, `DEC-044`).
#
#   session <repo> -- <argv...>
#
# Looks `<repo>` up in the tree a room's image renders under `root`, one
# directory per repo: `clone` links to its checkout and, for a target with a
# tool set, `tools` links to that package. With `tools`, `tools/bin` goes ahead
# of the inherited `PATH`; without it, the `PATH` is the caller's exactly. Then
# it moves to the clone's *physical* path and `exec`s the argv untouched, so the
# command and everything it starts inherit the repo's tools.
#
# A malformed call (no `--`, or nothing after it), a name that is not
# repo-safe, or a repo the tree lacks is refused on stderr with exit 2. It
# prints nothing to stdout, and sources no profile: a non-login caller gets the
# same `PATH` a login one would (`environment.variables` is login-shell scope).
#
# **It holds no repo table** — which repos exist, where they live and which have
# tools is the tree's answer, so nothing here learns what a target is
# (POL-002). Convenience inside the guest, not a boundary (POL-001).
#
# `root` is the seam (POL-004): a build-time value, so a room ships the default
# and `vm/session-cases.nix` renders a copy over a fixture tree.
# `runtimeInputs` stays empty, since any entry would sit ahead of the caller's
# `PATH`, which is what a repo without a set must leave alone.
{
  pkgs,
  root ? "/etc/room/repo",
}:
pkgs.writeShellApplication {
  name = "session";
  runtimeInputs = [];
  text = ''
    root=${pkgs.lib.escapeShellArg root}

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

    if [ -d "$root/$repo/tools" ]; then
      PATH="$root/$repo/tools/bin:$PATH"
    fi
    cd -P "$root/$repo/clone"
    exec "$@"
  '';
}
