# A socket nobody's and an sshd that accepts nobody: the fixture a suite stands
# behind a door to reach as far as authentication (RV-023 F-5,
# `mem.pattern.oubliette.fixture-sshd-in-the-build-sandbox`). Spliced by
# `roomGitCases` (host/room-git-cases.nix) and `roomClientCases`
# (host/room-client-cases.nix).
#
# A shell **fragment** rather than a program, because both suites need its
# functions in their own shell: it inherits the build's `set -e` and its
# `nativeBuildInputs` (socat, openssh), and it sets no trap — a suite says
# `trap stopListeners EXIT` itself, once it has a listener to stop.
#
# - `serve SOCK TEXT` runs `TEXT` behind a listener at `SOCK`, once per
#   connection, and returns when the socket exists.
# - `stopListeners` kills and waits by pid, so a failing case cannot hang the
#   build on one.
# - `sshd_fixture DIR` makes a host key and an sshd config under `DIR`, and sets
#   `sshd_exec` to the command that serves one connection on stdio.
{pkgs}: ''
  listeners=()
  serve() {
    printf '#!${pkgs.runtimeShell}\n%s\n' "$2" >"$1.sh"
    chmod +x "$1.sh"
    socat UNIX-LISTEN:"$1",fork EXEC:"$1.sh" &
    listeners+=("$!")
    for _ in $(seq 50); do [ -S "$1" ] && return 0; sleep 0.1; done
    echo "FAIL listener $1 never made its socket" >&2
    exit 1
  }
  stopListeners() {
    for p in "''${listeners[@]}"; do kill "$p" 2>/dev/null || true; done
    for p in "''${listeners[@]}"; do wait "$p" 2>/dev/null || true; done
  }
  sshd_fixture() {
    ssh-keygen -q -t ed25519 -N "" -f "$1/hostkey"
    printf '%s\n' "HostKey $1/hostkey" "UsePAM no" "StrictModes no" \
      "PidFile none" "AuthorizedKeysFile none" >"$1/sshd_config"
    sshd_exec="exec $(command -v sshd) -i -f $1/sshd_config -e"
  }
''
