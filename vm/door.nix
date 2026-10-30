# The door: what every confined guest is reached by (DEC-034, design sec-5).
# The tap link, sshd, and root's keys — and nothing about what the guest is for.
#
# Imported by `vm/capsule.nix` and, from PHASE-05, `vm/room.nix`. A function of
# the one thing the importer must say, applied with
# `lib.modules.importApply ./door.nix {inherit hostKeyDir;}`:
#
#   hostKeyDir  a directory on the importer's volume. /etc is tmpfs, so a host
#               key kept there would be regenerated every boot; the importer
#               names where it is parked instead.
#
# Reads `net` and `access` and no target: a room has none (sec-5).
{hostKeyDir}: {
  lib,
  net,
  access,
  ...
}: {
  microvm.interfaces = [
    {
      type = "tap";
      id = net.tap;
      mac = net.mac;
    }
  ];

  # No resolver in the guest, which the boundary claim has always said and this
  # makes true: networkd pulled in systemd-resolved, leaving a stub on
  # 127.0.0.53 with no configured upstream and no route to one — it could only
  # ever SERVFAIL, but it answered, and a client that retries a stub is a client
  # that hangs. Names are resolved by the host's proxy instead, as the host, so
  # guest lookups inherit whatever the host resolves through (here: resolved ->
  # stubby -> ControlD over DoT). Nothing guest-side can bypass that, because
  # nothing guest-side has a route to a nameserver.
  services.resolved.enable = false;

  # Point-to-point link only. No gateway, no resolver: everything outbound
  # goes through the host's allowlist proxy, which does its own DNS.
  #
  # The static address is needed because `vm/common.nix` sets
  # `networking.useDHCP = false` (and `hello` imports that and not this), so
  # without it a guest never answers at `net.guest` (RV-014 F-1).
  systemd.network = {
    enable = true;
    networks."10-capsule" = {
      matchConfig.MACAddress = net.mac;
      address = ["${net.guest}/${toString net.prefix}"];
      networkConfig.DHCP = "no";
      linkConfig.RequiredForOnline = "carrier";
    };
  };

  # A host->guest door, so the console isn't the only session. It widens
  # nothing outbound: the guest still has no route past the proxy. The tap is
  # point-to-point, so this is reachable from this host and nowhere else.
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "prohibit-password";
      # Every connection through the door comes from `net.host`, so sshd's
      # per-source penalties can only ever lock out this host: a run of
      # banner-only pre-flights (host/room-git.nix) adds a `noauth` penalty
      # each, and about fifteen in a row refuse the next push (ISS-027).
      PerSourcePenaltyExemptList = net.host;
    };
    # /etc is tmpfs here, so keys kept there would be regenerated every boot
    # and your known_hosts would fight it. Park them on the volume.
    hostKeys = [
      {
        path = "${hostKeyDir}/ssh_host_ed25519_key";
        type = "ed25519";
      }
    ];
  };

  # Root is reachable by key from the host only — no password, no sudo, no su
  # for the agent. Admin is a thing you do from outside the jail.
  #
  # `access.stopKey` is the public half of the host's stop key: what a
  # `microvm@<name>` unit's `ExecStop` presents to ask this guest to reboot,
  # which is the only clean stop firecracker leaves available (host/halt.nix,
  # NOTES item 11). Root's alone — an unprivileged session cannot reboot
  # anything, so giving it to the agent would only widen what a key on the host
  # reaches.
  #
  # Not the human's key, because the unit has no agent and no way into her home;
  # not in the store, because the private half is a secret; and required rather
  # than optional, because a guest that quietly omits it is one whose volume
  # gets power-cut — and it would say so for the first time at host shutdown.
  users.users.root.openssh.authorizedKeys.keys = access.adminKeys ++ [access.stopKey];
}
