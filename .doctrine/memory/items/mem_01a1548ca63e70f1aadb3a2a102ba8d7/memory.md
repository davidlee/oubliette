Verified 2026-10-20 (SL-008 plan time), openssh 10.5p1, socat 1.8.1.3, inside a
`nix-build` runCommand (sandbox on, build dir `/build`).

Fixture: `ssh-keygen -t ed25519 -N ''` host key; sshd config `HostKey <k>`,
`UsePAM no`, `StrictModes no`, `PidFile none`, `AuthorizedKeysFile none`;
`socat UNIX-LISTEN:<sock>,fork EXEC:"$(command -v sshd) -i -f <cfg> -e" &`.
Client reaches it with `ProxyCommand=socat - UNIX-CONNECT:<sock>`.

What it distinguishes, all exit 255:
- strict, no key known → `Host key verification failed.`
- accept-new → `Permanently added '<alias>'`, key written under `HostKeyAlias`, then `Permission denied`
- strict, key known → `Permission denied` (key accepted, auth refused)

So host-key checking, `UserKnownHostsFile` and `HostKeyAlias` of a shipped door
are pinnable by a `*Cases` suite. Before this, room-git-cases.nix's header
listed "accept-new writing the room's known_hosts" as unreachable by any case.
Under stdenv's `set -e`, capture each expected ssh failure (`|| rc=$?`).
Auth itself (an actual push landing) still needs a real key and user.
