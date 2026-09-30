# Which VMMs in this netns are running a given image — the devshell path's only
# way to find its own, shared by `vm` (refuse to start over one) and `vm-stop`
# (wait for one, then reap it). SL-003 design sec-4.
#
# **Keyed by process name, never by slot name.** A runner is
# `exec -a microvm@<hostName>`, and every capsule image is hostName `capsule`
# (DEC-020), so a slot's name is never in the process table. `vm-stop` used to
# grep `microvm@$name`, which found slot `c` only because `c` is a prefix of
# `capsule` — and told every other slot it was down over a running VMM
# (ISS-016). `vmmOf` is that mapping, and `capsuleNames` is its one input: the
# names whose image is a capsule's (`capsule` and each declared slot).
#
# **Scoped to this shell's netns.** Every capsule is `microvm@capsule`, so a
# bare `pgrep`/`pkill -f` is a power cut for any namespaced sibling the module
# path is running. A VMM in a namespace is root's and lives in another netns, so
# the test excludes it: the readlink fails, or it does not match this shell's.
{
  lib,
  capsuleNames,
}: ''
  vmmOf() {
    case "$1" in
      ${lib.concatStringsSep " | " capsuleNames}) echo capsule ;;
      *) echo "$1" ;;
    esac
  }

  own_vms() {
    local self pid
    self=$(readlink /proc/self/ns/net)
    # Anchored at both ends: a prefix match is how ISS-016 happened.
    for pid in $(pgrep -f "^microvm@$1( |\$)" || true); do
      [ "$(readlink "/proc/$pid/ns/net" 2>/dev/null)" = "$self" ] \
        && echo "$pid"
    done
  }
''
