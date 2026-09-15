# `capsule-volume-root`: the only program on the volume path that runs as root,
# and the only one that touches an image file (SL-002 design sec-3, `DEC-005`).
#
#   capsule-volume-root reset <slot>
#   capsule-volume-root clone <src> <dest> [--identity]
#
# `reset` deletes a stopped slot's image, so its next start makes a cold volume.
# `clone` sparse-copies one stopped slot's image onto another and, unless
# `--identity`, leaves a scrub marker the front end acts on before any inject
# (sec-5). Nothing here starts, stops or reaches a guest: whether a unit is
# stopped is the front end's cheap early question, and this program asks the one
# that is a guarantee, whether anything has the *file* open, in the same process
# that then acts on it.
#
# **Every path it acts on is fixed when it is built.** Its roots, its image
# owner and its lock come from arguments with defaults, never from its command
# line, which carries a sub-command, slot names and `--identity` and nothing
# else. It runs as root through `sudo -k`, and a later password-less grant
# (`IMP-010`) must not be able to point it at `/`. That is also why its suite
# renders its own copy against a sandbox rather than running this store path
# (host/volume-root-cases.nix).
#
# **Root does no path-based act inside an image directory** (`RV-003` `F-1`).
# Each `/var/lib/microvms/<slot>` is `root:kvm 0775`, and `microvm`, the uid of
# every VMM whichever slot it serves, is in `kvm`. A root `cp`, `chmod` or `rm` by
# path in there is a symlink race any running VMM can win. So everything that
# creates, modifies, renames or removes a file there goes through `asImageOwner`:
# as that owner a won race gains nothing the VMM does not already have, a copy
# the owner makes needs no ownership change, and a swapped source it cannot read
# fails the copy. Root keeps what writes nothing through that directory: the
# lock, `fuser`, the fit check's `stat`, and the marker, which sits in the
# operator's record directory where `microvm` cannot write.
#
# `tools` is the guard's seam (host/guard.nix) for the three steps a sandbox
# cannot provoke: a filesystem small enough to refuse a clone, a second uid, and
# a failure between two lines. `df`, `setpriv` and `mv` come from
# `runtimeInputs`, so a suite cannot shadow them on `PATH`.
{
  pkgs,
  lib,
  # capsules.nix: the declared slot names, `volumeLock` and `volumeReserve`.
  capsules,
  # Where microvm.nix keeps each slot's state directory and image.
  microvms ? "/var/lib/microvms",
  # Where the assignment records live; the scrub marker sits in a slot's one.
  moduleState ? "/var/lib/capsule",
  # Who acts inside an image directory: the runner's own images' owner.
  imageOwner ? {
    user = "microvm";
    group = "kvm";
  },
  tools ? ''
    freeBytes() { df --output=avail -B1 "$1" | tail -n 1; }
    asImageOwner() { setpriv --reuid=${imageOwner.user} --regid=${imageOwner.group} --init-groups -- "$@"; }
    commitImage() { asImageOwner mv -T -- "$1" "$2"; }
  '',
}:
pkgs.writeShellApplication {
  name = "capsule-volume-root";
  runtimeInputs = [pkgs.coreutils pkgs.util-linux pkgs.psmisc];
  text = ''
    ${tools}

    declared=(${lib.escapeShellArgs (builtins.attrNames capsules.instances)})
    reserve=${toString capsules.volumeReserve}
    umask 022

    usage() {
      echo "usage: capsule-volume-root reset <slot>" >&2
      echo "       capsule-volume-root clone <src> <dest> [--identity]" >&2
      exit 2
    }
    refuse() { echo "capsule-volume-root: $*" >&2; exit 1; }

    img() { printf '%s/%s/capsule-work.img' ${microvms} "$1"; }
    marker() { printf '%s/slot/%s/scrub-pending' ${moduleState} "$1"; }
    # The same test as the front end's `created`: microvm.nix made this slot's
    # state directory, so an image placed there is one a start will use.
    created() { [ -x ${microvms}/"$1"/current/bin/tap-up ]; }

    # Against the pool this program was built with, and never trusted because the
    # front end checked first: this is a root program.
    declaredSlot() {
      local s
      for s in "''${declared[@]}"; do [ "$s" = "$1" ] && return 0; done
      refuse "not a declared slot: $1 (declared: ''${declared[*]})"
    }

    # A file, not a process name, because every VMM is `microvm@capsule`
    # (mem.fact.oubliette.dead-guest-is-not-a-dead-vm).
    notHeld() {
      local pids
      [ -e "$1" ] || return 0
      if pids=$(fuser "$1" 2> /dev/null); then
        refuse "$1 is held open by pid$pids; stop whatever holds it first"
      fi
    }

    resetImage() {
      local slot=$1 image
      declaredSlot "$slot"
      image=$(img "$slot")
      if [ ! -e "$image" ]; then
        rm -f -- "$(marker "$slot")"
        echo "capsule-volume-root: $slot has no image, so it is already fresh"
        return 0
      fi
      notHeld "$image"
      asImageOwner rm -f -- "$image"
      # A cold volume has no identity to scrub. A crash between these two lines
      # leaves a marker over no image, whose only effect is a scrub of the cold
      # volume the next start makes.
      rm -f -- "$(marker "$slot")"
      echo "capsule-volume-root: deleted $slot's image; its next start makes a cold volume"
    }

    # Global rather than local: the EXIT trap reads it after the function is gone.
    tmp=

    cloneImage() {
      local src=$1 dest=$2 identity=''${3:-} from to mark need free wrote=
      declaredSlot "$src"
      declaredSlot "$dest"
      [ "$src" != "$dest" ] || refuse "source and destination are the same slot: $src"
      from=$(img "$src")
      to=$(img "$dest")
      mark=$(marker "$dest")
      [ -f "$from" ] || refuse "$src has no image to clone ($from)"
      created "$dest" || refuse "$dest was never created here, so there is nowhere to put its image"
      # The record directory is the operator's (0750, the record writer's), and one
      # made here would be root's and refuse every later record write.
      [ -d "''${mark%/*}" ] || refuse "$dest has no record directory (''${mark%/*}); the front end makes it as the operator, and this program never does"

      notHeld "$from"
      notHeld "$to"

      # Allocated, not apparent: a sparse copy costs what the source has written.
      # Free is what non-root writers have, because the running VMMs are
      # `microvm` and grow their own images into it.
      need=$(($(stat -c '%b * %B' "$from") + reserve))
      free=$(freeBytes "''${to%/*}")
      [ "$need" -le "$free" ] ||
        refuse "$src's image allocates $((need - reserve)) bytes, and with the $reserve-byte reserve that does not fit in the $free bytes free"

      # A fixed name beside the destination, so the commit is a rename on one
      # filesystem. A leftover is an earlier run killed mid-copy: the lock says no
      # helper is writing it, and `notHeld` says nothing else is using the slot.
      # After a successful commit the name no longer exists, so the trap removes
      # only a copy that never became the image.
      tmp="''${to%/*}/capsule-work.img.clone"
      trap 'asImageOwner rm -f -- "$tmp"' EXIT
      asImageOwner rm -f -- "$tmp"
      asImageOwner cp --sparse=always -- "$from" "$tmp"
      asImageOwner chmod 0644 -- "$tmp"

      # The marker invariant: it exists whenever the destination's image may carry
      # another slot's identity that nobody chose to keep. So it is written before
      # the commit, and a failed commit removes only a marker this run wrote. An
      # earlier clone's marker is left exactly as it is, since removing it would
      # unmark a clone nobody has scrubbed.
      if [ -z "$identity" ] && [ ! -e "$mark" ]; then
        printf 'source=%s at=%s\n' "$src" "$(date -u +%FT%TZ)" > "$mark"
        wrote=1
      fi
      if ! commitImage "$tmp" "$to"; then
        [ -z "$wrote" ] || rm -f -- "$mark"
        refuse "could not move the copy into place at $to; $dest's image and marker are as they were"
      fi
      # Kept on purpose, so an earlier clone's marker would scrub what the operator
      # asked to keep. Only after the commit: before it, that marker still guards
      # the earlier clone's image.
      [ -z "$identity" ] || rm -f -- "$mark"

      echo "capsule-volume-root: cloned $src onto $dest ($((need - reserve)) bytes allocated)"
    }

    [ $# -ge 1 ] || usage
    verb=$1
    shift
    case "$verb" in
      reset) [ $# -eq 1 ] || usage ;;
      clone) [ $# -eq 2 ] || { [ $# -eq 3 ] && [ "$3" = --identity ]; } || usage ;;
      *) usage ;;
    esac

    # Before any check, so every check and act below is inside it. Held until
    # this process exits, and the kernel drops it with the last descriptor, so a
    # crash releases it. `capsule <slot> start` takes it shared.
    exec 9<>${capsules.volumeLock}
    flock -n 9 || refuse "another volume operation is running on this host; try again when it finishes"

    case "$verb" in
      reset) resetImage "$@" ;;
      clone) cloneImage "$@" ;;
    esac
  '';
}
