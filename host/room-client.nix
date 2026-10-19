# A room client's bundle (SL-008 design sec-4, `DEC-057`): the door to room
# `<r>` for a client on this host — a human's ssh or git, an agent's jail —
# as `capsule-room-client-<r>`:
#
#   etc/ssh_config   the door as ssh_config lines (host/room-door.nix's `config`)
#   bin/ssh          openssh's ssh, linked rather than wrapped
#
# **`Host *`, and no user and no identity**: the file is the door, so whatever
# name a client gives the room — `room-<r>`, the guest's address, `<r>` — is the
# caller's, and so are the login and the key. The ProxyCommand is socat by store
# path (`DEC-053`), so the bundle needs nothing on the client's `PATH`.
#
# **Strict checking, and it never writes** (`DEC-056`): `checking = "yes"` over
# the room's one trust store (`DEC-047`), so a client refuses a room whose key
# no oubliette door has learned — before the first push, and again after
# `forget-host-key` — and leaves learning it to those doors, which are
# `accept-new`.
#
# **`binds`, what a jail must mount read-only to use it** (`DEC-056`): the
# door's root, not the door's own directory — that is the relay's
# RuntimeDirectory and goes on every stop, so a bind of it would point at a dead
# inode; the module makes the root at boot (host/services.nix) — and the room's
# state directory, which holds the trust store.
#
# Precondition: run as the module's owner (`DEC-037`), who alone may read the
# trust store and connect to the socket. It ignores `CAPSULE_STATE` (design
# sec-7): the store is the declared root's.
#
# Nothing in it is spelled: every value is the record's, rooms.nix's or
# room-door.nix's, and `stateDir` is an argument so `roomClientCases` can build
# the same bundle at a root the sandbox can write.
{
  pkgs,
  lib,
  roomDoor,
  rooms,
  stateDir,
}: r: let
  knownHosts = roomDoor.knownHostsOf stateDir r.name;
  config = pkgs.writeText "capsule-room-client-${r.name}-ssh_config" (roomDoor.config {
    checking = "yes";
    room = r.name;
    inherit (r) socket;
    inherit knownHosts;
  });
  binds = [(rooms.doorRootOf r.socket) (rooms.stateDirOf stateDir r.name)];
in
  pkgs.runCommand "capsule-room-client-${r.name}" {
    passthru = {
      room = r.name;
      inherit (r) socket;
      inherit knownHosts config binds;
      hostKeyAlias = roomDoor.aliasOf r.name;
    };
  } ''
    mkdir -p $out/etc $out/bin
    ln -s ${config} $out/etc/ssh_config
    ln -s ${lib.getExe' pkgs.openssh "ssh"} $out/bin/ssh
  ''
