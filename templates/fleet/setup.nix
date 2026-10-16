# What a fresh capsule needs before it is a capsule you can work in, beyond its
# history and its static config. `capsule-inject` pushes these over the existing
# ssh channel as you — and `capsule <name> start` runs it, so a started capsule
# has them; oubliette's `host/inject.nix` is the mechanism and knows none of the
# below.
#
# Its own file, and deliberately not a target's: none of this is a property of
# the repo under confinement. doctrine has no opinion about which agent you sign
# in as, and a second target would share this list unchanged. Empty (`[]`) is a
# working value — a capsule with no injections is a capsule you log into by
# hand.
#
# **Selection is the whole point.** Every entry names what leaves this host, and
# the default for anything not named is that it stays. The tempting version —
# copy an agent's whole config directory in — would carry every repo path you
# have opened and your prompt history into a jail that exists to not have them.
#
# An entry is `{name, dest, produce, tools}` plus an optional `optional`:
#
#   - `name` is what `capsule-inject` reports, and what you name to re-inject it.
#   - `dest` is the absolute path in the guest the payload is written to.
#   - `produce` is a host-side shell fragment writing the payload to stdout. It
#     is a program, not a value, which is what keeps filenames, formats and key
#     names out of the mechanism. `$capsule` is in scope, so a payload may differ
#     per capsule; argv is not, since the flag loop has already consumed it.
#   - `tools` are nixpkgs attr names `produce` needs on its PATH.
#   - `optional = true` means a source that is not on this host is a skip rather
#     than a failure — the working absent path a declaration shared by every host
#     needs.
#
# The volume's mount point is the only thing taken from oubliette's `targets/`,
# because a payload's destination is on the volume and `/work` may not be
# spelled twice. Nothing else target-shaped belongs here.
{volumePath}: let
  # The agent's `$HOME` in the guest (docs/contract-target.md), for the
  # commented example below.
  home = "${volumePath}/home";

  # Where *this* host keeps what it is willing to hand a capsule. Per capsule
  # first, then a shared file — so one host can give two capsules different
  # secrets without the declaration learning either capsule's name.
  mine = "$HOME/.config/capsule";
in [
  {
    # Environment secrets — API keys and anything else a shell in the guest
    # wants exported. `<volumePath>/.env` is sourced at login and persists on the
    # volume, so this is the file the guest already has (NOTES item 2).
    #
    # `op inject` is the second shape, and it is the same interface — swap the
    # line below for
    #
    #     op inject -i "${mine}/$capsule.env.tpl" 2>/dev/null \
    #       || op inject -i "${mine}/env.tpl" 2>/dev/null
    #
    # and add `tools = ["_1password-cli"];`. It has to run *here* rather than in
    # the guest: `op` reaches a host unix socket and firecracker has no shares,
    # so the direction is fixed — the rendered environment goes in, it is never
    # fetched out (docs/plan-c-multi-capsule.md, "Secrets and home at N").
    #
    # Optional, and that is the point of the field: a host with neither file
    # still starts capsules, and says which payload it skipped.
    name = "env";
    dest = "${volumePath}/.env";
    optional = true;
    produce = ''
      cat "${mine}/$capsule.env" 2>/dev/null || cat "${mine}/env" 2>/dev/null
    '';
    tools = [];
  }

  # An agent's credential, whole, so a capsule session starts signed in. Point
  # `produce` at a copy you are willing to hand a capsule — a separated agent
  # account's, not your own home's — and uncomment. `capsule-inject` refuses to
  # replace an existing copy without `--force`, because a token that rotates on
  # refresh diverges between the two copies and neither is authoritative.
  #
  # {
  #   name = "claude-credentials";
  #   dest = "${home}/.claude/.credentials.json";
  #   produce = "cat ${mine}/claude-credentials.json";
  #   tools = [];
  # }
]
