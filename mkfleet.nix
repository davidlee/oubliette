# oubliette's own inputs — never the caller's. What a fleet is built *with*:
# the guest's nixpkgs, microvm.nix, and the governance CLI the devshell carries.
{
  nixpkgs,
  microvm,
  # The governance CLI the devshell carries (design sec-1's `doctrine*`): an
  # input of oubliette's, not a target. Design sec-10's curry names only the two
  # above; this one is closed over for the same reason as `microvm`.
  doctrine,
}:
# The caller's declarations, one argument per owner (design sec-10), all
# required: an omitted one fails at eval naming it, and an unexpected one is
# refused rather than ignored.
{
  # The repos this host confines, each `{decl; flake}`: a target's declaration
  # paired with the flake its tool set comes from. **Shadowed below** by the
  # derived set every factory here expects (targets/default.nix) — same axis,
  # derived form — so the pairs are reachable only as `declared.targets`.
  targets,
  # Which slots exist and the fabric they sit on: the declaration
  # `capsules.nix` is applied to.
  fleet,
  # The policy vocabulary (a consumer's policies.nix has this shape).
  policies,
  # Tap name, both addresses, MAC and ports, which the host-side module needs
  # too.
  net,
  # The host operator's half of every guest's tool set: `extras`, the fragments
  # composed into each image, and `sources`, the flake inputs they come from
  # (fragments.nix, docs/contract-flavour.md).
  flavour,
  # Who may reach a guest and what is put on its volume: `adminKeys`,
  # `stopKey`, and `injections`, the setup function `{volumePath}: [injection]`
  # — one value read by the host programs and by the guest's scrub list.
  access,
  # `{target; fabric}`: the one real target the probes are about, and the
  # names and addressing a probe's egress fabric is built from.
  probe,
  # Which rooms exist: guests that are not slots (rooms.nix). `{}` for none —
  # required, so a consumer says so.
  rooms,
  # Where this host's declarations live. Threaded to the module and read by
  # nothing yet (RV-012 F-11).
  fleetPath,
  # Where this host keeps its state: assignment records, quarantines, a room's
  # trust store (DEC-054). A flake argument rather than a module option, so a
  # host flake that does not evaluate the module still reads the same root.
  # Required, with no default (POL-003), and refused unless it is a safe
  # absolute path (state-dir.nix). **Shadowed below** by the checked value, so
  # the raw one is reachable only as `declared.stateDir`.
  stateDir,
} @ declared: let
  system = "x86_64-linux";
  pkgs = nixpkgs.legacyPackages.${system};
  inherit (nixpkgs) lib;

  # The declared root, checked. It throws state-dir.nix's reason wherever it is
  # read — the module, both front ends, the programs, the probes — and only
  # there: an output that never reads the root (`fleetCases`, say) still
  # evaluates, which is fleet.nix's `slotImages` laziness again.
  stateDir = (import ./state-dir.nix {inherit lib;} declared.stateDir).value;

  # The host module, bound once: `hostModule` imports it and `nixosModules` exports it.
  capsulePerimeter = import ./host/services.nix {
    inherit net targets capsules policies workBranch fleetPath stateDir;
    inherit (access) injections;
    rooms = roomDecision;
  };

  # The target-shaped settings that follow from each declared target
  # (targets/default.nix), and each target's flake, for its tool set — both
  # derived from the one list, so the targets and their flakes cannot name
  # different sets and there is nothing to refuse (fleet.nix). Nothing below
  # spells a target detail twice, and nothing generic imports a target — it is
  # handed down as an argument (SL-003 design sec-2).
  targets = import ./targets (lib.mapAttrs (_: t: t.decl) declared.targets);
  targetFlakes = lib.mapAttrs (_: t: t.flake) declared.targets;

  probeTarget = probe.target;
  probeFabric = probe.fabric;
  probeSubject = targets.byName.${probeTarget};

  # Which capsules exist, and each one's namespace, socket and uplink: the
  # function (capsules.nix) applied to the caller's `fleet`. Under netns the
  # guest-facing link is *not* in here — it is identical in every capsule, so
  # it stays in `net`.
  capsules = import ./capsules.nix {inherit policies;} fleet;

  # Each declared room's guest record — name, namespace, socket, no uplink —
  # the function (rooms.nix) applied to the caller's `rooms` and the declared
  # slot names, which a room may not take. Not called `rooms`: that is the
  # declaration, and this is what it decides — bound whole for the host module,
  # which takes it as rooms.nix returns it, and its records once for the rest.
  # `fragmentNames` is the vocabulary's names, read only for a room that
  # declares extras.
  roomDecision = import ./rooms.nix {inherit lib;} {
    inherit rooms targets policies;
    fragmentNames =
      lib.attrNames
      (import ./fragments.nix {
        inherit pkgs;
        inherit (flavour) sources;
      }).vocabulary;
    slotNames = lib.attrNames fleet.slots;
  };
  roomRecords = roomDecision.instances;
  inherit (roomDecision) readersGroup;

  # The fabric the case suites run on (guardCases, netnsCases, policyCases,
  # volumeCases, volumeRootCases): the same function, applied to a declaration
  # that is no host's. No slots of its own — each suite declares its instances
  # through `instancesOf`, as shapes the declaration's refusals would reject —
  # so the refusals are vacuous and the fabric is independent of whoever calls
  # this. The numbers equal what this host declared at SL-004, so the move was
  # derivation-neutral; nothing ties them, and changing them moves five suites
  # in every caller's build. Not a NOTES item 38 borrower: a suite runs in a
  # build sandbox and creates no link.
  casesCapsules = import ./capsules.nix {inherit policies;} {
    slots = {};
    addressing = {
      uplinkNet = "10.100.0.0/16";
      egressAddr = "10.101.0.2";
      egressPeerAddr = "10.101.0.1";
    };
    volumeReserve = 20 * 1024 * 1024 * 1024;
  };

  # Where a collected exhibit lives and what its refs are called. Bound here
  # rather than imported at each use because there are three now — the token
  # bound in `snapshotCases`, and both probes that assert a collect landed
  # where it was sent. A probe that spells a ref convention is a probe that
  # keeps asserting the old one after the convention moves, which is what
  # `refs/capsule/<name>/heads/` cost (NOTES item 38).
  quarantine = import ./host/quarantine.nix;

  # The branch a capsule's checkout sits on, everywhere and always. Not a value
  # file of its own and not a field of any of the three above: it is not
  # addressing, it is not a slot's, and it is emphatically not the target's —
  # `target.nix`'s `defaultBranch` was deleted rather than given the run-time
  # override it lacked, because a name that identifies the work is not project
  # state and two slices of one project at once is what shows it (plan-d L13,
  # docs/contract-target.md). Two consumers, the guest's seed and
  # `capsule-provision`, and they must agree — so it is spelled here, where the
  # wiring already is, and threaded to both.
  workBranch = "work";

  # Where a capsule's way in lives, for the probes' throwaway capsules — which
  # are not instances, and must not spell that path a second time.
  inherit (capsules) socketOf;

  # `hostName`, not the instance's name: the hostname is in the closure, so a
  # per-instance one is a per-instance image (docs/plan-c-implementation.md).
  # `args` are the specialArgs a VM needs beyond the fleet's — for a capsule
  # image, its target and that target's flake.
  mkVm = hostName: module: args:
    lib.nixosSystem {
      inherit system;
      specialArgs = {inherit net workBranch access flavour;} // args;
      modules = [
        microvm.nixosModules.microvm
        ./vm/common.nix
        module
        {networking.hostName = hostName;}
      ];
    };

  # The caller's declarations bound to images: one image per target, and each
  # slot bound to the image its declared `profile` names (fleet.nix, SL-003
  # sec-3). Applied once, here, to the caller's values. Two slots with one
  # profile get the same value rather than a rebuild of it, so identical modules
  # make an identical derivation and "one image per target, N capsules" is
  # structural rather than a claim.
  bound = import ./fleet.nix {inherit lib mkVm;} {
    inherit targets targetFlakes capsules probeTarget;
  };

  # What `vm <name>` can boot, and so what `packages` carries by name: the
  # smoke test and the slots' images. Not the rooms — a room runs only on the
  # module path (design sec-1), so it gets no devshell runner to be booted from.
  devshellVms =
    {
      # Smoke test: does firecracker boot at all on this host. No network.
      hello = mkVm "hello" ./vm/hello.nix {};
    }
    # `capsule` is the probe target's image under the hostname it carries — as
    # against a *slot*, which is where a capsule's namespace, socket and units
    # live. It exists because a runner is `microvm@<hostName>` in the process
    # table: every probe matches on that string and builds `.#capsule` to get
    # it. And an attribute per declared slot, because `microvm -c <name> -f .`
    # resolves `nixosConfigurations.<name>` (the CLI appends that itself and
    # takes no fragment).
    // bound.vms;

  # One image per declared room, under hostName `capsule` like every image, so
  # a running room is `microvm@capsule` and every probe's refusal sees it
  # (DEC-032). A room's name is its `nixosConfigurations` attribute, which is
  # what `microvm -c <room>` resolves — and the only way one is created, since
  # it is not in `devshellVms`.
  # Every room is handed the targets, their flakes and `session`, as a slot is
  # handed its target and flake (fleet.nix); a room without repos reads none.
  roomVms = lib.mapAttrs (_: room: mkVm "capsule" ./vm/room.nix {inherit room targets targetFlakes session readersGroup;}) roomRecords;

  # The room's one per-repo launcher, built once at its default root: every room
  # with repos ships this store path, and `sessionCases` runs the same value.
  session = import ./vm/session.nix {inherit pkgs;};

  # Every `nixosConfigurations` attribute: `hello`, `capsule`, each slot and
  # each room (DEC-032). A target's image is never one of its own: it builds as
  # `packages.image-<target>`, so `microvm -c` cannot create one outside a slot.
  vms = devshellVms // roomVms;

  # What a room's evaluated image must say, as `{ok; reason;}` per rule. Each
  # predicate reads an option the pinned nixpkgs defines, and a user's are
  # guarded on presence first, so a missing user is its reason and not a
  # missing-attribute abort. None is defaulted to its passing value.
  roomChecks = name: cfg: let
    c = cfg.config;
    room = roomRecords.${name};
    check = ok: rule: {
      inherit ok;
      reason = "roomImages: room '${name}': ${rule}";
    };
    # The repos user and its readers share the readers' group, and only when
    # there are readers (IMP-023); everyone else is in none.
    reading = room.repos != null && room.repos.readers != [];
    groupsOf = u:
      lib.optional (reading && builtins.elem u ([room.repos.user] ++ room.repos.readers)) readersGroup.name;
    userChecks = u: let
      present = c.users.users ? ${u};
      user = c.users.users.${u};
    in
      [(check present "declared user '${u}' is not a user of the image (sec-5)")]
      ++ lib.optionals present [
        (check user.isNormalUser "user '${u}' is not a normal user (sec-5)")
        (check (user.openssh.authorizedKeys.keys == room.users.${u}.keys)
          "user '${u}' does not carry exactly its declared keys (sec-5)")
        (check (user.uid == room.users.${u}.uid)
          "user '${u}' has uid ${builtins.toJSON user.uid}, not the record's uid ${toString room.users.${u}.uid}; an allocated one moves with name order (RSK-012)")
        (check (user.extraGroups == groupsOf u)
          "user '${u}' has extra groups ${builtins.toJSON user.extraGroups}, not ${builtins.toJSON (groupsOf u)}; a room grants only the readers' group (POL-001 limb 3, IMP-023)")
      ];

    # The work volume and the tree `session` reads (sec-3). A repo-less room is
    # asserted to have neither; it still gains the base, as every room does
    # (DEC-052).
    work = lib.filter (v: v.mountPoint == targets.volumePath) c.microvm.volumes;
    etc = c.environment.etc;
    tree = lib.filter (lib.hasPrefix "room/repo/") (lib.attrNames etc);
    onPath = map toString c.environment.systemPackages;
    repoChecks = r: let
      key = leaf: "room/repo/${r.name}/${leaf}";
      clone = etc.${key "clone"} or null;
      tools = etc.${key "tools"} or null;
      hasSet = targets.byName.${r.name}.toolsPackage != null;
    in
      [
        # A string, never a path: a path would copy into the store (sec-3).
        (check (clone != null && clone.source == r.guestPath)
          "repo '${r.name}': /etc/${key "clone"} is not a link to its guestPath ${r.guestPath} (DEC-049)")
        (check ((tools != null) == hasSet)
          "repo '${r.name}': /etc/${key "tools"} is ${
            if tools == null
            then "absent"
            else "present"
          }, but its target's toolsPackage is ${
            if hasSet
            then "set"
            else "null"
          } (DEC-049)")
      ]
      ++ lib.optional (tools != null)
      (check (!builtins.elem (toString tools.source) onPath)
        "repo '${r.name}': its tool set is in environment.systemPackages, where two repos' tools would meet on one PATH (DEC-052)");
    repoRules =
      if room.repos == null
      then [
        (check (work == [])
          "a volume is mounted at ${targets.volumePath}, but the room declares no repos (DEC-043)")
        (check (tree == [])
          "/etc carries ${builtins.toJSON tree}, but the room declares no repos (DEC-049)")
      ]
      else
        [
          (check (lib.any (v: v.image == "room-work.img" && v.size == room.sizes.work) work)
            "no volume 'room-work.img' of sizes.work at ${targets.volumePath} (DEC-043)")
        ]
        ++ lib.concatMap repoChecks room.repos.targets;
  in
    [
      (check (c.networking.hostName == "capsule")
        "hostName is '${c.networking.hostName}', not 'capsule' (DEC-032)")
      (check (etc ? "room/base" && builtins.elem (toString etc."room/base".source) onPath)
        "/etc/room/base is absent or its base is not in environment.systemPackages (DEC-052)")
      (check (c.services.getty.autologinUser == null)
        "the console autologs '${toString c.services.getty.autologinUser}'; a room autologs nobody (POL-001 limb 3, RV-014 F-2)")
      (check (!c.networking.useDHCP
        && (c.systemd.network.networks."10-capsule".networkConfig.DHCP or null) == "no")
      "DHCP is on, or the door's static link is missing (RV-014 F-1)")
      (check (lib.any (v: v.image == "room-home.img" && v.mountPoint == "/home") c.microvm.volumes)
        "no volume 'room-home.img' at /home (sec-5)")
      (check (c.users.users.root.openssh.authorizedKeys.keys == access.adminKeys ++ [access.stopKey])
        "root's keys are not exactly the admin keys and the stop key (POL-001 limb 3)")
      (check (c.security.lockKernelModules && c.security.protectKernelImage)
        "kernel modules or the kernel image are not locked (vm/room.nix)")
    ]
    ++ lib.concatMap userChecks (lib.attrNames room.users)
    ++ lib.optional reading
    (check ((c.users.groups.${readersGroup.name}.gid or null) == readersGroup.gid)
      "the readers' group '${readersGroup.name}' is absent or its gid is not ${toString readersGroup.gid}; an allocated one moves with name order (RSK-012, IMP-023)")
    ++ repoRules;

  # Every room's runner, built — the first gate in `just build` that builds a VM
  # image at all (RV-014 F-7). Forcing a link's `path` forces every check above
  # first, so a room that breaks a rule fails here with the rule, and one whose
  # module does not evaluate fails here with that. Proves the image evaluates,
  # meets the rules and builds; not that it boots. Empty for `rooms = {}`.
  roomImages = pkgs.linkFarm "capsule-room-images" (lib.mapAttrsToList (name: cfg: {
      inherit name;
      path =
        builtins.foldl' (acc: c: assert c.ok || throw c.reason; acc)
        cfg.config.microvm.declaredRunner
        (roomChecks name cfg);
    })
    roomVms);

  # Is the host-side half of the perimeter loaded? Injected into the
  # jail-agnostic perimeter as `preflight` + `watch` and shared verbatim with
  # capsule-net, so "intact" has one definition. The systemd path reads the
  # same ruleset as root instead (host/services.nix); this path goes through
  # a NOPASSWD sudo rule, since `capsule-host` holds no privilege.
  #
  # /run/current-system/sw, not a store path: the host config's sudoers rule
  # has to name the same string this does, and this one survives a rebuild on
  # either side.
  perimeterChecks = import ./host/perimeter-check.nix {
    inherit net;
    nft = "sudo -n /run/current-system/sw/bin/nft";
  };

  # Firecracker cannot create its own tap, so one persistent tap is made up
  # front, owned by the invoking user — after which running the VM needs no
  # privilege at all.
  capsule-net = pkgs.writeShellApplication {
    name = "capsule-net";
    runtimeInputs = [pkgs.iproute2 pkgs.procps pkgs.gnugrep];
    text = ''
      tap=${net.tap}

      ${perimeterChecks}

      # Fail closed, before the link exists: `open` means the tap would be a
      # transit path the moment the guest asks for one.
      audit_host() {
        case "$(perimeter_state)" in
          dropped)
            echo "$tap: FORWARD drop verified"
            ;;
          latent)
            echo "warning: net.ipv4.ip_forward is 0, so nothing forwards today, but" >&2
            perimeter_advice
            ;;
          open)
            echo "capsule-net: refusing — net.ipv4.ip_forward is on and" >&2
            perimeter_advice
            return 1
            ;;
        esac
      }

      case "''${1:-}" in
        up)
          audit_host
          if ip link show "$tap" >/dev/null 2>&1; then
            echo "$tap already up"
            # A tap with no address is a half-created link: capsule-host
            # would fail its bind check with nothing pointing at the cause.
            tap_up || {
              echo "warning: $tap exists but ${net.host} is not assigned —" >&2
              echo "         'capsule-net down' then up again." >&2
            }
            exit 0
          fi
          if pgrep -f "microvm@" >/dev/null; then
            echo "warning: a microvm is already running and is attached to the" >&2
            echo "         *old* tap — recreating one will not reattach it." >&2
          fi
          sudo ip tuntap add dev "$tap" mode tap user "$USER"
          # Before the link comes up, so the tap never emits a router
          # solicitation and the host's IPv6 stack is never on the guest's
          # side of the boundary. Per-interface, and the interface is ours,
          # so this one belongs here rather than in the host config — a
          # boot-time sysctl would fire before the tap exists.
          # Absent only if the host kernel has no IPv6 at all, in which case
          # there is nothing to turn off.
          if [ -e "/proc/sys/net/ipv6/conf/$tap/disable_ipv6" ]; then
            sudo sysctl -q -w "net.ipv6.conf.$tap.disable_ipv6=1"
          fi
          sudo ip addr add ${net.host}/${toString net.prefix} dev "$tap"
          sudo ip link set "$tap" up
          echo "$tap up — host ${net.host} <-> guest ${net.guest}"
          # The allow half of the host config fails loud, unlike the drop:
          # omit it and the guest simply reaches nothing.
          echo "if the guest reaches nothing at all, the host is missing the"
          echo "firewall stanza — see README 'Host requirements'."
          ;;
        verify)
          audit_host
          ;;
        down)
          # Deleting a tap out from under a running VM silently kills its
          # NIC: the fd survives, the netdev doesn't, and recreating the tap
          # attaches to nothing. Only a VM restart recovers it.
          if pgrep -f "microvm@" >/dev/null && [ "''${2:-}" != "--force" ]; then
            echo "capsule-net: a microvm is running — stop it first (vm-stop)," >&2
            echo "             or pass --force to sever its network." >&2
            exit 1
          fi
          sudo ip link del "$tap"
          ;;
        *)
          echo "usage: capsule-net up|down|verify" >&2
          exit 1
          ;;
      esac
    '';
  };

  # The allowlist egress proxy. Jail-agnostic by construction (see
  # perimeter/default.nix); the tap check is the one firecracker-specific
  # bit and is injected rather than assumed.
  perimeter = import ./perimeter {
    inherit pkgs;
    bind = net.host;
    client = net.guest;
    inherit (net) proxyPort;
    extraRuntimeInputs = [pkgs.iproute2];
    preflight = ''
      ${perimeterChecks}

      if ! tap_up; then
        echo "capsule-host: ${net.host} is not assigned — run 'capsule-net up' first" >&2
        exit 1
      fi

      # The other path, if this host runs it. It is no longer a port conflict
      # — a unit-path proxy binds this address *inside a namespace*, so the
      # two can both appear to work — which makes it worse rather than
      # better: two perimeters, two logs, and no way to tell which one served
      # a request. One shape at a time. systemd-shaped, so it is injected
      # here rather than living in perimeter/.
      if command -v systemctl >/dev/null 2>&1 \
        && [ -n "$(systemctl list-units --state=active --no-legend \
             'capsule-proxy-*.service' 2>/dev/null)" ]; then
        echo "capsule-host: a capsule-proxy unit is active — the module path" >&2
        echo "  owns the perimeter. Use one path or the other:" >&2
        echo "  systemctl stop 'capsule-proxy-*'" >&2
        exit 1
      fi

      # The proxy is the guest's only reachable surface, so refuse to offer it
      # at all when the host-side half of the perimeter is gone.
      case "$(perimeter_state)" in
        dropped) echo "capsule-host: FORWARD drop on ${net.tap} verified" ;;
        latent)
          echo "capsule-host: warning — net.ipv4.ip_forward is 0, so nothing" >&2
          echo "  forwards today, but" >&2
          perimeter_advice
          ;;
        open)
          echo "capsule-host: refusing — net.ipv4.ip_forward is on and" >&2
          perimeter_advice
          exit 1
          ;;
      esac
    '';
    # Preflight only proves the perimeter was intact at start. Docker or
    # tailscale can flip forwarding on at any point in a session, and a
    # `capsule-net down --force` can take the bind address out from under
    # both services, so keep checking and take the egress down with it.
    # Cheap checks every cycle; the ruleset read only once forwarding is
    # actually live, which is the only case where the drop matters. The
    # checks themselves come from `preflight`, which has already run in this
    # shell.
    watch = ''
      while sleep 10; do
        if ! tap_up; then
          echo "capsule-host: ${net.host} is gone — the tap was removed" >&2
          exit 1
        fi
        forwarding_off && continue
        if ! forward_dropped; then
          echo "capsule-host: net.ipv4.ip_forward went live mid-session and" >&2
          perimeter_advice
          echo "  Tearing down egress." >&2
          exit 1
        fi
      done
    '';
  };
  # `capsule-host`, with a policy resolved in front of it. The perimeter no
  # longer carries an allowlist (NOTES item 36), so the devshell path names one
  # the way it names a capsule: as an argument, refusing without. A wrapper
  # rather than an argument to `perimeter/` for the reason everything else here
  # is injected — a policy vocabulary is this host's, and `perimeter/` is the
  # one place that must stay portable enough for a seatbelt to reuse.
  #
  # It is a wrapper on `PATH`, so reading it answers about the wrapper and not
  # about the proxy (CLAUDE.md).
  capsule-host =
    pkgs.writeShellApplication {
      name = "capsule-host";
      text = ''
        ${rootFragment}
        case "''${1:-}" in
          --policy)
            [ -n "''${2:-}" ] || { echo "capsule-host: --policy takes a name" >&2; exit 1; }
            policy="$2"
            shift 2
            ;;
          *)
            echo "capsule-host: usage: capsule-host --policy <name> [args…]" >&2
            echo "  declared policies: ${lib.concatStringsSep " " policies.everything}" >&2
            echo "  A perimeter serves under a named policy or it does not serve" >&2
            echo "  (the fleet's policies argument, NOTES item 36)." >&2
            exit 1
            ;;
        esac
        case "$policy" in
        ${lib.concatMapStringsSep "
" (n: ''
            ${n}) allow="$root/${policies.dir}/${policies.policies.${n}.allowlist}" ;;'')
          policies.everything}
          *)
            echo "capsule-host: no policy named '$policy'." >&2
            echo "  declared: ${lib.concatStringsSep " " policies.everything}" >&2
            exit 1
            ;;
        esac
        [ -r "$allow" ] || {
          echo "capsule-host: policy '$policy' names $allow, which is not readable." >&2
          exit 1
        }
        echo "capsule-host: policy $policy"
        export CAPSULE_ALLOWLIST="$allow"
        exec ${lib.getExe perimeter.host} "$@"
      '';
    };

  # Host->guest ssh, for everything that is not the proxy: no host-key check
  # and no record of one, because a fresh capsule has fresh keys at the same
  # address. The reasoning, and why it is its own file rather than a literal
  # here, is in host/guest-ssh.nix — the units need the identical relaxation
  # and a security default in two copies is one copy nobody edits.
  guestSsh = import ./host/guest-ssh.nix {inherit lib;};

  # Everything the human runs at a capsule: the git channel both ways,
  # `capsule-inject`, `capsule-baseline`. Built here to reach the guest
  # straight over the tap, and built again in `host/services.nix` with the
  # relay socket instead — one construction, two transports, which is the only
  # thing that differs (host/programs.nix).
  #
  # `access` means two things here: the host's argument (`adminKeys`, `stopKey`,
  # `injections`) and, as a key below, the transport programs.nix takes. Only
  # `injections` crosses — never `inherit access` into this call.
  hostPrograms = import ./host/programs.nix {
    inherit pkgs lib net targets capsules policies workBranch stateDir;
    inherit (access) injections;
    rooms = roomDecision;
    # The same socket expression the units inject, for the opposite purpose:
    # there it is the way in, here its existence is what says this copy is the
    # wrong one (host/guest-ssh.nix).
    access = guestSsh.direct {
      names = builtins.attrNames capsules.instances;
      socket = socketOf ''"$capsule"'';
    };
  };

  # The same values, rendered instead of interpolated — each target's run-time
  # half as `<name>.json`, plus the one function that reads one back
  # ([item 51](./docs/ledger/051-the-target-in-four-store-paths.md) step 3).
  # Nothing consumes it yet; step 4 points the programs above at it, and until
  # then the suite beside it is what builds it.
  #
  # Built here rather than inside `host/programs.nix` for that file's own
  # reason: it is a function of `target` and of nothing else — no transport, no
  # capsule — so a second construction would have nothing to differ in, and one
  # store path is the honest statement of that.
  # A function of a target *set* rather than the value, because the suite
  # beside it renders a fixture set — one target or two — and one construction
  # is the rule (CLAUDE.md), so this host's own profile is that function
  # applied to this host's set rather than a second import.
  render = ts:
    import ./host/profile.nix {
      inherit pkgs lib;
      targets = ts;
    };
  # This host's own, taken from where the programs get it rather than built a
  # second time: `host/programs.nix` constructs it because both of its callers
  # need one and a value constructed twice is a value one of them can construct
  # differently (CLAUDE.md). `render` stays for the suite's fixtures alone.
  hostProfile = hostPrograms.profile;

  # Not one of those four: they run at the *agent*, over whichever transport
  # reaches a capsule, and this one runs at guest root over the link itself —
  # every capsule has the same one, since the namespace is what tells two of
  # them apart. So it takes no capsule and no transport, only an identity, and
  # both paths use the one store path.
  capsule-halt = import ./host/halt.nix {inherit pkgs net guestSsh;};
  inherit (hostPrograms) guestHost;
  # The probe subject's checkout as a URL, for **`probe-netns-boot` and nothing
  # else**. That probe is the deliberate exception to the addressing rule — it
  # boots the real guest, whose image has the `net` declaration and its target in it, so
  # the real capsule *is* its subject. No program carries this.
  guestRepo = "ssh://${guestHost}${probeSubject.guestPath}";
  capsule-provision = hostPrograms.provision;
  capsule-collect = hostPrograms.collect;
  capsule-inject = hostPrograms.inject;

  # These four used to be *attrsets*, present only where `target.nix` declared
  # the field each one reads — "no program at all rather than one that cannot
  # work", which was the right absent path while a host had one target and is
  # the wrong one the moment it has two (NOTES item 51 step 6). Every one of
  # them refuses at run time for a document that declares nothing, naming the
  # profile, and that is a sentence only a run can say.
  capsule-baseline = hostPrograms.baseline;
  capsule-refresh = hostPrograms.refresh;
  capsule-adopt = hostPrograms.adopt;
  capsule-brief = hostPrograms.brief;

  # The front end: resolve a name, pick the copy of a program that can reach
  # that capsule, exec (host/cli.nix). Built once and installed by both paths,
  # because unlike the four programs it carries no transport — so there is
  # nothing for a second instantiation to differ in, and one store path is the
  # honest statement of that. `capsule-cli` as an attribute, `capsule` as a
  # program: `.#capsule` is the guest runner and has been all along.
  #
  # `observe` is what a capsule answers about itself, pushed over the door at
  # each status rather than baked into the guest — a store path, so the front
  # end never learns a guest path (host/observe.nix). It comes from
  # `hostPrograms` because that is where the paths it reads are named, and
  # because a thing built at each of this file's two call sites is a thing one
  # of them can be missing.
  capsule-cli = import ./host/cli.nix {
    inherit pkgs lib net capsules policies guestSsh;
    moduleState = stateDir;
    rooms = roomRecords;
    inherit (hostPrograms) observe observeFragment programVerbs profileVerbs stateRefPrefix volumeRootHelper roomTrust;
  };

  # The third kind of check (CLAUDE.md): a host-side program's own text, run
  # with a substitute for the one thing tying it to this host. One file per
  # suite, beside the program it pins — what stays here is who each one runs
  # and what it is handed
  # ([item 51](./docs/ledger/051-the-target-in-four-store-paths.md)), because
  # the alternative was half this file.
  #
  # **A suite runs the store path the program ships**, which is what step 2 of
  # that item made possible: every program below arrives from `hostPrograms`
  # rather than being rendered a second time. The two exceptions are handed a
  # fixture on purpose — the guard its stubbed kernel, the front end a pool
  # that is not this host's — and each says so in its own header. Four of them
  # run on `casesCapsules`, the fabric above, rather than this host's capsules.
  guardCases = import ./host/guard-cases.nix {
    inherit pkgs lib net;
    capsules = casesCapsules;
    rooms = import ./rooms.nix;
  };

  # The namespace program against a stubbed kernel and a scratch `/etc/netns`
  # (SL-005 sec-3): handed a fixture, as its header says. Its subject and the
  # room record's constructor are the unapplied functions.
  netnsCases = import ./host/netns-cases.nix {
    inherit pkgs lib net;
    capsules = casesCapsules;
    netns = import ./host/netns.nix;
    rooms = import ./rooms.nix;
  };

  # The slots the caller's fleet declares, as the programs under test have them
  # baked (host/programs.nix's `slots`). For every suite whose subject refuses,
  # maps or wraps by declared name — `briefCases`, `vmCases`, `gitChannelCases`,
  # `wrapCases` — so a case about a declared slot names one the caller declared,
  # rather than a letter that was this host's once and passes or fails by
  # accident in every other fleet (SL-004 PHASE-07).
  declaredSlots = builtins.attrNames capsules.instances;

  briefCases = import ./host/brief-cases.nix {
    inherit pkgs lib;
    runner = hostPrograms.briefRunner;
    spec = hostPrograms.briefSpecChecker;
    slots = declaredSlots;
  };

  snapshotCases = import ./host/state-snapshot-cases.nix {
    inherit pkgs quarantine;
    snapshot = hostPrograms.stateSnapshotScript;
    # The other end of the same command line (item 51 step 4): the fragment
    # that builds it off a document, and the reader it needs.
    snapshotArgs = hostPrograms.snapshotArgsFragment;
    profileFragment = hostProfile.fragment;
  };

  baselineCases = import ./host/baseline-cases.nix {
    inherit pkgs;
    runner = hostPrograms.baselineRunner;
  };

  observeCases = import ./host/observe-cases.nix {
    inherit pkgs;
    inherit (hostPrograms) observe observeFragment;
  };

  refreshCases = import ./host/refresh-cases.nix {
    inherit pkgs lib;
    script = hostPrograms.refreshScript;
    # The host half, from where its callers get it (`host/programs.nix`'s
    # `fragments.refresh`), so the suite pins the text `capsule-provision` and
    # `capsule-refresh` both run rather than a second render of it.
    invoke = hostPrograms.refreshInvoke;
  };

  # The ninth, and the first over a program that talks to a guest: what it can
  # reach is everything upstream of the door, which is the whole of what step 4
  # of [item 51](./docs/ledger/051-the-target-in-four-store-paths.md) rewrote.
  # The slot name is this host's declaration and not a fixture, because the
  # shipped program has that list baked in — see the file's own header.
  gitChannelCases = import ./host/git-channel-cases.nix {
    inherit pkgs lib;
    inherit (hostPrograms) provision collect;
    slot = builtins.head declaredSlots;
  };

  # The second over a program that talks to a guest: the room channel at its
  # exit statuses — every caller error a 2 decided before the door, a room with
  # no socket a 75 (host/room-git-cases.nix). The shipped store path, and the
  # caller's policy vocabulary, from which it picks one that permits and one
  # that forbids rather than naming either.
  roomGitCases = import ./host/room-git-cases.nix {
    inherit pkgs lib policies;
    roomGit = hostPrograms.roomGit;
    # The same text with a room's socket under the sandbox, since the shipped
    # path is fixed under `/run`: a door nobody's, for the branches past the
    # socket test (`volumeCases`' fixture socket, one program over).
    fixtureDoor = (hostPrograms.roomGitOf (name: ''"$CASE_RUN/${name}.sock"'')).program;
  };

  # The quarantine's ingestion bound, as fragments spliced into the smallest
  # `main` — a library suite, beside `profileCases`, over the same binding every
  # caller gets (host/quarantine-cases.nix).
  quarantineCases = import ./host/quarantine-cases.nix {
    inherit pkgs lib quarantine;
  };

  # The first suite whose subject is a *library* rather than a program, and the
  # only thing that builds the rendered document — which is why it is not
  # optional on anything (host/profile-cases.nix).
  profileCases = import ./host/profile-cases.nix {
    inherit pkgs lib;
    inherit (hostProfile) fragment select dir names check jsonOf renderDocs jq;
    # Every shipped program that splices the reader, unwrapped and as this file
    # binds them, keyed by program name: the suite asks each one's text for the
    # reader's own `jq` (`DEC-053`). The suite spells the seven names itself,
    # so one dropped from here is a red rather than a shorter loop.
    splicers = {
      inherit capsule-provision capsule-collect capsule-refresh capsule-brief capsule-baseline;
      capsule-room-git = hostPrograms.roomGit;
      capsule = capsule-cli;
    };
    # The same construction this host's own profile comes from, so a fixture
    # document has the key set a real one has rather than the key set this
    # suite remembered. Since item 52 it is used for `.json` alone: the eleven
    # document rules are the *reader's*, so they are refusals to run rather
    # than throws to evaluate.
    inherit render;
    # For `misprofiledIn`, the eval half of the profile-name grammar (SL-001).
    inherit capsules;
  };

  # The tenth, and the only one whose subjects are *devshell* programs: `vm`
  # and `vm-stop` are what a human types, and until `ISS-002` neither read its
  # argv as anything but a name (host/vm-name.nix).
  vmCases = import ./host/vm-cases.nix {
    inherit pkgs lib vm vm-stop;
    slots = declaredSlots;
    rooms = lib.attrNames roomRecords;
  };

  # The eleventh, and a *fourth* kind of check: its subject is the
  # composition of the module path's wrapper with an inner program, which is
  # the one thing neither `hostModuleUnits` nor a `*Cases` suite can see
  # (`ISS-004`, and host/wrap-cases.nix's header). Handed a fixture on
  # purpose — the paths it pins are nobody's, because the rule is the subject
  # and not this host's directories. And handed this host's provision and one
  # declared slot, as `gitChannelCases` is, for the one case over a real
  # program: whether the program's own fallback for `CAPSULE_REPO` is reached
  # (SL-001). The slot is the program's baked list, not a borrowed fixture.
  wrapCases = import ./host/wrap-cases.nix {
    inherit pkgs lib;
    inherit (hostPrograms) provision;
    slot = builtins.head declaredSlots;
  };

  policyCases = import ./host/policy-cases.nix {
    inherit pkgs lib net policies guestSsh;
    capsules = casesCapsules;
    inherit (hostPrograms) observe observeFragment programVerbs profileVerbs stateRefPrefix volumeRootHelper roomTrust;
  };

  # The front end's six room verbs and the refusal of the rest (SL-005
  # sec-7, DEC-051): a fixture pool and rooms built by the real constructor,
  # and its own render, for `policyCases`' reason (host/room-verbs-cases.nix).
  roomVerbsCases = import ./host/room-verbs-cases.nix {
    inherit pkgs lib net policies guestSsh;
    capsules = casesCapsules;
    inherit (hostPrograms) observe observeFragment programVerbs profileVerbs stateRefPrefix volumeRootHelper roomTrust;
    rooms = import ./rooms.nix;
  };

  # The one root program on the volume path (SL-002). Handed a fixture pool and
  # rendering its own subject, like `policyCases`: the helper's roots are
  # build-time arguments so that a root program cannot be pointed elsewhere,
  # which is exactly what stops the shipped store path running in a sandbox
  # (host/volume-root-cases.nix).
  volumeRootCases = import ./host/volume-root-cases.nix {
    inherit pkgs lib;
    capsules = casesCapsules;
    shipped = hostPrograms.volumeRootHelper;
  };

  # The front end's half of the volume path (SL-002): where the name came from,
  # the checks that need no root, and the lock a start shares with the helper.
  # A fixture pool and its own render, for `policyCases`' reason, plus the
  # shipped front end for the one line the fixture replaces
  # (host/volume-cases.nix).
  volumeCases = import ./host/volume-cases.nix {
    inherit pkgs lib net policies guestSsh;
    capsules = casesCapsules;
    inherit (hostPrograms) observe observeFragment programVerbs profileVerbs stateRefPrefix volumeRootHelper roomTrust;
    shipped = capsule-cli;
  };

  # The guest's one deleting program (SL-002), and the first suite whose subject
  # ships in the image rather than on this host. A fixture home, for the same
  # reason as the helper's roots; and the scrub list is read off the evaluated
  # capsule, which puts a guest *eval* (not a build) into `just build`
  # (vm/reset-home-cases.nix).
  # The binding from this host's declarations to its VMs (SL-003 sec-3), run
  # against a stub mkVm and fixtures that are no host's, so no NixOS system is
  # built. Its subject is the unapplied function, as `bound` above applies it
  # (fleet-cases.nix).
  fleetCases = import ./fleet-cases.nix {
    inherit pkgs lib;
    fleet = import ./fleet.nix;
  };

  # What `mkFleet` accepts as this host's state root (SL-008 sec-2, DEC-054),
  # against values that are nobody's. Its subject is the unapplied function, as
  # `stateDir` above applies it (state-dir-cases.nix).
  stateDirCases = import ./state-dir-cases.nix {
    inherit pkgs lib;
    stateDir = import ./state-dir.nix;
  };

  # A room declaration's verdicts (SL-005 sec-2), against fixtures that are no
  # host's. Its subject is the unapplied function (rooms-cases.nix).
  roomsCases = import ./rooms-cases.nix {
    inherit pkgs lib;
    rooms = import ./rooms.nix;
    targetsOf = import ./targets;
  };

  # Which names a probe's fabric may not borrow (NOTES item 38), against a slot
  # and a room built by the real constructors over declarations that are no
  # host's. Its subject is the unapplied function (fabric-cases.nix).
  fabricCases = import ./fabric-cases.nix {
    inherit pkgs lib;
    fabric = import ./fabric.nix;
    capsules = import ./capsules.nix;
    rooms = import ./rooms.nix;
  };

  # The room's launcher, over a fixture tree, and the shipped copy found in the
  # first declared room with repos — `null` when there is none, which the suite
  # reports as skipped (vm/session-cases.nix).
  sessionCases = import ./vm/session-cases.nix {
    inherit pkgs lib;
    session = import ./vm/session.nix;
    shipped = session;
    image = let
      withRepos = lib.filter (n: roomRecords.${n}.repos != null) (lib.attrNames roomRecords);
    in
      if withRepos == []
      then null
      else roomVms.${builtins.head withRepos}.config;
  };

  resetHomeCases = import ./vm/reset-home-cases.nix {
    inherit pkgs lib;
    inherit targets;
    inherit (access) injections;
    guest = bound.images.${probeTarget}.config;
    images = lib.mapAttrs (_: image: image.config) bound.images;
  };

  # The host module has no build of its own — it is a NixOS module, and this
  # repo cannot rebuild someone's host to try it. So *evaluate* it: a text
  # file naming the units it generates drags the whole module through the
  # evaluator, which is where a wrong option name, a bad interpolation or a
  # failed assertion actually lives. Seconds, no NixOS build, and it is in
  # `just build` — the alternative was finding those in a host rebuild.
  # Two derivations off one evaluation of the module: what it *says*
  # (`hostModuleUnits`, seconds, no build) and what it *runs*
  # (`hostModulePrograms`, a build, because shellcheck is a build).
  hostModule = let
    host = lib.nixosSystem {
      inherit system;
      modules = [
        capsulePerimeter
        {
          system.stateVersion = "25.05";
          # Only the unit graph is being read, so nothing here boots — but the
          # base assertions about a root filesystem and a bootloader fire
          # first and bury whatever the module itself has to say. Stubbed
          # rather than answered with `boot.isContainer`, which mutes them by
          # changing what kind of machine this is: that also turns on
          # `useHostResolvConf`, which resolved then refuses, and would go on
          # quietly moving defaults the units are read against.
          boot.loader.grub.enable = false;
          fileSystems."/" = {
            device = "none";
            fsType = "tmpfs";
          };
          # The module asserts on this: a capsule's only resolver is the stub
          # resolved puts on the aggregator's host end.
          services.resolved.enable = true;
          services.capsule-perimeter = {
            enable = true;
            owner = "nobody";
          };
        }
      ];
    };
    failed = lib.filter (a: !a.assertion) host.config.assertions;
    units =
      lib.filter (n: lib.hasPrefix "capsule-" n || lib.hasPrefix "microvm" n)
      (lib.attrNames host.config.systemd.services);

    # The module's *programs*, and the reason this line exists: everything else
    # here reads the unit graph, and a unit graph does not mention what the
    # module puts on a human's PATH. So `host/cli.nix` — imported at two call
    # sites, this file's and the module's — could gain an argument at one of
    # them and every check here still pass. It did: `observe` was added to the
    # devshell's copy only, and the failure landed in a host rebuild, which is
    # the one thing this derivation exists to prevent.
    #
    # `seq` on the store path rather than the string *of* it: forcing an
    # outPath evaluates the derivation, which is where a missing argument
    # throws, while embedding one would make every program a build input of a
    # text file and turn seconds into a full build. Names in the output, paths
    # never.
    installed =
      lib.filter (lib.hasPrefix "capsule")
      (map (p: builtins.seq p.outPath (p.pname or p.name))
        host.config.environment.systemPackages);

    # **The same hole again, one shelf over** (NOTES item 52). An activation
    # script is in neither the unit graph nor `systemPackages`, so the one that
    # installs the profile documents could name a missing attribute and only a
    # host rebuild would say so — which is exactly what `installed` above exists
    # to stop happening to a program. Selected by name prefix rather than
    # hand-listed, so the next `capsule*` activation script is checked without
    # this line being touched, and NixOS's own dozens stay out of it.
    activations =
      lib.filter (lib.hasPrefix "capsule")
      (lib.attrNames host.config.system.activationScripts);
    activationText = map (n: let
      v = host.config.system.activationScripts.${n};
    in
      if builtins.isString v
      then v
      else v.text)
    activations;

    # Item 37's class a third time, and `installed` above is the half that
    # cannot close it: forcing an outPath evaluates a derivation and builds
    # nothing, so `host/services.nix`'s `wrap` — the programs whose entire text
    # is the environment this host's copies run with — had never been
    # shellchecked by anything. That matters more since item 52 put
    # `CAPSULE_PROFILE_DIR` in there. Paths and not names, which is the whole
    # difference between this derivation and the other. Still unasserted, and
    # item 52 says so: that the wrapper exports the *right* directory. Building
    # it proves only that it parses.
    wrappers =
      map (p: "${p}")
      (lib.filter (p: lib.hasPrefix "capsule" (p.pname or p.name or ""))
        host.config.environment.systemPackages);

    # The guard reads `/proc/<pid>/ns/net` for processes owned by `microvm`, and
    # a hardened unit that may not do that does not fail — `ip netns pids`
    # returns a list with the unreadable processes missing, so the guard refuses
    # a correctly-bound guest and names the wrong cause. Nothing else pairs a
    # program's needs with its unit's permissions, and this is the file that
    # reads both, so it is asserted rather than remembered (NOTES item 30).
    guardCaps = host.config.systemd.services.capsule-perimeter-guard.serviceConfig.CapabilityBoundingSet;

    # A newline in a unit directive is unbalanced quoting to systemd, which
    # ignores that directive *and* the rest of the drop-in — so a unit loses
    # its namespace and its `ExecStop` and says nothing about it. Nix will
    # happily produce one, systemd only complains at load, and both paths
    # around it look healthy: that is a whole rebuild and an evening
    # (docs/plan-c-implementation.md, "Traps already paid for"). Asked here
    # because this is the one thing that reads the module without a host.
    literals = v:
      if builtins.isList v
      then lib.concatMap literals v
      else if builtins.isString v
      then [v]
      else [];
    directives = n:
      literals (lib.attrValues (host.config.systemd.services.${n}.serviceConfig or {}));
    newlined = lib.filter (n: lib.any (lib.hasInfix "\n") (directives n)) units;

    # A bound path is mounted as **root** and opened as the unit's **user**, so
    # `BindReadOnlyPaths` naming a file under a directory that user cannot
    # traverse builds a unit that starts and then dies at `open()` — `filter
    # file: Permission denied` about a path that is plainly there, with the
    # bind itself reported as fine. Every capsule proxy was in exactly that
    # state, on every slot and under every policy, and the only witness was one
    # line in one unit's journal ([NOTES item 39]).
    #
    # Evaluable because both halves are this module's own declarations: its `d`
    # rules say what mode it gives each directory it creates, and each unit says
    # who it runs as. Same shape as the guard's capability pairing above and as
    # `borrowed` in the probe fabric — the alternative is a comment that is true
    # on the day it is written. It cannot see directories the module did not
    # declare, which is the honest limit: it pairs what this repo controls.
    dirRules =
      lib.filter (d: d != null)
      (map (
          rule: let
            w = lib.filter (s: s != "") (lib.splitString " " rule);
            at = i: lib.elemAt w i;
          in
            if lib.length w >= 5 && at 0 == "d"
            then {
              path = at 1;
              # tmpfiles' own defaults for `-`, so a rule that declines to say
              # is read as what it will actually produce.
              mode =
                if at 2 == "-"
                then "0755"
                else at 2;
              owner =
                if at 3 == "-"
                then "root"
                else at 3;
              group =
                if at 4 == "-"
                then "root"
                else at 4;
            }
            else null
        )
        host.config.systemd.tmpfiles.rules);

    # Traversal is the `x` bit, and for a user who is neither the owner nor in
    # the group that is the *others* digit. Group membership is a declaration
    # too, so it is read rather than assumed.
    othersTraverse = mode: lib.elem (lib.last (lib.stringToCharacters mode)) ["1" "3" "5" "7"];
    mayTraverse = user: d:
      d.owner
      == user
      || lib.elem user (host.config.users.groups.${d.group}.members or [])
      || othersTraverse d.mode;

    binds = n: let
      v = host.config.systemd.services.${n}.serviceConfig.BindReadOnlyPaths or [];
    in
      map (e: lib.head (lib.splitString ":" e)) (lib.toList v);

    unreachable = lib.concatMap (n: let
      user = host.config.systemd.services.${n}.serviceConfig.User or "root";
    in
      if user == "root"
      then []
      else
        lib.concatMap (
          p:
            map (d: "${n} runs as ${user} and binds ${p}, which is under ${d.path} (${d.mode} ${d.owner}:${d.group}) — it cannot traverse that, so the open fails though the mount does not")
            (lib.filter (d: lib.hasPrefix "${d.path}/" p && !(mayTraverse user d)) dirRules)
        )
        (binds n))
    units;

    # The other half of the same pairing, read the other way up: not who may
    # pass through a declared directory, but whether tmpfiles will make it at
    # all. It refuses an "unsafe path transition" — a step from a directory not
    # owned by root into one owned by someone else — and a parent nothing
    # declares is one it makes itself, `root:root`. So a `d` rule under the
    # owner's `stateDir` with an undeclared parent is never made, and silently:
    # a switch reruns tmpfiles as `systemd-tmpfiles-resetup`, whose
    # `SuccessExitStatus` includes the refusal's `CANTCREAT` (ISS-024, SL-006
    # PHASE-07: `stateDir/room`). Under `stateDir`, every declared directory's
    # parent must be declared too, owned by root or by the same user; each
    # parent is checked in turn, so the whole chain up to `stateDir` is.
    # Generic rather than the two names it was found on, since a third is one
    # `++` away.
    unparented = lib.concatMap (d: let
      parent = builtins.dirOf d.path;
      declared = lib.filter (p: p.path == parent) dirRules;
      safe = p: p.owner == "root" || p.owner == d.owner;
    in
      if !(lib.hasPrefix "${stateDir}/" d.path) || lib.any safe declared
      then []
      else if declared == []
      then ["${d.path} (owned by ${d.owner}) has no `d ${parent}` rule, so tmpfiles makes ${parent} root:root and then refuses the unsafe path transition into it"]
      else ["${d.path} (owned by ${d.owner}) is under ${parent}, which is declared owned by ${(lib.head declared).owner}, so tmpfiles refuses the unsafe path transition into it"])
    dirRules;

    # `capsule <slot> policy <name>` ends in `sudo systemctl restart
    # capsule-proxy-<slot>`, and on a host that does not permit it the verb
    # cannot finish — it now undoes the selection rather than half-applying it,
    # but a verb built to be *delegable* that always refuses is not delegable
    # (NOTES item 41). Both halves are this module's own declarations: the
    # proxy units it makes, and the rule it installs for them. Fourth instance
    # of the shape, after the guard's capability (item 30) and the bind's
    # traversal (item 39) — and this one earns its place twice, because nothing
    # else here reads `security.sudo.extraRules` at all, so without it a type
    # error in that rule would surface in a host rebuild.
    #
    # The literal path is sudo's, not nix's: sudo resolves the command against
    # its own `secure_path` before matching, so a rule naming a store path would
    # look right and never fire (host/services.nix says the same where the rule
    # is written).
    sudoCommands =
      lib.concatMap (r: map (c: c.command or c) r.commands)
      host.config.security.sudo.extraRules;
    unrestartable =
      lib.filter (n: !(lib.elem (import ./host/proxy-restart.nix n) sudoCommands))
      (lib.filter (lib.hasPrefix "capsule-proxy-") units);

    # The removed options — `repo` (SL-001, `DEC-013`) and `stateDir` (SL-008,
    # `DEC-054`) — which the fixture above never sets and so cannot see. A
    # second evaluation of the same host with the option set — `extendModules`,
    # not a second `nixosSystem` — asked two things, each under its own
    # `tryEval`: a shim deleted or misnamed makes reading `options` throw on the
    # unmatched definition, which must read as that and not as some other eval
    # failure; and `mkRemovedOptionModule` reports through `config.assertions`,
    # so its message is readable here, and must name what replaced the option.
    removed = name: replacement: let
      withOld = host.extendModules {
        modules = [{services.capsule-perimeter.${name} = "/set/by/an/old/host";}];
      };
      held = r: r.success && r.value;
    in {
      readable = held (builtins.tryEval (withOld.options.services.capsule-perimeter ? ${name}));
      redirected = held (builtins.tryEval (lib.any
        (a: !a.assertion && lib.hasInfix replacement a.message)
        withOld.config.assertions));
    };
    repoRemoved = removed "repo" "profile document's `path`";
    stateDirRemoved = removed "stateDir" "mkFleet's `stateDir`";

    # The state root is `mkFleet`'s declaration (`DEC-054`) and the module makes
    # it, the owner's and closed to everyone else. Compared against the binding
    # this file checked rather than a spelling, so a module that made the old
    # default where a host declared another root is the one this refuses.
    stateRootMissing =
      !(lib.any (d: d.path == stateDir && d.mode == "0750" && d.owner == cfg.owner && d.group == "users")
        dirRules);

    # A room is a guest and not a slot (SL-005 design sec-4, `DEC-036`): it gets
    # the per-guest units — namespace, tap and VMM drop-ins, relay — and none of
    # the per-slot ones, and nothing of its own may lean on the egress fabric it
    # has no link to. Read off the module this fixture declares rooms for, so
    # the first check is what keeps the next ones from passing over nothing.
    roomNames = lib.attrNames roomRecords;
    service = n: host.config.systemd.services.${n} or {};
    roomUnitsMissing = lib.filter (n:
      !(lib.all (u: lib.elem u units)
        ["capsule-netns-${n}" "capsule-ssh-relay-${n}" "microvm@${n}" "microvm-tap-interfaces@${n}"]))
    roomNames;
    # The aggregator is matched by prefix rather than by an exported name: the
    # module spells `capsule-egress-ns.service` once (host/services.nix), and a
    # rename there should not make this check vacuous.
    roomOnAggregator = lib.filter (n: let
      u = service "capsule-netns-${n}";
    in
      lib.any (lib.hasPrefix "capsule-egress") ((u.requires or []) ++ (u.after or [])))
    roomNames;
    roomWantsProxy = lib.filter (n:
      lib.any (lib.hasPrefix "capsule-proxy-") ((service "microvm@${n}").wants or [])
      || lib.elem "capsule-proxy-${n}" units)
    roomNames;
    roomRelayElsewhere = lib.filter (n: let
      sc = (service "capsule-ssh-relay-${n}").serviceConfig or {};
    in
      !(lib.hasInfix "UNIX-LISTEN:${roomRecords.${n}.socket}," (sc.ExecStart or "")
        && (sc.RuntimeDirectory or null) == "capsule-room/${n}"))
    roomNames;

    # The room channel's two module halves (SL-006 design sec-4, sec-5). Every
    # declared room gets its trust store's directory, with or without repos,
    # because every door to a room uses it (DEC-047) — spelled here rather than
    # read from `rooms.stateDirOf`, so the check cannot agree with itself.
    # And the one `capsule-room-git` on PATH is the wrapped one, compared by
    # store path in the condition and never embedded (`installed`'s rule): bare,
    # its state falls back to `$PWD/.vm/host` (RV-015 F-3, `ISS-004`). So is the
    # one `capsule`, around this file's own `capsule-cli`: that one comparison
    # says the wrapper's `CAPSULE_STATE` default is the declared root *and* that
    # the module's front end is the devshell's store path (RSK-004).
    cfg = host.config.services.capsule-perimeter;
    roomStateMissing = lib.filter (n:
      !(lib.any (d: d.path == "${stateDir}/room/${n}" && d.mode == "0700" && d.owner == cfg.owner && d.group == "users")
        dirRules))
    roomNames;
    inherit
      (import ./host/wrap.nix {
        inherit pkgs lib;
        paths = {
          inherit stateDir;
          inherit (cfg) policyDir allowlistDir profileDir;
        };
      })
      wrap
      ;
    isWrapped = name: program: let
      found =
        lib.filter (p: (p.pname or p.name or "") == name)
        host.config.environment.systemPackages;
    in
      lib.length found == 1 && (lib.head found).outPath == (wrap name program).outPath;

    # Refused before either derivation is named, so a `nix build` of the
    # programs cannot pass a module whose units are wrong.
    checked = drv:
      if failed != []
      then throw "capsule-perimeter: ${lib.concatMapStringsSep "; " (a: a.message) failed}"
      else if newlined != []
      then throw "capsule-perimeter: a newline in a serviceConfig value of ${lib.concatStringsSep ", " newlined} — systemd reads that as unbalanced quoting and drops the rest of the unit. Put the script in the store and name it."
      else if !(lib.elem "CAP_SYS_PTRACE" guardCaps)
      then throw "capsule-perimeter: the guard's CapabilityBoundingSet has no CAP_SYS_PTRACE, so `ip netns pids` will silently omit the VMM it is asked about and the guard will refuse a correctly-bound guest (NOTES item 30)."
      else if unreachable != []
      then throw "capsule-perimeter: ${lib.concatStringsSep "; " unreachable} (NOTES item 39)."
      else if unparented != []
      then throw "capsule-perimeter: ${lib.concatStringsSep "; " unparented} (ISS-024)."
      else if unrestartable != []
      then throw "capsule-perimeter: no sudoers rule permits restarting ${lib.concatStringsSep ", " unrestartable}, so `capsule <slot> policy <name>` cannot finish a selection for those slots and will undo it instead (NOTES item 41)."
      else if !repoRemoved.readable
      then throw "capsule-perimeter: with services.capsule-perimeter.repo set, the module's options are unreadable — the removed-option shim for `repo` is gone or misnamed, so a host that still sets it fails on an unknown option instead of being told source is the profile document's `path` (SL-001)."
      else if !repoRemoved.redirected
      then throw "capsule-perimeter: with services.capsule-perimeter.repo set, no assertion names the profile document's `path` — the removed-option shim for `repo` no longer says what replaced it (SL-001)."
      else if !stateDirRemoved.readable
      then throw "capsule-perimeter: with services.capsule-perimeter.stateDir set, the module's options are unreadable — the removed-option shim for `stateDir` is gone or misnamed, so a host that still sets it fails on an unknown option instead of being told the root is mkFleet's `stateDir` (DEC-054)."
      else if !stateDirRemoved.redirected
      then throw "capsule-perimeter: with services.capsule-perimeter.stateDir set, no assertion names mkFleet's `stateDir` — the removed-option shim for `stateDir` no longer says what replaced it (DEC-054)."
      else if stateRootMissing
      then throw "capsule-perimeter: no tmpfiles `d ${stateDir} 0750 <owner> users` — the module does not make the state root mkFleet declares (DEC-054)."
      else if roomUnitsMissing != []
      then throw "capsule-perimeter: room(s) ${lib.concatStringsSep ", " roomUnitsMissing} have no capsule-netns, capsule-ssh-relay, microvm@ or microvm-tap-interfaces@ unit — a room is a guest, and those units are built over guests (SL-005 design sec-4, DEC-036)."
      else if roomOnAggregator != []
      then throw "capsule-perimeter: the namespace unit of room(s) ${lib.concatStringsSep ", " roomOnAggregator} requires or is ordered after the egress aggregator — a room has no uplink, so it must neither pull the aggregator in nor wait on it (SL-005 design sec-4, DEC-036)."
      else if roomWantsProxy != []
      then throw "capsule-perimeter: room(s) ${lib.concatStringsSep ", " roomWantsProxy} want or have a capsule-proxy unit — a room has no uplink and no policy, so it gets no egress proxy (SL-005 design sec-4, DEC-036)."
      else if roomRelayElsewhere != []
      then throw "capsule-perimeter: the ssh relay of room(s) ${lib.concatStringsSep ", " roomRelayElsewhere} does not listen on the room's own socket under RuntimeDirectory capsule-room/<name> — a room's door is its record's (SL-005 design sec-4)."
      else if roomStateMissing != []
      then throw "capsule-perimeter: room(s) ${lib.concatStringsSep ", " roomStateMissing} have no tmpfiles `d <stateDir>/room/<name> 0700 <owner> users` — that is the room's one known_hosts, which every door to it checks (SL-006 design sec-5, DEC-047)."
      else if !(isWrapped "capsule-room-git" hostPrograms.roomGit)
      then throw "capsule-perimeter: the module does not install exactly one capsule-room-git, wrapped (host/wrap.nix) around the same program `hostPrograms.roomGit` builds — bare, its quarantine and known_hosts fall back to $PWD/.vm/host and its profiles to the store's (RV-015 F-3, ISS-004)."
      else if !(isWrapped "capsule" capsule-cli)
      then throw "capsule-perimeter: the module does not install exactly one capsule, wrapped (host/wrap.nix) with mkFleet's `stateDir` around the same `capsule-cli` the devshell carries — either its CAPSULE_STATE default is not the declared root or its front end is a second store path (DEC-054, RSK-004)."
      else drv;
  in {
    units = checked (pkgs.writeText "capsule-units.txt" ''
      units:
      ${lib.concatStringsSep "\n" units}

      programs:
      ${lib.concatStringsSep "\n" installed}

      activation:
      ${lib.concatStringsSep "\n" activations}
    '');

    # **The exact inversion of the rule one comment up**, and deliberately a
    # second derivation for it: embedding the *string* of a store path makes
    # every program a build input, which is why `installed` refuses to — and
    # is the only way to make shellcheck run on a program no flake output
    # names. `capsule-netns` and `capsule-egress-ns` are only ever an
    # ExecStart, so nothing in `just build` had ever built them and a rollback
    # written into one shipped unchecked (NOTES item 37).
    #
    # Every serviceConfig literal, not a hand-listed set, so a program added
    # to a unit tomorrow is checked without this line being touched.
    #
    # The activation scripts' text belongs on *this* side and not the other,
    # for the same reason and with one addition: it names the rendered profile
    # directory, so putting the text here makes that document a build input and
    # `just build` renders it — and rendering it now runs the reader over it
    # (host/profile.nix, NOTES item 52). A document nothing builds is a document
    # nothing checks (item 37).
    #
    # And the *wrappers* — see `wrappers` in the `let` above.
    programs = checked (pkgs.writeText "capsule-module-programs.txt"
      (lib.concatStringsSep "\n"
        (lib.concatMap directives units ++ activationText ++ wrappers)));
  };

  hostModuleUnits = hostModule.units;
  hostModulePrograms = hostModule.programs;

  # The argv `vm` and `vm-stop` share, and the only thing either of them asks
  # of a human. One text, spliced ahead of both (host/vm-name.nix, `ISS-002`).
  vmName = import ./host/vm-name.nix;

  # A declared room, refused by both: a room runs only on the module path
  # (design sec-1), because a devshell boot puts its tap in the root namespace
  # and a room is a namespace's guest. Here and not in `host/vm-name.nix`, whose
  # test is a bare token on purpose — which names exist is the declaration's to
  # answer, and this is the one place both programs are handed it (POL-003).
  # Spliced after the argv is read and before anything is made or probed. Room
  # names are unit-safe (`rooms.nix`), so they are literal `case` patterns.
  roomRefusal = {prog}: let
    names = lib.attrNames roomRecords;
  in
    lib.optionalString (names != []) ''
      case "$name" in
        ${lib.concatStringsSep " | " names})
          echo "${prog}: '$name' is a room; rooms run only on the module path (capsule $name start)" >&2
          exit 2
          ;;
      esac
    '';

  # The devshell path's root (perimeter/root.nix), for the two programs here
  # that spell it; the rest import the file themselves.
  rootFragment = import ./perimeter/root.nix;

  # Which VMMs in this netns run a given image, and which image a name boots —
  # shared by `vm` and `vm-stop` (host/own-vms.nix, ISS-016).
  ownVms = import ./host/own-vms.nix {
    inherit lib;
    capsuleNames = ["capsule"] ++ builtins.attrNames capsules.instances;
  };

  # Each VM's runner keeps mutable state (volume images, API socket) in $PWD,
  # so give every one its own directory under .vm/.
  #
  # It builds the runner into `.vm/<name>/booted` and runs it *through* that
  # link, so the link names the image that is running — the devshell path's
  # counterpart of microvm.nix's `/var/lib/microvms/<slot>/booted`, and what
  # the front end reads a running image's target from (DEC-024). The out-link
  # is also a gcroot, so the running image cannot be collected under it, and a
  # failed build leaves it as it was.
  vm = pkgs.writeShellApplication {
    name = "vm";
    # `nix` is not here: it is the host's, as it always was.
    runtimeInputs = [pkgs.procps pkgs.coreutils];
    # No default, since `capsules.default` went with slots being abstract: an
    # omitted name used to mean the capsule that was called `capsule`. What
    # reads argv is `host/vm-name.nix`, shared with `vm-stop` — and every
    # refusal in it lands ahead of the `mkdir` below, which is `ISS-002`.
    text =
      vmName {prog = "vm";}
      + roomRefusal {prog = "vm";}
      + ownVms
      + ''
        ${rootFragment}

        # The link may only change while nothing runs from it. Every devshell
        # capsule is ${net.guest} on a tap in the root namespace, so one runs at
        # a time, and a second start would fail at the tap only *after* its
        # build had repointed `booted` at an image that is not the one running.
        # So refuse first — before the build, and before any state is made.
        # Two starts racing inside this gap are one human typing twice.
        if [ -n "$(own_vms "$(vmmOf "$name")")" ]; then
          echo "vm: a capsule is already running in this namespace; vm-stop it first" >&2
          exit 1
        fi

        dir="$root/.vm/$name"
        mkdir -p "$dir"
        cd "$dir"
        nix build --out-link booted "$root#$name"
        exec ./booted/bin/microvm-run
      '';
  };

  # Probes are in the tree rather than in a scratch file for two reasons: each
  # is the evidence behind a decision and has to outlive the conversation that
  # produced it, and building them here means shellcheck runs and their tools
  # are pinned rather than borrowed from whatever `sudo` happens to have on
  # PATH. They need root, so they are the human's to run.
  #
  # `prelude` is how a probe gets the caller's net/targets values without spelling
  # an address itself. The harness is concatenated rather than sourced: one
  # `writeShellApplication` is one script, so shellcheck sees both halves and
  # the probe needs no path to a sibling at run time.
  #
  # Harness, then prelude, then probe. The harness declares an empty default
  # for every value a prelude may inject — which is what lets it carry the
  # egress fabric below without every probe that never builds one tripping
  # SC2154 — so the prelude has to come *after* it or those defaults would win.
  mkProbe = {
    name,
    script,
    runtimeInputs,
    prelude ? "",
  }:
    pkgs.writeShellApplication {
      inherit name runtimeInputs;
      # A probe's whole job includes running commands that must fail.
      bashOptions = ["nounset" "pipefail"];
      text =
        builtins.readFile ./probe/harness.sh
        + prelude
        + builtins.readFile script;
    };

  # Which names the probe fabric borrows from the live declaration, and the
  # reason to refuse it (fabric.nix, NOTES item 38). Thrown when the prelude is
  # forced, which is every probe's build.
  fabricCheck = import ./fabric.nix {inherit lib;} {
    inherit capsules;
    rooms = roomRecords;
    fabric = probeFabric;
  };

  fabricPrelude = assert fabricCheck.reason == null || throw fabricCheck.reason; ''
    EG_NS="${probeFabric.ns}"
    EG_DEV="${probeFabric.dev}"
    EG_PEER="${probeFabric.peer}"
    EG_ADDR="${probeFabric.addr}"
    EG_PEER_ADDR="${probeFabric.peerAddr}"
    EG_NET="${probeFabric.net}"
    EG_NET_BASE="${probeFabric.netBase}"
    EG_UPLINK_NET="${probeFabric.uplinkNet}"
    EG_OUT_PREFIX="${probeFabric.outPrefix}"
    EG_WAN_PREFIX="${probeFabric.wanPrefix}"
  '';

  # The fabric, plus what a round that puts a *proxy* on it needs. Two strings
  # because `probe/netns.sh` builds the fabric with no proxy in it, and an
  # allowlist path a probe never reads is an unused variable — which is a build
  # failure here rather than a stray line.
  egressPrelude =
    fabricPrelude
    + ''
      PROXY_PORT="${toString net.proxyPort}"
      PROXY="${perimeter.proxy}/bin/capsule-proxy"
      # The two policies a wire round asserts under, named rather than
      # defaulted: the perimeter has no allowlist of its own any more, so a
      # probe states which policy it is asserting under exactly as a capsule
      # does (NOTES item 36). `build` is the one that has to admit a host,
      # since every round asserts a 200 as well as a 403; `sealed` must not.
      ALLOWLIST="${policies.dir}/${policies.policies.build.allowlist}"
      SEALED_ALLOWLIST="${policies.dir}/${policies.policies.sealed.allowlist}"
    '';

  # This flake's copy of the namespace layer. `host/services.nix` builds its
  # own from the module's `pkgs`, which is a different nixpkgs and therefore a
  # different store path — one *file*, two instantiations, exactly as
  # `guardCases` already instantiates it against a fixture. What must not
  # happen is a second file: a probe that reimplemented `up` and `down` would
  # assert that its own shell agrees with itself.
  netns = import ./host/netns.nix {inherit pkgs lib net capsules;};

  # Does a network namespace per capsule hold up (docs/plan-c-multi-capsule.md, "Netns per
  # capsule")? Models two capsules with identical addressing and no VM, on
  # addressing deliberately unlike the live capsule's.
  probe-netns = mkProbe {
    name = "probe-netns";
    script = ./probe/netns.sh;
    # Its links and namespaces were always its own (`spk-*`, `capspk-*`); its
    # *addressing* was the live aggregator's, and stage 2 puts `10.101.0.1` and
    # a route for `10.100.0.0/16` in the **root** namespace. Third instance of
    # NOTES item 38, and the reason the fix is a value rather than a rename.
    prelude = fabricPrelude;
    runtimeInputs = [
      pkgs.iproute2
      pkgs.iputils
      pkgs.nftables
      pkgs.procps
      pkgs.gawk
      pkgs.coreutils
      pkgs.bash # /dev/tcp, via `timeout 5 bash -c`
      pkgs.bind.dnsutils
      pkgs.socat # listeners, and the unix-socket way into a namespace
    ];
  };

  # The one thing that probe cannot answer, because it has no VM in it: does
  # firecracker come up with its tap inside a namespace (docs/plan-c-multi-capsule.md, "The one
  # thing still unverified")? Boots the real capsule, so it takes the real
  # values — and refuses to run beside the devshell shape.
  # Does a capsule's namespace survive being torn down and rebuilt (NOTES item
  # 37)? Drives the **real** `capsule-netns` through the seam it already has —
  # every per-capsule value comes from its unit's `Environment=`, so a probe
  # supplies a whole capsule's worth of addressing that is nobody's capsule.
  # No VM, no tap, no guest, and nothing in the root namespace.
  probe-netns-restart = mkProbe {
    name = "probe-netns-restart";
    script = ./probe/netns-restart.sh;
    # The program, not its text. Same store path `host/services.nix` puts in
    # an ExecStart, up to the nixpkgs each was built from.
    prelude = ''
      CAPSULE_NETNS="${lib.getExe netns.programs.capsule}"
    '';
    runtimeInputs = [
      pkgs.iproute2
      pkgs.procps
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.gawk # `since`, in the harness
    ];
  };

  probe-netns-boot = mkProbe {
    name = "probe-netns-boot";
    script = ./probe/netns-boot.sh;
    # Quoted, and it matters: `TAP=vm-capsule` unquoted reads as arithmetic to
    # shellcheck (SC2100) the moment the harness has a `vm` variable in scope,
    # and writeShellApplication takes that as a build failure.
    prelude = ''
      TAP="${net.tap}"
      HOST_ADDR="${net.host}"
      GUEST_ADDR="${net.guest}"
      PREFIX="${toString net.prefix}"
      VM="capsule"
      GUEST_REPO="${guestRepo}"
    '';
    runtimeInputs = [
      pkgs.iproute2
      pkgs.iputils
      pkgs.procps
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.util-linux # runuser: enter the namespace as root, boot the VM as you
      pkgs.glibc.bin # getent, for the human's home directory
      pkgs.bash # /dev/tcp, via `timeout 3 bash -c`
      pkgs.socat
      pkgs.openssh
      pkgs.git
      pkgs.nix # builds the runner, as the human
    ];
  };

  # The claim neither of those two makes: does the *perimeter* survive the move
  # into a namespace (docs/status.md, "Egress under netns is unproven")? Boots
  # the real capsule, joins the real proxy to its namespace, and asks the guest
  # to get out — to a host the allowlist permits and to one it does not. Takes
  # the proxy as a store path rather than rebuilding one, because a probe
  # against a lookalike proves nothing about the program that ships.
  probe-netns-egress = mkProbe {
    name = "probe-netns-egress";
    script = ./probe/netns-egress.sh;
    prelude =
      egressPrelude
      + ''
        TAP="${net.tap}"
        HOST_ADDR="${net.host}"
        GUEST_ADDR="${net.guest}"
        PREFIX="${toString net.prefix}"
        VM="capsule"
        # The VM-less sibling that exists to be unreachable. Prefixed like the
        # rest of the fabric rather than `cap-`, which is what a slot's
        # namespace is called.
        NSPEER="${probeFabric.peerNs}"
      '';
    runtimeInputs = [
      pkgs.iproute2
      pkgs.iputils
      pkgs.nftables
      pkgs.procps
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.gnused # the allowed host comes out of the allowlist, not the probe
      pkgs.gawk
      pkgs.util-linux # runuser: enter the namespace as root, boot the VM as you
      pkgs.glibc.bin # getent, for the human's home directory
      pkgs.bash # /dev/tcp, host-side and (over ssh) guest-side
      pkgs.socat
      pkgs.openssh
      pkgs.bind.dnsutils
      pkgs.nix # builds the runner, as the human
    ];
  };

  # What does a fresh capsule cost, and which of REQ-450's five freshness axes
  # does a microVM actually satisfy (doctrine IMP-426 P1a)? Boots the real
  # guest image, twice, against its *own* state directory — freshness means
  # making and destroying volumes, and a probe that did that to `.vm/capsule`
  # could be run once.
  #
  # The socket path is the designed one — `capsules.socketOf`, the same
  # convention a declared instance gets — rather than a mktemp, because
  # `capsule-provision` has to reach the guest through it: the probe exercises
  # the real program on the real seam, which is the whole point of `transport`
  # being injected.
  #
  # One set for every capsule a probe invents, `--capsule <name>` choosing
  # which. It used to be a function over the socket, because a socket path
  # baked into a store path meant a program per capsule — the asymmetry
  # `probe-two-capsules` was written to expose, and the reason the transport is
  # a run-time argument now. `socat` is bare here: a probe has it in
  # `runtimeInputs`, where a unit has no PATH to trust.
  nsPrograms = import ./host/programs.nix {
    inherit pkgs lib net targets capsules policies workBranch stateDir;
    inherit (access) injections;
    rooms = roomDecision;
    access = guestSsh.viaSocket {
      socat = "socat";
      socket = socketOf ''"$capsule"'';
    };
  };
  probe-freshness = mkProbe {
    name = "probe-freshness";
    script = ./probe/freshness.sh;
    prelude = ''
      TAP="${net.tap}"
      HOST_ADDR="${net.host}"
      GUEST_ADDR="${net.guest}"
      PREFIX="${toString net.prefix}"
      VM="capsule"
      GUEST_PATH="${probeSubject.guestPath}"
      TARGET_PATH="${probeSubject.path}"
      CACHES="${lib.concatStringsSep " " (lib.attrValues probeSubject.caches)}"
      PROVISION="${nsPrograms.provision}/bin/capsule-provision"
      # Its own name, not a slot's: this probe makes and destroys volumes, so
      # it must not land on a declared slot's socket — and `socketOf` is what
      # keeps the convention single even for a capsule nobody declared.
      SOCKDIR="${builtins.dirOf (socketOf "capsule")}"
    '';
    runtimeInputs = [
      pkgs.iproute2
      pkgs.iputils
      pkgs.procps
      pkgs.coreutils # du, dirname, date
      pkgs.gnugrep
      pkgs.gawk # the arithmetic behind every figure
      pkgs.util-linux # runuser: enter the namespace as root, boot the VM as you
      pkgs.glibc.bin # getent, for the human's home directory
      pkgs.bash
      pkgs.socat
      pkgs.openssh
      pkgs.git
      pkgs.nix # builds the runner and prices its closure, as the human
    ];
  };

  # Can two capsules run at once, are they independent, and what does the pair
  # cost (doctrine IMP-426 P1b, REQ-454)? Two namespaces, two volumes, two base
  # commits — and deliberately *one* runner from one store path, because that
  # is the shape being priced and it is what makes instance identity a real
  # problem rather than a hypothetical one. One set of host programs too, now
  # that the transport is an argument: this probe is what found that it was not.
  pairA = "pair-a";
  pairB = "pair-b";
  probe-two-capsules = mkProbe {
    name = "probe-two-capsules";
    script = ./probe/two-capsules.sh;
    prelude =
      egressPrelude
      + ''
        TAP="${net.tap}"
        HOST_ADDR="${net.host}"
        GUEST_ADDR="${net.guest}"
        PREFIX="${toString net.prefix}"
        VM="capsule"
        NAME_A="${pairA}"
        NAME_B="${pairB}"
        SOCKDIR_A="${builtins.dirOf (socketOf pairA)}"
        SOCKDIR_B="${builtins.dirOf (socketOf pairB)}"
        PROVISION="${nsPrograms.provision}/bin/capsule-provision"
        COLLECT="${nsPrograms.collect}/bin/capsule-collect"
        # What a slot's record and the operator's declaration would supply, for
        # two capsules that are neither (NOTES item 36, item 32). The unit half
        # is present only where this target's state paths have a hole for one,
        # since a flag that scopes nothing is refused.
        #
        # **The last eval-time reader of that predicate, and deliberately so**
        # (NOTES item 51 step 6): no *program* asks it at build any more, and
        # what is left is a probe, which is evidence about the real capsule on
        # this host and is allowed to know this host's real target —
        # `probe/netns-boot.sh` is the standing exception for the same reason.
        # It comes off `host/profile.nix` rather than being spelled here, so
        # the hole has one spelling ([item 38](./docs/ledger/038-a-probe-that-became-a-borrower.md)).
        COLLECT_ARGS=(--policy build${
          lib.optionalString (nsPrograms.profile.needsUnitOf probeSubject) " --unit probe"
        })
        GUEST_PATH="${probeSubject.guestPath}"
        TARGET_PATH="${probeSubject.path}"
        WORK_BRANCH="${workBranch}"
        MEM_MIB="${toString probeSubject.sizes.mem}"
        # Where a collect lands, from the one construction that decides it
        # rather than from this file's memory of it. The probe used to spell
        # `refs/capsule/<name>/<branch>` and was two assertions red from the
        # day item 32 split the code half under `heads/` — silently, because
        # nothing runs a probe (NOTES item 38).
        CODE_REFS_A="${quarantine.codeRefsOf pairA}"
        CODE_REFS_B="${quarantine.codeRefsOf pairB}"
      '';
    runtimeInputs = [
      pkgs.iproute2
      pkgs.iputils
      pkgs.nftables # the aggregator's drops, and each capsule's own
      pkgs.procps
      pkgs.coreutils # du, dirname, date, tr
      pkgs.gnugrep
      pkgs.gnused # the allowed host comes out of the allowlist, not the probe
      pkgs.gawk # the arithmetic behind every figure
      pkgs.util-linux # runuser: enter the namespace as root, boot the VM as you
      pkgs.glibc.bin # getent, for the human's home directory
      pkgs.bash
      pkgs.socat
      pkgs.openssh
      pkgs.bind.dnsutils # whether the host's own resolver is reachable
      pkgs.git
      pkgs.nix # builds the one runner both capsules share, as the human
    ];
  };

  # Stopping a VM is two jobs, and only the second one is this program's: get
  # the guest down (`capsule-halt`, shared with the unit path), then account
  # for the hypervisor. The API-socket fallback that used to sit here is gone
  # — it was `SendCtrlAltDel`, which this guest has no keyboard to receive
  # (host/halt.nix), so it only ever bought a wait and a `nix build`.
  vm-stop = pkgs.writeShellApplication {
    name = "vm-stop";
    runtimeInputs = [capsule-halt pkgs.procps pkgs.coreutils];
    text =
      vmName {prog = "vm-stop";}
      + roomRefusal {prog = "vm-stop";}
      + ownVms
      + ''
          # `capsule-halt` is namespace-relative and takes no transport, by design:
        # it is always run somewhere ${net.guest} is directly routable — the unit
        # from inside the capsule's own namespace, this program from the root one
        # where the devshell path's tap lives. So it is not that a transport was
        # forgotten here; it is that *this* copy is only correct on a host whose
        # taps are in the root namespace, and the module path's are not.
        #
        # Which makes this `direct`'s second refusal (host/guest-ssh.nix), owed by
        # a program that never selects a capsule because its argv is the name
        # already. Without it the ssh times out at ${net.guest}, `capsule-halt`
        # reports "no guest answering" — naming the wrong cause, since the guest
        # answers fine through its relay — and then `own_vms` correctly finds no
        # VMM of *this* namespace and the fall-through prints `is down` over a
        # capsule still running. Two true-in-scope sentences that compose into a
        # false one, which is the `pkill -f` trap one level up: the scoping is
        # right and the claim it licenses is not.
        sock=${socketOf ''"$name"''}
        if [ -S "$sock" ]; then
          echo "capsule '$name' is on the module path here ($sock exists), and this" >&2
          echo "  is the devshell's stop: it would ask a guest that is not routable" >&2
          echo "  from this namespace, then report a VMM it cannot see as down." >&2
          echo "    /run/current-system/sw/bin/capsule $name stop" >&2
          exit 1
        fi

        # One link, one guest: the devshell path runs a single capsule at
        # ${net.guest}, and every name whose image is a capsule's is that same
        # guest — the image under its own name, and each declared slot. Anything
        # else (`hello`) is a VM this cannot talk to and is reaped rather than
        # asked. `vmmOf` follows the slots because the alternative is a literal
        # that silently stops asking the moment a slot is renamed, and a stop
        # that does not ask is a power cut on a mounted volume.
        #
        # And its answer is the process name the VMMs below are found by: every
        # capsule image is `microvm@capsule`, whatever slot it serves (ISS-016).
        vmm=$(vmmOf "$name")
        halted=0
        if [ "$vmm" = capsule ] && capsule-halt; then halted=1; fi

        # A guest that took the reboot exits its own VMM — that is what
        # `reboot=k` buys, measured (docs/probes.md) — so the one correct move
        # here is to wait for it. Killing while it unmounts is precisely the
        # power cut this program exists to avoid, and a volume carrying a cold
        # build is where that costs something. Bounded, because a guest that
        # took the request and then hung still has to be reaped.
        if [ "$halted" = 1 ]; then
          for _ in $(seq 300); do
            mapfile -t pids < <(own_vms "$vmm")
            [ "''${#pids[@]}" -gt 0 ] || { echo "vm-stop: $name is down"; exit 0; }
            sleep 0.2
          done
          echo "vm-stop: the guest took a reboot but its VMM outlived it" >&2
        fi

        mapfile -t pids < <(own_vms "$vmm")
        [ "''${#pids[@]}" -gt 0 ] || { echo "vm-stop: $name is down"; exit 0; }

        echo "vm-stop: terminating the VMM"
        kill "''${pids[@]}" 2>/dev/null || true
        for _ in $(seq 50); do
          mapfile -t pids < <(own_vms "$vmm")
          [ "''${#pids[@]}" -gt 0 ] || { echo "vm-stop: $name is down"; exit 0; }
          sleep 0.1
        done
        kill -9 "''${pids[@]}" 2>/dev/null || true
        sleep 0.5
        mapfile -t pids < <(own_vms "$vmm")
        [ "''${#pids[@]}" -gt 0 ] && {
          echo "vm-stop: $name will not die" >&2
          exit 1
        }
        echo "vm-stop: $name is down"
      '';
  };
