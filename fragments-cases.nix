# `fragmentsCases` — what a room's door and its fragments promise — SL-009 design sec-5, sec-6;
# DEC-066 (the door's rules), DEC-060 (sudo is off, not emptied), RV-025 F-3.
#
# The subject is a *composition*: `fragments.nix`' selections and `roomChecks`'
# rules, applied to the images mkfleet.nix evaluates. **Handed evaluated fixture
# images, not a render of its own**: `roomChecks` and `roomVms` are the shipped
# rule list and the fixture rooms `lounge` and `assistant`, and `capsuleImage` is
# one evaluated capsule image. A negative case is `extendModules` on a fixture
# room, so what fails is the shipped image plus one deliberate change, and a
# verdict is read as the failing rule's `reason`, never a bare `tryEval`.
#
# Cases 4-6 and 9 (PHASE-03) read a room's postgresql-18 fragment and its
# persistence: the module's settings off the evaluated image, its reserved-name
# assertion by extending a room with a login, and the persistence rules
# (`roomChecks`' `persistence:` reasons) by `mkForce`-ing the bind's `fsType` or
# its options so exactly one rule fails.
#
# What it does not prove (STD-001): that any room boots, or that sshd answers
# there; that `postgresql.target` comes up, that the bind is ordered after
# `/home` as the unit text says, or that peer auth admits a login over a
# forward (SL-009 PHASE-05, ASM-005/006).
#
# The door rules are a regression guard over *named settings* (sec-5): a room
# that reaches the same end by another setting passes them, and a rule that
# names a setting says nothing of what a booted guest does with it.
#
# Cases are ordered by the phase that added them (1-3 and 7 first, then PHASE-03's
# 4-6 and 9), not by design number.
{
  pkgs,
  lib,
  # `import ./fragments.nix`, applied: the shipped vocabulary.
  fragments,
  # mkfleet.nix' `roomChecks`: name -> evaluated image -> [{ok; reason;}].
  roomChecks,
  # mkfleet.nix' `roomVms`: room name -> evaluated nixosConfiguration.
  roomVms,
  # `bound.images.${probeTarget}`, an evaluated image.
  capsuleImage,
  # The `flavour` that image was built with (mkFleet's argument): an evaluated
  # image does not expose its specialArgs, so the suite is handed the value.
  flavour,
  # mkfleet.nix' `roomRecords`: the declared rooms, as `rooms.nix` decided them.
  # Case 4 derives a room's declared users from here, not from the module's own
  # expression over `config.users.users`, which would agree with itself.
  roomRecords,
}: let
  # The rules an image breaks, as their reasons.
  failing = name: cfg: map (c: c.reason) (lib.filter (c: !c.ok) (roomChecks name cfg));
  joinReasons = lib.concatStringsSep "; ";
  rooms = lib.attrNames roomVms;

  # A fixture room plus one change.
  extended = name: module: roomVms.${name}.extendModules {modules = [module];};

  # `assistant` made an elevation: sudo forced on (a plain `true` would conflict
  # with the room's `false` at eval, a different failure) with a NOPASSWD rule.
  nopasswdSudo = extended "assistant" {
    security.sudo.enable = lib.mkForce true;
    security.sudo.extraRules = [
      {
        users = ["agent"];
        commands = [
          {
            command = "ALL";
            options = ["NOPASSWD"];
          }
        ];
      }
    ];
  };

  # An image's refusal reasons: the messages of its failing assertions.
  refusals = cfg: map (a: a.message) (lib.filter (a: !a.assertion) cfg.config.assertions);

  # PHASE-03: the fixture room that selects postgresql-18, the one that selects
  # no fragment, and a login added to either (a reserved role name, or not).
  clean = roomVms.assistant;
  withLogin = room: name:
    extended room {
      users.users.${name} = {
        isNormalUser = true;
        uid = 2001;
      };
    };
  asPg = clean.config.services.postgresql;
  # The room's declared users, from the record rather than the module.
  declared = lib.attrNames roomRecords.assistant.users;
  # What case 4 pins about the access rules: the suite's own text, one rule per
  # line, not an import of the fragment's.
  wantedAuthentication = ''
    local all      postgres peer map=postgres
    local samerole all      peer
  '';
  # An `ensureUsers` entry's clauses that are set: none, for any login.
  setClauses = u: lib.filterAttrs (_: v: v != null) u.ensureClauses;
  # The persistence rules' reasons (mkfleet.nix tags each `persistence:`).
  persistenceFailing = name: cfg: lib.filter (lib.hasInfix "persistence:") (failing name cfg);
  # The bind's path, read off the vocabulary and not retyped. A room with no
  # entry gets a no-op extension, so a missing render reads as FAIL lines (the
  # extension breaks no rule) and not as an abort over a half-declared entry.
  binds = fragments.persists roomRecords.assistant.extras;
  breakBind = attrs:
    extended "assistant" (lib.optionalAttrs (binds != []) {
      fileSystems.${(lib.head binds).path} = attrs;
    });
  # One persistence rule broken each: `mkForce`, since a plain `"auto"` would
  # conflict with the room's `"none"` at eval and `options` concatenates.
  fsAuto = breakBind {fsType = lib.mkForce "auto";};
  noRequires = breakBind {options = lib.mkForce ["bind" "x-systemd.after=room-persist.service"];};
  json = builtins.toJSON;

  # The same capsule image selecting one more fragment.
  capsuleWithPg = capsuleImage.extendModules {
    specialArgs.flavour = flavour // {extras = flavour.extras ++ ["postgresql-18"];};
  };

  # `null` becomes "" so an absent refusal is a `has` FAIL, not an eval abort.
  refusalText = extras: lib.optionalString (fragments.slotRefusal extras != null) (fragments.slotRefusal extras);
  pgRefusal = refusalText ["postgresql-18"];
