# What `mkFleet` accepts as the model door — SL-010 design sec-2 and sec-6,
# `DEC-069`, `DEC-071`.
#
# The subject is a *library*, as `state-dir-cases.nix`'s is: `model-door.nix` is
# the function mkfleet.nix applies to the caller's `net.modelDoor`, `fleet` and
# `net.proxyPort`, and this suite applies it to declarations nobody has. The
# verdicts are `throw`s, so they are read at eval with `builtins.tryEval` and
# asserted in the shell; every case forces what it pins with `deepSeq`, and the
# message is read off `reasons` because a verdict cannot say *why*.
#
# Each refusal breaks exactly one rule: the key it breaks must hold a reason
# naming the field, the value, its own `says` and the decision, and every other
# key must be null — otherwise a round would pass for the rule next door. One
# round breaks two on purpose, to pin which the value throws first.
{
  pkgs,
  lib,
  # `import ./model-door.nix`, unapplied: the function mkfleet.nix calls.
  modelDoor,
}: let
  check = modelDoor {inherit lib;};
  proxyPort = 3128;
  keys = ["slotValue" "undeclared" "port" "socket" "masked"];

  # Values no host declares.
  door = {
    port = 4000;
    socket = "/run/fixture-model-door/api.sock";
  };
  slots = {
    alpha = {
      index = 0;
      modelDoor = "on";
    };
    beta.index = 1;
  };
  declare = d: s:
    check {
      modelDoor = d;
      slots = s;
      inherit proxyPort;
    };
  withPort = p: door // {port = p;};
  withSocket = s: door // {socket = s;};
  slotsWith = v: slots // {alpha = slots.alpha // {modelDoor = v;};};

  mk = key: says: what: d: s: {inherit key says what d s;};
  # `says` are needles that only this rule's failure writes, plus the field and
  # the value, so a reason naming some other rule cannot satisfy them.
  portRound = p: mk "port" ["net.modelDoor.port" (builtins.toJSON p)] "port ${builtins.toJSON p}" (withPort p) slots;
  socketRound = what: s: says: mk "socket" (["net.modelDoor.socket" (builtins.toJSON s)] ++ says) what (withSocket s) slots;
  maskedRound = s: tree: setting: mk "masked" ["net.modelDoor.socket" (builtins.toJSON s) tree setting] "a socket under ${tree}" (withSocket s) slots;

  refusals =
    [
      (mk "slotValue" ["modelDoor" "alpha" (builtins.toJSON "yes")] "a slot door of \"yes\"" door (slotsWith "yes"))
      (mk "undeclared" ["net.modelDoor" "alpha"] "a slot door with no net.modelDoor" null slots)
    ]
    ++ map portRound [22 proxyPort 443 0 65536 "4000"]
    ++ [
      (socketRound "a relative socket" "run/x.sock" ["is not absolute"])
      (socketRound "a ',' in the socket" "/run/fixture-model-door/a,b.sock" [''contains ","''])
      (socketRound "a ':' in the socket" "/run/fixture-model-door/a:b.sock" [''contains ":"''])
      (socketRound "a '..' in the socket" "/run/fixture-model-door/../api.sock" [''has a component that is not a name: ".."''])
      (maskedRound "/home/u/s.sock" "/home" "ProtectHome")
      (maskedRound "/root/s.sock" "/root" "ProtectHome")
      (maskedRound "/run/user/1000/s.sock" "/run/user" "ProtectHome")
      (maskedRound "/tmp/s.sock" "/tmp" "PrivateTmp")
      (maskedRound "/var/tmp/s.sock" "/var/tmp" "PrivateTmp")
    ];

  acceptances = [
    {
      what = "the base declaration";
      d = door;
      s = slots;
    }
    {
      what = "port 1024";
      d = withPort 1024;
      s = slots;
    }
    {
      what = "port 65535";
      d = withPort 65535;
      s = slots;
    }
    {
      what = "a slot door of \"off\"";
      d = door;
      s = slotsWith "off";
    }
    {
      what = "no door and no slot declaring one";
      d = null;
      s = {beta.index = 1;};
    }
  ];

  # Does forcing this value throw? `deepSeq` is load-bearing (see header).
  throws = x: !(builtins.tryEval (builtins.deepSeq x x)).success;
  verdict = x: lib.boolToString (throws x);
  reason = r:
    if r == null
    then ""
    else r;
  q = lib.escapeShellArg;
in
  pkgs.runCommand "model-door-cases" {} ''
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

    # 1. Each refusal is a refusal, and says why in the key it breaks alone.
    ${lib.concatMapStrings (c: let
        r = declare c.d c.s;
        why = q (reason r.reasons.${c.key});
      in ''
        ck ${q "${c.what} is refused"} true ${verdict r.value}
        ${lib.concatMapStrings (n: ''
            has ${q "  saying ${n}"} ${q n} ${why}
          '')
          c.says}
        has "  and the rule" ${
          if c.key == "slotValue"
          then "DEC-069"
          else "DEC-071"
        } ${why}
        ${lib.concatMapStrings (k: ''
          ck ${q "  and not by ${k}"} "" ${q (reason r.reasons.${k})}
        '') (lib.remove c.key keys)}
      '')
      refusals}

    # 2. A declaration breaking two rules throws the first in sec-2's order.
    ${let
      r = declare (withPort 22) (slotsWith "yes");
    in ''
      ck "slot value and port 22 together are refused" true ${verdict r.value}
      has "  slotValue is the first reason" DEC-069 ${q (reason r.reasons.slotValue)}
      has "  and port is also broken" DEC-071 ${q (reason r.reasons.port)}
    ''}

    # 3. A sound declaration is accepted as it is, with nothing to say.
    ${lib.concatMapStrings (c: let
        r = declare c.d c.s;
      in ''
        ck ${q "${c.what} is accepted"} false ${verdict r.value}
        ${lib.concatMapStrings (k: ''
            ck ${q "  with no ${k} reason"} "" ${q (reason r.reasons.${k})}
          '')
          keys}
        ck "  and is the value declared" ${q (builtins.toJSON c.d)} ${q (builtins.toJSON r.value)}
      '')
      acceptances}

    cat "$log"
    exit "$fail"
  ''
