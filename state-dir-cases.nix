# What `mkFleet` accepts as this host's state root — SL-008 design sec-2,
# `DEC-054`, RV-023 F-4.
#
# The subject is a *library*, not a program: `state-dir.nix` is the function its
# one caller (mkfleet.nix) applies to the declared `stateDir`, and this suite
# applies the same function to values that are nobody's root. So every verdict
# is a value of the function rather than of this host (CLAUDE.md, the library
# rule), and nothing here is a path anything reads.
#
# What it pins is mostly `throw`s, so the verdicts are read at eval with
# `builtins.tryEval` and asserted in the shell — `hostModuleUnits`' arrangement
# (CLAUDE.md). `tryEval` forces only the outer layer, so every case forces the
# value it pins with `deepSeq`; and because a verdict alone cannot say *why*,
# each refusal's message is also read off `reasons`, the string the value
# throws. Every value and reason crosses into the script through
# `lib.escapeShellArg`: the hostile values are hostile to this builder too.
{
  pkgs,
  lib,
  # `import ./state-dir.nix`, unapplied: the function mkfleet.nix calls.
  stateDir,
}: let
  check = stateDir {inherit lib;};

  # Each refusal fails exactly one rule, and `says` is the part of the reason
  # that only that rule's failure writes — the rule itself is spelled in every
  # reason, so a needle drawn from it would pass for any refusal at all.
  refusals = [
    {
      what = "a relative path";
      value = "var/lib/capsule";
      says = "is not absolute";
    }
    {
      what = "the empty string";
      value = "";
      says = "is not absolute";
    }
    {
      what = "a '..' component";
      value = "/var/lib/../capsule";
      says = ''has a component that is not a name: ".."'';
    }
    {
      what = "the root itself";
      value = "/";
      says = ''has a component that is not a name: ""'';
    }
    {
      what = "a trailing slash";
      value = "/var/lib/capsule/";
      says = ''has a component that is not a name: ""'';
    }
    {
      what = "a space";
      value = "/var/lib/my capsule";
      says = ''contains " "'';
    }
    {
      what = "a '%'";
      value = "/var/lib/capsule%h";
      says = ''contains "%"'';
    }
    # The offending characters, all of them: with `$` admitted to the set the
    # parentheses still refuse this value, and only this line can tell.
    {
      what = "a command substitution";
      value = "/tmp/$(id)";
      says = ''contains "$()"'';
    }
    {
      what = "a quote";
      value = "/var/lib/capsule'x";
      says = ''contains "'"'';
    }
  ];
  acceptances = ["/var/lib/capsule" "/build/state"];

  # Does forcing this value throw? `deepSeq` is load-bearing (see header).
  throws = x: !(builtins.tryEval (builtins.deepSeq x x)).success;
  verdict = x: lib.boolToString (throws x);
  reason = r:
    if r == null
    then ""
    else r;
  q = lib.escapeShellArg;
in
  pkgs.runCommand "state-dir-cases" {} ''
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

    # 1. Each hostile value is refused, naming itself, the rule it broke, and
    #    the decision.
    ${lib.concatMapStrings (c: let
        r = check c.value;
        why = q (reason r.reasons.stateDir);
      in ''
        ck ${q "${c.what} is refused"} true ${verdict r.value}
        has "  naming the value" ${q (builtins.toJSON c.value)} ${why}
        has "  saying why" ${q c.says} ${why}
        has "  and the rule" DEC-054 ${why}
      '')
      refusals}

    # 2. A safe absolute path is accepted as it is, with nothing to say.
    ${lib.concatMapStrings (v: let
        r = check v;
      in ''
        ck ${q "${v} is accepted"} false ${verdict r.value}
        ck "  with no reason to refuse it" "" ${q (reason r.reasons.stateDir)}
        ck "  and is the value declared" ${q v} ${q r.value}
      '')
      acceptances}

    cat "$log"
    exit "$fail"
  ''
