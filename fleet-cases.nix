# What the fleet's binding decides — SL-003 design sec-3 and sec-6.
#
# The subject is a *library*, not a program: `fleet.nix` is the function its one
# caller (flake.nix) applies, and this suite applies the same function to a stub
# `mkVm` and to fixtures that are no host's — two targets nobody declares and
# slots nobody runs. So it never builds a NixOS system, and every verdict is a
# value of the function rather than of this host (CLAUDE.md, the library rule).
#
# **Handed a fixture, and it says so**: `targets`, `targetFlakes` and
# `capsules` below are invented. The stub `mkVm` returns its arguments, so a case
# can read which target and which flake an image was given.
#
# What it pins is mostly `throw`s, so the verdicts are read at eval with
# `builtins.tryEval` and asserted in the shell — `hostModuleUnits`' arrangement
# (CLAUDE.md). fleet's result is a lazy attrset and `tryEval` forces only its
# outer layer, so **every throw case forces the attribute it pins** with
# `deepSeq`; without it a throw case passes with the throw never evaluated
# (RV-010 F-6). And because a verdict alone cannot say *why*, each refusal's
# message is also read off `reasons`, the string fleet.nix throws.
{
  pkgs,
  lib,
  # `import ./fleet.nix`, unapplied: the function flake.nix calls.
  fleet,
}: let
  # An image is just what mkVm was handed.
  mkVm = hostName: module: args: {
    inherit hostName module;
    specialArgs = args;
  };
  apply = fleet {inherit lib mkVm;};

  targets = {
    volumePath = "/work";
    byName = {
      alpha = {name = "alpha";};
      beta = {name = "beta";};
    };
  };
  targetFlakes = {
    alpha = "flake-alpha";
    beta = "flake-beta";
  };
  slot = profile: {inherit profile;};
  good = apply {
    inherit targets targetFlakes;
    capsules.instances = {
      s1 = slot "alpha";
      s2 = slot "alpha";
      s3 = slot "beta";
    };
    probeTarget = "beta";
  };
  with' = over:
    apply ({
        inherit targets targetFlakes;
        probeTarget = "alpha";
      }
      // over);

  unknownProfile = with' {
    capsules.instances = {
      s1 = slot "alpha";
      stray = slot "gamma";
    };
  };
  noProfile = with' {
    capsules.instances = {
      s1 = slot "alpha";
      bare = slot null;
    };
  };
  missingFlake = with' {
    capsules.instances = {s1 = slot "alpha";};
    targetFlakes = {alpha = "flake-alpha";};
  };
  extraFlake = with' {
    capsules.instances = {s1 = slot "alpha";};
    targetFlakes = targetFlakes // {delta = "flake-delta";};
  };

  # Does forcing this attribute throw? `deepSeq` is load-bearing (see header).
  throws = x: !(builtins.tryEval (builtins.deepSeq x x)).success;
  verdict = x: lib.boolToString (throws x);
  reason = r:
    if r == null
    then ""
    else r;
in
  pkgs.runCommand "fleet-cases" {} ''
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

    # 1. A slot whose profile names no target throws, naming the slot.
    ck "a slot whose profile names no target throws" true ${verdict unknownProfile.slotImages}
    ck "  and so does every vm, which holds the slots" true ${verdict unknownProfile.vms}
    has "  naming the slot" stray ${lib.escapeShellArg (reason unknownProfile.reasons.slotImages)}
    has "  and the rule" DEC-017 ${lib.escapeShellArg (reason unknownProfile.reasons.slotImages)}

    # 2. A slot with no profile throws.
    ck "a slot with no profile throws" true ${verdict noProfile.slotImages}
    has "  naming the slot" bare ${lib.escapeShellArg (reason noProfile.reasons.slotImages)}

    # 3. targetFlakes must name exactly the declared targets.
    ck "targetFlakes missing a target throws" true ${verdict missingFlake.images}
    has "  naming the target" beta ${lib.escapeShellArg (reason missingFlake.reasons.images)}
    ck "targetFlakes with an extra entry throws" true ${verdict extraFlake.images}
    has "  naming the entry" delta ${lib.escapeShellArg (reason extraFlake.reasons.images)}
    ck "  and the slots, which are images, throw with it" true ${verdict extraFlake.slotImages}

    # A well-formed fleet throws nowhere and has nothing to say.
    ck "a well-formed fleet's vms evaluate" false ${verdict good.vms}
    ck "  with no reason to refuse its images" "" ${lib.escapeShellArg (reason good.reasons.images)}
    ck "  or its slots" "" ${lib.escapeShellArg (reason good.reasons.slotImages)}

    # 4. Two slots with one profile get the same image value (structural sharing).
    ck "two slots with one profile get the same image" true \
      ${lib.boolToString (good.slotImages.s1 == good.slotImages.s2)}
    ck "  and a slot with another profile gets another" false \
      ${lib.boolToString (good.slotImages.s1 == good.slotImages.s3)}

    # 5. Each image is given its own target and its own flake.
    ${lib.concatMapStrings (n: ''
      ck "image ${n} is given target ${n}" ${n} ${good.images.${n}.specialArgs.target.name}
      ck "  and its flake" flake-${n} ${good.images.${n}.specialArgs.targetFlake}
      ck "  and is the capsule module, as hostName capsule" capsule ${good.images.${n}.hostName}
    '') (builtins.attrNames targets.byName)}
    ck "there is one image per target and no more" "alpha beta" \
      ${lib.escapeShellArg (toString (builtins.attrNames good.images))}

    # 6. vms.capsule is the probe target's image; vms holds it and the slots.
    ck "vms.capsule is the probe target's image" true \
      ${lib.boolToString (good.vms.capsule == good.images.beta)}
    ck "  and vms is capsule plus the slots" "capsule s1 s2 s3" \
      ${lib.escapeShellArg (toString (builtins.attrNames good.vms))}

    cat "$log"
    exit "$fail"
  ''
