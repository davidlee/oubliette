# What a room declaration decides — SL-005 design sec-2, DEC-038.
#
# The subject is a *library*, not a program: `rooms.nix` is the function its one
# caller (mkfleet.nix) applies, and this suite applies the same function to
# fixtures that are no host's — slots `s1` and `s2` that nobody runs, and rooms
# nobody declares. Every verdict is a value of the function.
#
# **Handed a fixture, and it says so**: `slotNames`, the keys and the sizes below
# are invented.
#
# What it pins is mostly `throw`s, so the verdicts are read at eval with
# `builtins.tryEval` and asserted in the shell (`fleet-cases.nix`' arrangement).
# `instances` is a lazy attrset and `tryEval` forces only its outer layer, so
# **every throw case forces the attribute it pins** with `deepSeq`; without it a
# throw case passes with the throw never evaluated (RV-010 F-6). And because a
# verdict cannot say *why*, each refusal is also read off `reasons`, the string
# `rooms.nix` throws.
#
# What it does not prove (STD-001): that `mkFleet` applies `rooms.nix` to the
# caller's declaration (it does, once; nothing here watches it), that any unit,
# namespace or image exists for a room, or that the front end can name one. It
# is the function's verdicts over fixtures, and nothing more.
{
  pkgs,
  lib,
  # `import ./rooms.nix`, unapplied: the function mkfleet.nix calls.
  rooms,
}: let
  apply = rooms {inherit lib;};
  slotNames = ["s1" "s2"];
  with' = decls:
    apply {
      rooms = decls;
      inherit slotNames;
    };

  key = "ssh-ed25519 AAAA fixture";
  sizes = {
    vcpu = 1;
    mem = 512;
    volume = "1G";
  };
  # A room whose only variable is its users.
  withUsers = users: {inherit users sizes;};
  # A user with one key and the uid given, which is all a user declares.
  as = uid: {
    inherit uid;
    keys = [key];
  };
  # A room that is fine in every way but its name.
  named = name: with' {${name} = withUsers {ada = as 1001;};};

  good = with' {
    lounge = withUsers {
      ada = as 1001;
      bob = {
        uid = 1002;
        keys = [key key];
      };
    };
    assistant = withUsers {agent = as 1001;};
  };

  # One user, and then one whose name sorts before it (RSK-012): NixOS
  # allocates undeclared uids in name order on every boot, so this is the
  # change that would move `bob` off his files.
  bobAlone = with' {lounge = withUsers {bob = as 1002;};};
  bobAfterAaron = with' {
    lounge = withUsers {
      aaron = as 1001;
      bob = as 1002;
    };
  };

  # Does forcing this attribute throw? `deepSeq` is load-bearing (see header).
  throws = x: !(builtins.tryEval (builtins.deepSeq x x)).success;
  verdict = x: lib.boolToString (throws x);
  reason = r:
    if r == null
    then ""
    else r;

  # One refusal, both halves: `instances` throws, and `reasons.<field>` says
  # why — naming every needle. Needles are the offender and the clause.
  refused = title: decl: field: needles: ''
    ck ${lib.escapeShellArg title} true ${verdict decl.instances}
    ${lib.concatMapStrings (n: ''
        has ${lib.escapeShellArg "  naming ${n}"} ${lib.escapeShellArg n} ${lib.escapeShellArg (reason decl.reasons.${field})}
      '')
      (needles ++ ["DEC-038"])}
  '';
