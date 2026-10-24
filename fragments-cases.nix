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
# `fragments` and `capsuleImage` are used from PHASE-02 (the fragment
# selections and the capsule's refusal); the signature is fixed so later phases
# add cases without restructuring.
#
# What it does not prove (STD-001): that any room boots, or that sshd answers
# there. The door rules are a regression guard over *named settings* (sec-5):
# a room that reaches the same end by another setting passes them, and a rule
# that names a setting says nothing of what a booted guest does with it.
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
}: let
  # The rules an image breaks, as their reasons.
  failing = name: cfg: map (c: c.reason) (lib.filter (c: !c.ok) (roomChecks name cfg));
  reasonsOf = name: cfg: lib.concatStringsSep "; " (failing name cfg);
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

  # The same capsule image selecting one more fragment.
  baseFlavour = flavour;
  capsuleWithPg = capsuleImage.extendModules {
    specialArgs.flavour = baseFlavour // {extras = baseFlavour.extras ++ ["postgresql-18"];};
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
    ck "the fixture capsule refuses nothing" "" ${lib.escapeShellArg (lib.concatStringsSep "; " (refusals capsuleImage))}
    ck "a capsule selecting postgresql-18 has exactly one failing assertion" 1 ${toString (builtins.length (refusals capsuleWithPg))}
    has "  and it names postgresql-18" postgresql-18 ${lib.escapeShellArg (lib.concatStringsSep "; " (refusals capsuleWithPg))}
    ck "  and it is slotRefusal's own message" true ${lib.boolToString (lib.elem pgRefusal (refusals capsuleWithPg))}
    # Liveness: the extended image evaluates past its assertions (no packages added).
    ck "  and the extended image still evaluates its package set" ${toString (builtins.length capsuleImage.config.environment.systemPackages)} ${toString (builtins.length capsuleWithPg.config.environment.systemPackages)}

    # 3. The selections: paths in selection order, and no module for a package-only one.
    ck "persists names the fragment and its path" ${lib.escapeShellArg (builtins.toJSON [
      {
        name = "postgresql-18";
        path = "/var/lib/postgresql";
      }
    ])} ${lib.escapeShellArg (builtins.toJSON (fragments.persists ["search" "postgresql-18"]))}
    ck "modules of a package-only selection is empty" "[]" ${lib.escapeShellArg (builtins.toJSON (fragments.modules ["search"]))}

    # 4-6, 8. A room's persistence and the postgresql fragment (PHASE-03).

    # 7. The door's elevation rule (DEC-060, RV-025 F-3). Control first: every
    # fixture room passes every rule, and a failure prints why.
    ${lib.concatMapStrings (name: ''
        ck ${lib.escapeShellArg "room '${name}' passes every roomChecks rule"} "" ${lib.escapeShellArg (reasonsOf name roomVms.${name})}
      '')
      rooms}
    # Then one change: the NOPASSWD sudo fails the elevation rule and only it.
    ck "a NOPASSWD sudo in a room fails exactly one rule" 1 ${toString (builtins.length (failing "assistant" nopasswdSudo))}
    has "  and that rule is the elevation rule" "no elevation" ${lib.escapeShellArg (reasonsOf "assistant" nopasswdSudo)}

    cat "$log"
    exit "$fail"
  ''
