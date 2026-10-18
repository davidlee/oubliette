# A room: a guest that is not a capsule (design sec-5, Plan E/F). Several
# declared people — or one agent — ssh'd into one box, each in a home of their
# own on one volume. What makes it reachable is the door (`vm/door.nix`), the
# same one a capsule has; what this adds is sizes, the volume at `/home`, one
# normal user per declared user, and a first-boot seed that makes their homes.
#
# What it deliberately lacks, against `vm/capsule.nix`: no egress (a room has
# no uplink), so no proxy; no target, so no tool floor, no checkout, no marker
# on the kernel command line; and no `reset-home`. Nothing here learns what a
# room is for — `room.users` and `room.sizes` are values (POL-002).
{
  lib,
  pkgs,
  room,
  ...
}: let
  users = lib.attrNames room.users;
in {
  # Host keys on the volume, beside the homes, for the reason the door gives.
  imports = [(lib.modules.importApply ./door.nix {hostKeyDir = "/home/.ssh-host-keys";})];

  # No default for any size: a room that omits one fails here, at eval
  # (SL-005 PHASE-01 EX-5). Exec on `/home` stays permitted (DEC-037).
  microvm = {
    inherit (room.sizes) vcpu mem;
    volumes = [
      {
        image = "room-home.img";
        mountPoint = "/home";
        size = room.sizes.volume;
      }
    ];
  };

  # One login per declared user, by key only, under the uid the record carries
  # (RSK-012): the root fs is tmpfs, so an undeclared uid is allocated afresh
  # every boot in name order, and `/home` keeps the old numbers. Persisting
  # NixOS's uid map would not help — it lives on the root fs, and `/home` is
  # mounted after activation. `createHome = false` for the same reason: the
  # seed makes the home instead. No groups: nothing here is sudo.
  users.users =
    lib.mapAttrs (user: decl: {
      inherit (decl) uid;
      isNormalUser = true;
      home = "/home/${user}";
      createHome = false;
      openssh.authorizedKeys.keys = decl.keys;
    })
    room.users;

  # `vm/common.nix` autologs root on the console and a capsule forces `agent`;
  # a room forces nobody, so root stays reachable by key alone (POL-001 limb 3,
  # RV-014 F-2). `mkForce`, since a plain `null` conflicts with common's value.
  services.getty.autologinUser = lib.mkForce null;

  # The same lock a capsule takes, for the reason `vm/capsule.nix` gives.
  security.lockKernelModules = true;
  security.protectKernelImage = true;

  # First boot, and every boot after: the host-key directory and one home per
  # declared user, on the volume. `capsule-seed`'s shape, without a repository.
  systemd.services.room-seed = {
    description = "Seed /home with each declared user's home";
    wantedBy = ["multi-user.target"];
    after = ["local-fs.target"];
    before = ["sshd.service" "getty@ttyS0.service"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    path = [pkgs.coreutils];
    script =
      ''
        install -d -m 0700 /home/.ssh-host-keys
      ''
      + lib.concatMapStrings (u: let
        q = lib.escapeShellArg u;
      in ''
        install -d -m 0700 -o ${q} -g users /home/${q}
      '')
      users;
  };
}