in
  pkgs.runCommand "rooms-cases" {} ''
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

    # 1-4. A room name that collides, or that a unit cannot carry.
    ${refused "a room named for a slot throws" (named "s1") "names" ["s1" "slot"]}
    ${refused "a room named hello throws" (named "hello") "names" ["hello" "reserved"]}
    ${refused "a room named capsule throws" (named "capsule") "names" ["capsule" "reserved"]}
    ${refused "a room name with a dot throws" (named "x.y") "names" ["x.y" "unit-safe"]}
    ${refused "a room name that starts with a dash throws" (named "-x") "names" ["-x" "unit-safe"]}

    # 5-7. A user that may not log in, or that has no way to.
    ${refused "a user named root throws" (with' {lounge = withUsers {root = as 1001;};}) "users" ["lounge" "root"]}
    ${refused "a user with no keys throws" (with' {lounge = withUsers {ada = (as 1001) // {keys = [];};};}) "users" ["lounge/ada" "no keys"]}
    ${refused "a user name that is not user-safe throws" (with' {lounge = withUsers {Ada = as 1001;};}) "users" ["lounge" "Ada" "user-safe"]}
    ${refused "a user name over 31 characters throws" (with' {lounge = withUsers {${lib.concatStrings (lib.replicate 32 "a")} = as 1001;};}) "users" ["lounge" "user-safe"]}

    # 7a-7e. A user's uid is declared, in range, and its own (RSK-012): the
    # volume outlives the image, so the number that owns a home's files must
    # be the same on every boot, and nothing here picks one.
    ${refused "a user declared as a bare key list throws" (with' {lounge = withUsers {ada = [key];};}) "users" ["lounge/ada" "{ uid; keys; }"]}
    ${refused "a user with a field beyond uid and keys throws" (with' {lounge = withUsers {ada = (as 1001) // {uids = 1001;};};}) "users" ["lounge/ada" "{ uid; keys; }"]}
    ${refused "a user with no uid throws" (with' {lounge = withUsers {ada = {keys = [key];};};}) "users" ["lounge/ada" "no uid"]}
    ${refused "a uid below the normal-user range throws" (with' {lounge = withUsers {ada = as 999;};}) "users" ["lounge/ada (999)" "1000-29999"]}
    ${refused "a uid above it, where NixOS keeps nixbld, throws" (with' {lounge = withUsers {ada = as 30000;};}) "users" ["lounge/ada (30000)" "1000-29999"]}
    ${refused "a uid that is not a number throws" (with' {lounge = withUsers {ada = as "1001";};}) "users" ["lounge/ada (\"1001\")" "1000-29999"]}
    ${refused "two users of one room on one uid throw" (with' {
      lounge = withUsers {
        ada = as 1001;
        bob = as 1001;
      };
    }) "users" ["lounge/ada (1001)" "lounge/bob (1001)" "shared"]}
    ck "one uid in two rooms is two guests' business, and evaluates" false \
      ${verdict
      (with' {
        lounge = withUsers {ada = as 1001;};
        den = withUsers {bob = as 1001;};
      }).instances}

    # 7f. The case RSK-012 is: a uid is the declaration's, not the name order's.
    ck "a user's uid alone is the declared one" 1002 ${toString bobAlone.instances.lounge.users.bob.uid}
    ck "a user's uid is unchanged when a user whose name sorts earlier is added" 1002 \
      ${toString bobAfterAaron.instances.lounge.users.bob.uid}
    ck "  and the earlier user has its own" 1001 ${toString bobAfterAaron.instances.lounge.users.aaron.uid}

    # 8. A well-formed declaration throws nowhere and has nothing to say.
    ck "a well-formed declaration's instances evaluate" false ${verdict good.instances}
    ck "  with no reason to refuse its names" "" ${lib.escapeShellArg (reason good.reasons.names)}
    ck "  and none to refuse its users" "" ${lib.escapeShellArg (reason good.reasons.users)}
    ck "  and one record per room" "assistant lounge" ${lib.escapeShellArg (toString (builtins.attrNames good.instances))}
    ck "  whose record is exactly the design's" true ${lib.boolToString (good.instances.lounge
      == {
        name = "lounge";
        ns = "room-lounge";
        uplink = null;
        socket = "/run/capsule-room/lounge/ssh.sock";
        users = {
          ada = as 1001;
          bob = {
            uid = 1002;
            keys = [key key];
          };
        };
        inherit sizes;
      })}
    ck "  with a namespace of its own" room-assistant ${good.instances.assistant.ns}
    ck "  no uplink" true ${lib.boolToString (good.instances.assistant.uplink == null)}
    ck "  and a socket under the room's directory" /run/capsule-room/assistant/ssh.sock ${good.instances.assistant.socket}

    # 9. Sizes pass through: nothing is filled in for a room that gives none.
    ck "empty sizes stay empty (nothing defaults)" true \
      ${lib.boolToString ((with' {
        lounge = {
          users.ada = as 1001;
          sizes = {};
        };
      }).instances.lounge.sizes
      == {})}

    # 10. The two clauses are independent: fixing one does not hide the other.
    ${let
      d = with' {
        "x.y" = withUsers {
          root = as 1001;
          ada = as 70000;
        };
      };
    in ''
      ck "a bad name and a bad user both throw" true ${verdict d.instances}
      has "  the name is still reported" x.y ${lib.escapeShellArg (reason d.reasons.names)}
      has "  and so is the user" root ${lib.escapeShellArg (reason d.reasons.users)}
      has "  and so is the uid" "x.y/ada (70000)" ${lib.escapeShellArg (reason d.reasons.users)}
    ''}

    cat "$log"
    exit "$fail"
  ''
