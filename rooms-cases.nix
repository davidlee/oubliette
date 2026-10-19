# What a room declaration decides — SL-005 design sec-2, DEC-038; SL-006 design
# sec-2, DEC-048 (a room's repos, policy and work volume) and DEC-046 (its
# policy is one the fleet declares); SL-007 design sec-2, DEC-052 (a room's
# extras are names from the fragment vocabulary); IMP-023 (a room's repos may
# name readers, other declared users who may read the clones).
#
# The subject is a *library*, not a program: `rooms.nix` is the function its one
# caller (mkfleet.nix) applies, and this suite applies the same function to
# fixtures that are no host's — slots `s1` and `s2` that nobody runs, and rooms
# nobody declares. Every verdict is a value of the function.
#
# **Handed a fixture, and it says so**: `slotNames`, the keys and the sizes below
# are invented, and so are the `targets` (built by the real derivation,
# targets/default.nix, so a record's `guestPath` is checked against it and not
# against a second spelling), the `policies` and the `fragmentNames`. The awkward target names
# (`foo+bar`, `.`, `..`) are *declared*, so a grammar case is refused for its
# grammar and for no other reason.
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
# namespace or image exists for a room, that the front end can name one, that
# any guest holds `/work` or a clone (SL-006 PHASE-03), or that any program
# reads a room's `policy` (PHASE-04, PHASE-05). It
# is the function's verdicts over fixtures, and nothing more.
{
  pkgs,
  lib,
  # `import ./rooms.nix`, unapplied: the function mkfleet.nix calls.
  rooms,
  # `import ./targets`, unapplied: the constructor mkfleet.nix derives targets with.
  targetsOf,
}: let
  apply = rooms {inherit lib;};
  slotNames = ["s1" "s2"];
  targets = targetsOf (lib.genAttrs ["a" "b" "foo+bar" "." ".."] (_: {caches = {};}));
  policies = {everything = ["open" "shut"];};
  # A fragment vocabulary nobody's: the names are invented, not fragments.nix'.
  fragmentNames = ["search" "editor"];
  withVocabulary = names: decls:
    apply {
      rooms = decls;
      fragmentNames = names;
      inherit slotNames targets policies;
    };
  with' = withVocabulary fragmentNames;

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
  # A room with repos, a policy and a work volume, fine in every way; `extra`
  # overrides, and the partial cases take fields away with `removeAttrs`.
  withRepos = extra:
    {
      users.agent = as 1001;
      sizes = sizes // {work = 512;};
      repos = {
        user = "agent";
        targets = ["a" "b"];
      };
      policy = "open";
    }
    // extra;
  withReposIn = repos: withRepos {inherit repos;};
  withTargets = ts:
    withReposIn {
      user = "agent";
      targets = ts;
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
  refusedUnder = decision: title: decl: field: needles: ''
    ck ${lib.escapeShellArg title} true ${verdict decl.instances}
    ${lib.concatMapStrings (n: ''
        has ${lib.escapeShellArg "  naming ${n}"} ${lib.escapeShellArg n} ${lib.escapeShellArg (reason decl.reasons.${field})}
      '')
      (needles ++ [decision])}
  '';
  refused = refusedUnder "DEC-038";
  # One room, `assistant`, refused by DEC-048 or DEC-046.
  repoRefused = title: room: needles: refusedUnder "DEC-048" title (with' {assistant = room;}) "repos" needles;
  repoOf = with' {assistant = withRepos {};};
  # One room, `assistant`, refused by DEC-052.
  extrasRefused = title: room: needles: refusedUnder "DEC-052" title (with' {assistant = room;}) "extras" needles;
  withExtras = extras: (withUsers {agent = as 1001;}) // {inherit extras;};
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
        repos = null;
        policy = null;
        extras = [];
      })}
    ck "  with a namespace of its own" room-assistant ${good.instances.assistant.ns}
    ck "  no uplink" true ${lib.boolToString (good.instances.assistant.uplink == null)}
    ck "  and a socket under the room's directory" /run/capsule-room/assistant/ssh.sock ${good.instances.assistant.socket}
    ck "  whose door root is the parent of every room's directory" /run/capsule-room ${good.doorRootOf good.instances.assistant.socket}

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

    # 11. A room's repos: the record resolves each to the target derivation's
    # path, in the declaration's order, and says nothing it was not told.
    ck "a well-formed repo room evaluates" false ${verdict repoOf.instances}
    ck "  with no reason to refuse its repos" "" ${lib.escapeShellArg (reason repoOf.reasons.repos)}
    ck "  and none to refuse its policy" "" ${lib.escapeShellArg (reason repoOf.reasons.policy)}
    ck "  its record's repos are the user and each target's derived path" true \
      ${lib.boolToString (repoOf.instances.assistant.repos
      == {
        user = "agent";
        readers = [];
        targets = [
          {
            name = "a";
            inherit (targets.byName.a) guestPath;
          }
          {
            name = "b";
            inherit (targets.byName.b) guestPath;
          }
        ];
      })}
    ck "  and the path is the derivation's, /work/a" /work/a \
      ${(builtins.head repoOf.instances.assistant.repos.targets).guestPath}
    ck "  its policy is the declared one" open ${repoOf.instances.assistant.policy}
    ck "  and sizes.work passes through" 512 ${toString repoOf.instances.assistant.sizes.work}
    ck "  and the declaration's order is kept" "b a" \
      ${lib.escapeShellArg (toString (map (t: t.name) (with' {assistant = withTargets ["b" "a"];}).instances.assistant.repos.targets))}
    ck "a room declaring none is repo-less and policy-less" true \
      ${lib.boolToString (good.instances.assistant.repos == null && good.instances.assistant.policy == null)}

    # 12. All or none: a room names every one of repos, policy and sizes.work.
    ${repoRefused "repos without a policy throws" (removeAttrs (withRepos {}) ["policy"]) ["assistant (no policy)" "partial"]}
    ${repoRefused "repos and policy without sizes.work throws" (withRepos {inherit sizes;}) ["assistant (no sizes.work)" "partial"]}
    ${repoRefused "a policy alone throws" {
      users.agent = as 1001;
      inherit sizes;
      policy = "open";
    } ["assistant (no repos, sizes.work)"]}
    ${repoRefused "sizes.work alone throws" {
      users.agent = as 1001;
      sizes = sizes // {work = 512;};
    } ["assistant (no policy, repos)"]}

    # 13. repos is { user; targets = [ <target name> ]; } and a malformed one is
    # its one reason, never a missing-attribute abort.
    ${repoRefused "repos as a bare list throws" (withReposIn ["a"]) ["assistant" "{ user; targets"]}
    ${repoRefused "repos with no user throws" (withReposIn {targets = ["a"];}) ["assistant" "{ user; targets"]}
    ${repoRefused "repos with a field beyond user and targets throws" (withReposIn {
      user = "agent";
      targets = ["a"];
      extra = 1;
    }) ["assistant" "{ user; targets"]}
    ${repoRefused "targets as a bare string throws" (withReposIn {
      user = "agent";
      targets = "a";
    }) ["assistant" "{ user; targets"]}
    ${repoRefused "a target that is not a string is a reason, not an abort" (withTargets [1]) ["assistant" "{ user; targets"]}

    # 14. Each repo is a declared target, named once, with a name a path can bear.
    ${repoRefused "no targets throws" (withTargets []) ["assistant" "no targets"]}
    ${repoRefused "a target nobody declares throws" (withTargets ["a" "zz"]) ["assistant/zz" "not a declared target"]}
    ${repoRefused "a target named twice throws" (withTargets ["a" "a"]) ["assistant/a" "named twice"]}
    ${repoRefused "a declared target with a + throws" (withTargets ["foo+bar"]) ["assistant/foo+bar" "[A-Za-z0-9._-]"]}
    ${repoRefused "a declared target named . throws" (withTargets ["."]) ["assistant/." "[A-Za-z0-9._-]"]}
    ${repoRefused "a declared target named .. throws" (withTargets [".."]) ["assistant/.." "[A-Za-z0-9._-]"]}
    ${repoRefused "a repo user the room does not declare throws" (withReposIn {
      user = "carol";
      targets = ["a"];
    }) ["assistant/carol" "user not a declared user"]}

    # 15. A policy is one the fleet declares (DEC-046).
    ${refusedUnder "DEC-046" "a policy nobody declares throws" (with' {assistant = withRepos {policy = "nope";};}) "policy" ["assistant (\"nope\")" "policies.everything"]}

    # 16. The fields are independent, and so are they of the users'.
    ${let
      d = with' {
        assistant = withRepos {
          policy = "nope";
          repos = {
            user = "agent";
            targets = ["zz"];
          };
        };
      };
    in ''
      ck "a bad target and a bad policy both throw" true ${verdict d.instances}
      has "  the target is still reported" assistant/zz ${lib.escapeShellArg (reason d.reasons.repos)}
      has "  and so is the policy" nope ${lib.escapeShellArg (reason d.reasons.policy)}
    ''}
    ${let
      d = with' {
        assistant = withRepos {
          users.agent = as 70000;
          repos = {
            user = "carol";
            targets = ["a"];
          };
        };
      };
    in ''
      ck "a bad uid and a bad repos user both throw" true ${verdict d.instances}
      has "  the uid is still reported" "assistant/agent (70000)" ${lib.escapeShellArg (reason d.reasons.users)}
      has "  and so is the repos user" assistant/carol ${lib.escapeShellArg (reason d.reasons.repos)}
    ''}

    # 17. The absent path: repo rooms and repo-less rooms in one declaration.
    ${let
      d = with' {
        assistant = withRepos {};
        lounge = withUsers {ada = as 1001;};
      };
    in ''
      ck "a repo room beside a repo-less room evaluates" false ${verdict d.instances}
      ck "  the repo-less record has no repos" true ${lib.boolToString (d.instances.lounge.repos == null)}
      ck "  and no policy" true ${lib.boolToString (d.instances.lounge.policy == null)}
    ''}

    # 18. extras is a list of strings, and a malformed one is its one reason,
    # never a type-error abort (tryEval would not catch one).
    ${extrasRefused "extras as a bare string throws" (withExtras "search") ["assistant" "not a list of fragment names"]}
    ${extrasRefused "an extra that is not a string is a reason, not an abort" (withExtras [1]) ["assistant" "not a list of fragment names"]}

    # 19. A name outside the vocabulary: the offender is named, and so is the
    # vocabulary. The valid name beside it is not an offender; the bare name is
    # in the vocabulary list, so the offender form is what is read.
    ${let
      d = with' {assistant = withExtras ["search" "nope"];};
      r = lib.escapeShellArg (reason d.reasons.extras);
    in ''
      ${extrasRefused "a name outside the vocabulary throws" (withExtras ["search" "nope"]) ["assistant (\"nope\")" "search" "editor" "not in the vocabulary"]}
      case ${r} in
        *'assistant ("search")'*) echo "FAIL the valid name is not an offender" >&2; fail=1 ;;
        *) echo "ok     the valid name is not an offender" >>"$log" ;;
      esac
    ''}

    # 20. Absent: no extras is the empty list, and nothing to say.
    ck "a room declaring no extras has []" true \
      ${lib.boolToString (good.instances.assistant.extras == [] && repoOf.instances.assistant.extras == [])}
    ck "  and no reason to refuse its extras" "" ${lib.escapeShellArg (reason good.reasons.extras + reason repoOf.reasons.extras)}

    # 21. Declared: carried through in the declared order, on either kind of room.
    ${let
      d = with' {
        assistant = withRepos {extras = ["editor" "search"];};
        lounge = withExtras ["editor" "search"];
      };
    in ''
      ck "rooms declaring extras from the vocabulary evaluate" false ${verdict d.instances}
      ck "  with no reason to refuse them" "" ${lib.escapeShellArg (reason d.reasons.extras)}
      ck "  a repo room's record carries them in order" "editor search" ${lib.escapeShellArg (toString d.instances.assistant.extras)}
      ck "  and so does a repo-less room's" "editor search" ${lib.escapeShellArg (toString d.instances.lounge.extras)}
    ''}

    # 22. As with policy, nothing forces the vocabulary for a room with no extras.
    ck "rooms without extras never force fragmentNames" false \
      ${verdict (withVocabulary (throw "fragmentNames forced") {assistant = withRepos {};}).instances}
    ck "  of either kind" false \
      ${verdict (withVocabulary (throw "fragmentNames forced") {assistant = withUsers {agent = as 1001;};}).instances}

    # 23. Independent of policy: both are reported.
    ${let
      d = with' {
        assistant = withRepos {
          policy = "nope";
          extras = ["gone"];
        };
      };
    in ''
      ck "a bad policy and an unknown extra both throw" true ${verdict d.instances}
      has "  the policy is still reported" nope ${lib.escapeShellArg (reason d.reasons.policy)}
      has "  and so is the extra" 'assistant ("gone")' ${lib.escapeShellArg (reason d.reasons.extras)}
    ''}

    # 24. Readers (IMP-023): absent is [], declared ones are carried in order,
    # and each is a declared user of the room other than the repos' own.
    ${let
      d = with' {
        assistant = withRepos {
          users = {
            agent = as 1001;
            satan = as 1002;
            ada = as 1003;
          };
          repos = {
            user = "agent";
            targets = ["a"];
            readers = ["satan" "ada"];
          };
        };
      };
    in ''
      ck "a room with readers evaluates" false ${verdict d.instances}
      ck "  with no reason to refuse its repos" "" ${lib.escapeShellArg (reason d.reasons.repos)}
      ck "  and its record carries them in order" "satan ada" ${lib.escapeShellArg (toString d.instances.assistant.repos.readers)}
    ''}
    ${repoRefused "readers as a bare string throws" (withReposIn {
      user = "agent";
      targets = ["a"];
      readers = "agent";
    }) ["assistant" "readers"]}
    ${repoRefused "a reader the room does not declare throws" (withReposIn {
      user = "agent";
      targets = ["a"];
      readers = ["carol"];
    }) ["assistant/carol" "reader not a declared user"]}
    ${repoRefused "the repos' own user as a reader throws" (withReposIn {
      user = "agent";
      targets = ["a"];
      readers = ["agent"];
    }) ["assistant/agent" "reader is the repos' user"]}

    cat "$log"
    exit "$fail"
  ''
