# A room's door (SL-008 design sec-3, `DEC-055`): the one list of ssh options
# that reaches room `<r>`, and its two renders. Built once in host/programs.nix,
# for the room channel (host/room-git.nix), the front end's human door
# (host/cli.nix, through `roomTrust`) and its `forget-host-key`.
#
# **One trust store per room** (`DEC-047`): `$state/room/<r>/known_hosts`, the
# key filed under `HostKeyAlias=room-<r>`. **And no other** (RV-023 F-2): ssh
# reads `/etc/ssh/ssh_known_hosts*` beside `UserKnownHostsFile` unless told not
# to, so `GlobalKnownHostsFile none` is part of every door, or a key this host's
# global file holds would be trusted for a room that never showed it.
#
# `checking` is the one parameter. Oubliette's own doors pass `accept-new`, which
# is sound because the path is a socket this host created into a VM this host
# booted: it learns an unknown key and refuses a changed one. Never the slot
# relaxation (`guestSsh.args`), which checks nothing (POL-001).
#
# **One list, two renders, and neither is a spelling of the other.** `words` is
# the list as `-o "Name=value"` words for an argv array, and takes *shell
# expressions* (`$room`, `$sock`), every value double-quoted so it expands at
# run time. `config` is the list as ssh_config lines, and takes *nix strings*.
#
# `aliasOf` is the key's name in the store, not the room's network namespace,
# though rooms.nix spells that `room-<r>` too: the two answer different
# questions and are not one value.
{
  lib,
  guestSsh,
  # A store path, so the door's ProxyCommand needs nothing on `PATH` (`DEC-053`).
  socat,
  # `rooms.stateDirOf`: the room's host-side state directory (DEC-047).
  stateDirOf,
}: rec {
  aliasOf = room: "room-${room}";

  optionsOf = {
    checking,
    room,
    socket,
    knownHosts,
  }: [
    {
      name = "StrictHostKeyChecking";
      value = checking;
    }
    {
      name = "HostKeyAlias";
      value = aliasOf room;
    }
    {
      name = "UserKnownHostsFile";
      value = knownHosts;
    }
    {
      name = "GlobalKnownHostsFile";
      value = "none";
    }
    {
      name = "ProxyCommand";
      value = guestSsh.proxyCommand {inherit socat socket;};
    }
  ];

  words = args: lib.concatMapStringsSep " " (o: ''-o "${o.name}=${o.value}"'') (optionsOf args);
  config = args: "Host *\n" + lib.concatMapStrings (o: "  ${o.name} ${o.value}\n") (optionsOf args);

  # The room's trust store, the file the door names: the one spelling of its
  # name, for the channel, the front end's door and its `forget-host-key`.
  # `knownHostsIn` takes the room's directory, for a caller that makes it;
  # `knownHostsOf` the state root and the room, for a caller that makes nothing.
  # Shell expressions, as `stateDirOf`'s are.
  knownHostsIn = roomDir: "${roomDir}/known_hosts";
  knownHostsOf = state: room: knownHostsIn (stateDirOf state room);
}
