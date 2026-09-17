# `capsule-reset-home`: the only code that deletes inside a volume (SL-002 design
# sec-4, `DEC-001`), and it ships in the guest.
#
#   capsule-reset-home [--scrub]      as root, over the admin door
#
# Deletes the agent's `$HOME` and re-runs `capsule-seed`, which makes it again.
# `--scrub` also removes `scrubPaths` and makes the guest a new host key, which is
# what a clone that must not carry its source's identity needs (`DEC-003`).
#
# It refuses (3) on evidence that the agent is working, then stops what that test
# cannot see, the gettys and the agent's whole user slice, before it deletes. A
# login that arrives meanwhile is detected (4), not prevented: blocking one needs
# `pam_nologin` in the guest's sshd stack (`IMP-011`). The gettys are started
# again on every exit once they were stopped.
#
# **Every path it acts on is fixed when the image is built**: `home` and
# `scrubPaths` are spliced into the text raw, as `capsule-seed` splices `home`,
# and the command line carries `--scrub` and nothing else. A fixture passes a
# double-quoted shell expression instead (vm/reset-home-cases.nix), which is why
# the check that a real path is a plain absolute one is not here but at the call
# site that holds the target's values: vm/capsule.nix, through vm/guest-path.nix.
# Both are unlinked rather than followed: `rm -rf` on `$HOME` with no trailing
# slash removes a symlink and not what it names, and never follows one inside it.
# That matters less than on the host (POL-001: this is convenience, not a
# boundary), but a root program walking an agent-writable tree should not
# follow it anywhere.
#
# **What it does not know:** what a credential is, which target is confined, or
# which slot it is (POL-002). It deletes a directory the guest module named and
# paths two declarations named.
#
# `tools` is the guard's seam (host/guard.nix) for the running guest: logind's
# session list and systemd's units. The rule for which sessions are work is not
# in it, so a suite runs that rule rather than stubbing its answer. `systemctl`
# and `loginctl` come from the guest's own `PATH`, so they are the running
# systemd's.
{
  pkgs,
  lib,
  # vm/capsule.nix's own binding.
  home,
  # `users.users.agent.uid`: systemd puts every agent session in `user-<uid>.slice`.
  agentUid,
  # Absolute paths removed only under `--scrub` (vm/capsule.nix says where from).
  scrubPaths,
  tools ? ''
    # One line per agent session: id, tty (`-` for none), service, class, state.
    # A session that cannot be read is printed with `?` fields, which the rule
    # below counts as work: the unknown errs towards a refusal.
    agentSessions() {
      local sessions id
      # Returned rather than left to errexit, which a command substitution does
      # not inherit: an empty listing would read as nobody working.
      sessions=$(loginctl list-sessions --no-legend) || return
      while read -r id _; do
        [ -n "$id" ] || continue
        loginctl show-session "$id" -p Name -p TTY -p Service -p Class -p State |
          awk -F= -v id="$id" '
            { v[$1] = substr($0, length($1) + 2) }
            END { if (v["Name"] == "agent") print id, (v["TTY"] == "" ? "-" : v["TTY"]), v["Service"], v["Class"], v["State"] }' ||
          echo "$id - ? ? ?"
      done <<<"$sessions"
    }
    activeGettys() {
      systemctl list-units --state=active --no-legend --plain 'getty@*' 'serial-getty@*' | awk '{print $1}'
    }
    startUnit() { systemctl start "$@"; }
    stopUnit() { systemctl stop "$@"; }
    restartUnit() { systemctl restart "$1"; }
    unitActive() { systemctl is-active --quiet "$1"; }
  '',
}:
pkgs.writeShellApplication {
  name = "capsule-reset-home";
  runtimeInputs = [pkgs.coreutils pkgs.gawk];
  passthru = {inherit scrubPaths;};
  text = ''
    ${tools}

    home=${home}
    slice=user-${toString agentUid}.slice
    scrubPaths=(${lib.concatStringsSep " " scrubPaths})

    usage() { echo "usage: capsule-reset-home [--scrub]" >&2; exit 2; }
    scrub=
    case $# in
      0) ;;
      1) [ "$1" = --scrub ] || usage; scrub=1 ;;
      *) usage ;;
    esac

    # sec-2: a session is work unless a getty logged it in or it is a user
    # manager. Everything else refuses, including a class nobody has seen here.
    workingSessions() {
      agentSessions | awk '$3 != "login" && $4 != "manager" && $4 != "manager-early"'
    }

    # 1. Refuse on evidence of work, before anything is stopped.
    working=$(workingSessions)
    if [ -n "$working" ]; then
      echo "capsule-reset-home: agent is working, so nothing was stopped:" >&2
      echo "$working" >&2
      exit 3
    fi

    # 2. Quiesce what that test cannot see. Every getty autologins the agent, and
    # one left running logs it back in within seconds, so all of them stop, and
    # all of them come back however this exits.
    gettyList=$(activeGettys)
    gettys=()
    [ -z "$gettyList" ] || mapfile -t gettys <<<"$gettyList"
    # Keeps the status it was called with, so a 3 or a 4 survives the restart.
    restoreGettys() {
      local rc=$?
      [ ''${#gettys[@]} -eq 0 ] || startUnit "''${gettys[@]}" ||
        echo "capsule-reset-home: could not start the gettys again: ''${gettys[*]}" >&2
      exit "$rc"
    }
    trap restoreGettys EXIT
    [ ''${#gettys[@]} -eq 0 ] || stopUnit "''${gettys[@]}"

    # 3. The slice holds the autologins, the user manager and anything it ran.
    stopUnit "$slice"
    if unitActive "$slice"; then
      echo "capsule-reset-home: $slice is still active after its stop, so the agent could not be kept out" >&2
      exit 4
    fi

    # 4. No trailing slash: a `$HOME` that is a symlink loses the link only.
    rm -rf -- "$home"

    # 5. A RemainAfterExit oneshot, so a restart re-runs the seed, which makes
    # `$HOME` again as the agent's. It runs as root in its own unit and opens no
    # session, so it does not start the slice.
    restartUnit capsule-seed

    # 6. sshd makes no host keys itself; `sshd-keygen` does, only while one is
    # missing, and is inactive again after the boot that ran it. A restart of
    # sshd replaces the listener and leaves established sessions (`ASM-002`).
    if [ -n "$scrub" ]; then
      rm -f -- "''${scrubPaths[@]}"
      startUnit sshd-keygen
      restartUnit sshd
    fi

    # 7. Nothing prevented a login during steps 3-6; this is where it shows.
    if unitActive "$slice"; then
      echo "capsule-reset-home: an agent login arrived during the reset; its \$HOME may be partial, so run it again" >&2
      exit 4
    fi

    echo "capsule-reset-home: reset $home''${scrub:+, and scrubbed the identity of this guest}"
  '';
}