in
  pkgs.runCommand "fragments-cases" {} ''
    fail=0
    log=$out
    : >"$log"
    ck() {
      if [ "$2" = "$3" ]; then echo "ok   $1" >>"$log"
      else echo "FAIL $1: got '$3', wanted '$2'" >&2; fail=1; fi
    }
    has() {
      case "$3" in
        *"$2"*) echo "ok   $1" >>"$log" ;;
        *) echo "FAIL $1: '$3' does not mention '$2'" >&2; fail=1 ;;
      esac
    }

    # 1. A slot refuses a capability fragment and names it; package-only is fine.
    ck "slotRefusal of a package-only selection is null" true ${lib.boolToString (fragments.slotRefusal ["agents"] == null)}
    has "slotRefusal names the capability fragment" postgresql-18 ${lib.escapeShellArg (refusalText ["search" "postgresql-18"])}

    # 2. A capsule image selecting it carries that refusal as a failing
    # assertion (read from config.assertions, RV-025 F-8). Control first.
    ck "the fixture capsule refuses nothing" "" ${lib.escapeShellArg (joinReasons (refusals capsuleImage))}
    ck "a capsule selecting postgresql-18 has exactly one failing assertion" 1 ${toString (builtins.length (refusals capsuleWithPg))}
    has "  and it names postgresql-18" postgresql-18 ${lib.escapeShellArg (joinReasons (refusals capsuleWithPg))}
    ck "  and the capsule reports slotRefusal's message, not a second one" true ${lib.boolToString (lib.elem pgRefusal (refusals capsuleWithPg))}
    # The fragment adds no packages to a capsule: the package count is unchanged.
    ck "  and selecting it adds no packages to the capsule" ${toString (builtins.length capsuleImage.config.environment.systemPackages)} ${toString (builtins.length capsuleWithPg.config.environment.systemPackages)}

    # 3. The selections: paths in selection order, and no module for a package-only one.
    ck "persists names the fragment and its path" ${lib.escapeShellArg (builtins.toJSON [
      {
        name = "postgresql-18";
        path = "/var/lib/postgresql";
      }
    ])} ${lib.escapeShellArg (builtins.toJSON (fragments.persists ["search" "postgresql-18"]))}
    ck "modules of a package-only selection is empty" "[]" ${lib.escapeShellArg (builtins.toJSON (fragments.modules ["search"]))}

    # 4. `assistant` selects postgresql-18: the module's settings off the
    # evaluated image (merged values, so a default that wins would show).
    ck "assistant enables postgresql" true ${lib.boolToString asPg.enable}
    ck "  at major 18" 18 ${lib.optionalString asPg.enable (lib.versions.major asPg.package.version)}
    ck "  listening on no address" "" ${lib.escapeShellArg (asPg.settings.listen_addresses or "<unset>")}
    ck "  with exactly the two access rules" ${lib.escapeShellArg wantedAuthentication} ${lib.escapeShellArg asPg.authentication}
    ck "  ensureUsers names exactly the declared users" ${lib.escapeShellArg (json declared)} ${lib.escapeShellArg (json (map (u: u.name) asPg.ensureUsers))}
    ck "  each owning its database" true ${lib.boolToString (lib.all (u: u.ensureDBOwnership) asPg.ensureUsers)}
    ck "  and carrying no clause" "[]" ${lib.escapeShellArg (json (lib.filter (c: c != {}) (map setClauses asPg.ensureUsers)))}
    ck "  ensureDatabases is the same list" ${lib.escapeShellArg (json declared)} ${lib.escapeShellArg (json asPg.ensureDatabases)}
    ck "  and no assertion fails" "" ${lib.escapeShellArg (joinReasons (refusals clean))}

    # 5. A reserved login fails the fragment's assertion and only that one
    # (RV-025 F-6, F-9, F-11). The clean room above is the control.
    ${lib.concatMapStrings (user: ''
        ck ${lib.escapeShellArg "a login '${user}' fails exactly one assertion"} 1 ${toString (builtins.length (refusals (withLogin "assistant" user)))}
        has ${lib.escapeShellArg "  and it names '${user}'"} ${lib.escapeShellArg user} ${lib.escapeShellArg (joinReasons (refusals (withLogin "assistant" user)))}
        has ${lib.escapeShellArg "  and it is the fragment's"} "fragments.nix postgresql-18:" ${lib.escapeShellArg (joinReasons (refusals (withLogin "assistant" user)))}
      '')
      ["pg_demo" "template1" "shared_x"]}

    # 6. `lounge` selects no fragment: nothing of it is rendered, and the
    # reserved names bind only a room that selects it.
    ck "lounge does not enable postgresql" false ${lib.boolToString roomVms.lounge.config.services.postgresql.enable}
    ck "  has no filesystem at the bind" false ${lib.boolToString (roomVms.lounge.config.fileSystems ? "/var/lib/postgresql")}
    ck "  has no room-persist unit" false ${lib.boolToString (roomVms.lounge.config.systemd.services ? room-persist)}
    ck "  and a login 'pg_demo' fails no assertion there" "" ${lib.escapeShellArg (joinReasons (refusals (withLogin "lounge" "pg_demo")))}

    # 9. The persistence rules (DEC-061, RV-025 F-2, F-4), each over one break.
    # Control first: the room as shipped fails none of them.
    ck "assistant fails no persistence rule" "" ${lib.escapeShellArg (joinReasons (persistenceFailing "assistant" clean))}
    ck "a bind with fsType 'auto' fails exactly one persistence rule" 1 ${toString (builtins.length (persistenceFailing "assistant" fsAuto))}
    has "  and it is the fsType rule" fsType ${lib.escapeShellArg (joinReasons (persistenceFailing "assistant" fsAuto))}
    ck "a bind without x-systemd.requires fails exactly one persistence rule" 1 ${toString (builtins.length (persistenceFailing "assistant" noRequires))}
    has "  and it is the requires rule" x-systemd.requires ${lib.escapeShellArg (joinReasons (persistenceFailing "assistant" noRequires))}

    # 7. The door's elevation rule (DEC-060, RV-025 F-3). Control first: every
    # fixture room passes every rule, and a failure prints why.
    ${lib.concatMapStrings (name: ''
        ck ${lib.escapeShellArg "room '${name}' passes every roomChecks rule"} "" ${lib.escapeShellArg (joinReasons (failing name roomVms.${name}))}
      '')
      rooms}
    # Then one change: the NOPASSWD sudo fails the elevation rule and only it.
    ck "a NOPASSWD sudo in a room fails exactly one rule" 1 ${toString (builtins.length (failing "assistant" nopasswdSudo))}
    has "  and that rule is the elevation rule" "no elevation" ${lib.escapeShellArg (joinReasons (failing "assistant" nopasswdSudo))}

    cat "$log"
    exit "$fail"
  ''
