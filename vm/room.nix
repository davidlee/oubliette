# A room: a guest that is not a capsule (design sec-5, Plan E/F). Several
# declared people — or one agent — ssh'd into one box, each in a home of their
# own on one volume. What makes it reachable is the door (`vm/door.nix`), the
# same one a capsule has; what this adds is sizes, the volume at `/home`, one
# normal user per declared user, and a first-boot seed that makes their homes.
#
# Every room, with repos or without, renders a **base** (DEC-052): one
# `buildEnv` of the floor (`git bash coreutils-full which`) and the extras the
# room selects from `fragments.nix`, on `systemPackages` and at
# `/etc/room/base`. No `ignoreCollisions`: a fragment that collides with the
# floor fails the build. So a repo-less room's image is no longer what it was
# before repos existed — it gains the floor, and whatever it selects.
#
# A room that declares repos (SL-006 design sec-3) also gets a second volume at
# `/work` (`targets.volumePath`), one `git init`ed clone per repo at its
# target's `guestPath`, and `session`, which runs a command in one repo over the
# tree rendered under `/etc/room/repo` — per repo a `clone` link and, for a
# target with a tool set, a `tools` link — with the base behind the repo's
# tools. A repo-less room renders none of that.
#
# What it deliberately lacks, against `vm/capsule.nix`: no egress (a room has
# no uplink), so no proxy; no repo's tool set on the login `PATH` — one is
# reached only through `session` (DEC-044), and only the base is everyone's
# (DEC-052); no marker on the kernel command line; and no `reset-home`. Nothing
# here learns what a room is for — `room.users`, `room.sizes`, `room.repos` and
# `room.extras` are values (POL-002).
{
  lib,
  pkgs,
  room,
  # The derived targets (targets/default.nix), their flakes, the one `session`
  # construction (mkfleet.nix) and the work branch: read only for a room with
  # repos.
  targets,
  targetFlakes,
  session,
  workBranch,
  # The fragment sources (mkFleet's `flavour.sources`), which a room's extras
  # are built from, as a capsule's are.
  flavour,
  ...
}: let
  # The vocabulary, resolved against this guest's pkgs, as `vm/capsule.nix` does.
  fragments = import ../fragments.nix {
    inherit pkgs;
    inherit (flavour) sources;
  };
  # The room's base (DEC-052): the floor and its extras, one tree. Collisions
  # fail the build on purpose.
  base = pkgs.buildEnv {
    name = "room-base";
    paths = fragments.compose {
      floor = with pkgs; [git bash coreutils-full which];
      inherit (room) extras;
    };
  };
  users = lib.attrNames room.users;
  repos =
    if room.repos == null
    then []
    else room.repos.targets;
  # A repo's tool set, by `vm/capsule.nix`'s lookup, or `null` for a target
  # with none.
  toolsOf = r: let
    target = targets.byName.${r.name};
  in
    if target.toolsPackage == null
    then null
    else targetFlakes.${r.name}.packages.${pkgs.stdenv.hostPlatform.system}.${target.toolsPackage};
in {
  # Host keys on the volume, beside the homes, for the reason the door gives.
  imports = [(lib.modules.importApply ./door.nix {hostKeyDir = "/home/.ssh-host-keys";})];

  # No default for any size: a room that omits one fails here, at eval
  # (SL-005 PHASE-01 EX-5). Exec on `/home` stays permitted (DEC-037).
  microvm = {
    inherit (room.sizes) vcpu mem;
    volumes =
      [
        {
          image = "room-home.img";
          mountPoint = "/home";
          size = room.sizes.volume;
        }
      ]
      # The clones' volume, at `/work` (DEC-043).
      ++ lib.optional (room.repos != null) {
        image = "room-work.img";
        mountPoint = targets.volumePath;
        size = room.sizes.work;
      };
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

  # The base for every room, and `session` for running in a repo (DEC-044,
  # DEC-049, DEC-052). No repo's tool set: those are reached only through the
  # tree below.
  environment.systemPackages = [base] ++ lib.optional (room.repos != null) session;

  # `/etc/room/base`, which `session` puts behind a repo's tools, and the tree
  # `session` reads, links and nothing else: a `clone` per repo, its
  # `guestPath` as a string so the link points out of the store rather than at
  # a copy, and a `tools` for a repo whose target has a set.
  environment.etc =
    {"room/base".source = base;}
    // lib.listToAttrs (lib.concatMap (r: let
      tools = toolsOf r;
    in
      [(lib.nameValuePair "room/repo/${r.name}/clone" {source = r.guestPath;})]
      ++ lib.optional (tools != null)
      (lib.nameValuePair "room/repo/${r.name}/tools" {source = tools;}))
    repos);

  # First boot, and every boot after: the host-key directory and one home per
  # declared user, on the volume. `capsule-seed`'s shape. With repos, then one
  # clone per repo on `/work`, made by the repos' user and `git init`ed only
  # when it has no `.git`, so nothing here touches a clone again (DEC-043).
  systemd.services.room-seed = {
    description = "Seed /home with each declared user's home";
    wantedBy = ["multi-user.target"];
    after = ["local-fs.target"];
    before = ["sshd.service" "getty@ttyS0.service"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    path = [pkgs.coreutils] ++ lib.optionals (room.repos != null) [pkgs.git pkgs.util-linux];
    script =
      ''
        install -d -m 0700 /home/.ssh-host-keys
      ''
      + lib.concatMapStrings (u: let
        q = lib.escapeShellArg u;
      in ''
        install -d -m 0700 -o ${q} -g users /home/${q}
      '')
      users
      # `HOME` explicitly: `runuser` keeps root's, and git reading
      # `/root/.gitconfig` as the user is a fatal EACCES.
      + lib.concatMapStrings (r: let
        u = lib.escapeShellArg room.repos.user;
        dir = lib.escapeShellArg r.guestPath;
      in ''
        install -d -m 0700 -o ${u} -g users ${dir}
        [ -e ${dir}/.git ] ||
          runuser -u ${u} -- env HOME=${lib.escapeShellArg "/home/${room.repos.user}"} \
            git init -q --initial-branch=${lib.escapeShellArg workBranch} ${dir}
      '')
      repos;
  };
}