in {
  nixosConfigurations = vms;

  # The host half of the perimeter as units under dedicated uids, for a NixOS
  # host that wants it as its real posture. Opt-in: `capsule-host` in the
  # devshell stays the development path and needs no rebuild. Import it in the
  # host's config and set `services.capsule-perimeter.{enable,owner}`.
  nixosModules.capsule-perimeter = capsulePerimeter;

  packages.${system} =
    lib.mapAttrs (_: cfg: cfg.config.microvm.declaredRunner) devshellVms
    # Every target's image, by the target's name, for `just build-vm`.
    // lib.mapAttrs' (name: cfg:
      lib.nameValuePair "image-${name}" cfg.config.microvm.declaredRunner)
    bound.images
    // {
      # Four programs and four suites that were conditional on `target.nix`
      # until step 6 (NOTES item 51). They are outputs like any other now,
      # which also means `just build` can no longer be made to skip a suite by
      # a value in a target's file.
      inherit capsule-baseline capsule-refresh capsule-adopt capsule-brief;
      inherit briefCases snapshotCases refreshCases baselineCases;
      inherit vm vm-stop capsule-halt capsule-net capsule-host;
      # The checks that need no root and no host: what the module says, what the
      # guard decides, and which policy a slot resolves to.
      inherit hostModuleUnits hostModulePrograms guardCases netnsCases policyCases observeCases;
      inherit profileCases gitChannelCases roomGitCases quarantineCases vmCases wrapCases volumeRootCases resetHomeCases sessionCases volumeCases fleetCases stateDirCases roomsCases fabricCases roomVerbsCases;
      # Every declared room's image, checked and built (RV-014 F-7).
      inherit roomImages;
      # The rendered run-time half of every target, so a human can read what a
      # program will resolve (host/profile.nix). `nix build .#capsule-profiles`.
      capsule-profiles = hostProfile.dir;
      # The validator as a program, and it was reachable by nobody: built only
      # as an argument to `profileCases`, in no `packages` set, in no devshell
      # and in no `systemPackages` — while `docs/contract-target.md` names it
      # as *what to run before dropping a document in*. That caller is the
      # reason it is a program at all (host/profile.nix), and item 52's whole
      # point is a producer that is not nix, so a checker only nix can reach
      # is the same gap `ISS-004` was: shipped in the abstract (`IMP-004`).
      capsule-profile-check = hostProfile.check;
      inherit capsule-cli capsule-provision capsule-collect capsule-inject;
      # A package and not a devshell program: a devshell copy would keep
      # a room's known_hosts under `$PWD/.vm/host` while the module's doors keep
      # it under the state directory, two trust stores for one room (DEC-047).
      capsule-room-git = hostPrograms.roomGit;
      inherit probe-netns probe-netns-restart probe-netns-boot probe-netns-egress;
      inherit probe-freshness probe-two-capsules;
      default = vms.capsule.config.microvm.declaredRunner;
    };

  # A consumer gets this same devshell from `mkFleet` (SL-004 design sec-4).
  devShells.${system}.default = pkgs.mkShellNoCC {
    packages = [
      vm
      vm-stop
      capsule-halt
      capsule-net
      capsule-host
      capsule-cli
      capsule-provision
      capsule-collect
      capsule-inject
      probe-netns
      probe-netns-boot
      probe-netns-egress
      probe-freshness
      probe-two-capsules
      pkgs.firecracker
      pkgs.just
      # `just ssh` reaches a namespaced capsule through its relay socket, so
      # the devshell needs the same tool the units do.
      pkgs.socat
      microvm.packages.${system}.microvm # `microvm` CLI (host-module workflows)
      # stdenv's PATH carries plain `pkgs.bash`, which is built without readline
      # or progcomp: running `bash` in here gave `complete: command not found`
      # and a prompt full of literal \[ \]. `packages` comes first, so this puts
      # the real one back. Not repo-specific — every nix devshell does it.
      pkgs.bashInteractive
      capsule-baseline
      capsule-refresh
      capsule-adopt
      capsule-brief
      doctrine.packages.${system}.default
      # Takes a file and nothing else — no state, no transport, no name to
      # resolve — so the devshell copy and the module's are the same store path
      # and neither needs the wrapper.
      hostProfile.check
    ];
    shellHook = ''
      echo "capsule — firecracker. host side:  capsule-net up  &&  capsule-host"
      echo "                       guest side: vm capsule   (or: vm hello)"
      echo "                       then:       capsule-provision / capsule-inject"
      echo "                                   capsule-baseline (to green)"
      echo "                       and back:   capsule-collect"

      # A root that is not this checkout is the caller's to set, so it is
      # reported and never overridden (RV-012 F-7; `ISS-004` is why a hook
      # must not assign it). `-ef`, because a symlinked checkout is the same one.
      (
        ${rootFragment}
        if [ ! "$root" -ef "$PWD" ]; then
          echo "capsule: $root is not this checkout ($PWD); left as set" >&2
        fi
      )

      # Re-pointed on every entry, so the link names this devshell's oubliette
      # (DEC-028); like any devshell binary it is stale until re-entry.
      if [ -e .oubliette ] && [ ! -L .oubliette ]; then
        echo "capsule: .oubliette exists and is not a link; left alone" >&2
      elif [ -f flake.nix ]; then
        ln -sfn ${./just} .oubliette
      fi
    '';
  };
}
