# rooms.nix — from a room declaration to its guest records. SL-005 design sec-2,
# DEC-038; SL-006 design sec-2, DEC-048 and DEC-046.
#
# Pure: no host values. mkfleet.nix applies it once, to the declared `rooms`, the
# slot names, the *derived* `targets` (targets/default.nix: only
# `.byName.<n>.guestPath` is read) and the `policies` vocabulary (only
# `.everything` is read), and is the one binding site; every other applier —
# rooms-cases.nix and the four suites that build a room — passes declared
# fixtures (POL-003). A room is a guest that is not a slot: its record mirrors a slot's
# (`name`, `ns`, `socket`, `uplink`) so the programs that take a guest take
# either, but it has no uplink, and nothing here learns what a room is for
# (POL-002) — users and sizes are values, passed through.
#
# A user is `{ uid; keys; }`, and the uid is declared rather than allocated
# (RSK-012): a room's root fs is tmpfs, so NixOS would allocate undeclared uids
# afresh on every boot, in name order, while `/home` is a volume that keeps the
# numbers its files were written under. A derived uid would make its formula
# part of that volume's format, so nothing here picks one (POL-003).
#
# A room may also declare `repos = { user; targets = [<target name>]; }`, a
# `policy` and `sizes.work`, all or none (DEC-048). A repo is a *target's name*,
# resolved here against `targets`, so its tools come from that target and its
# path from the derivation (`guestPath`), which is read and never re-spelt
# (POL-003). `policy` names one of `policies.everything` (DEC-046). A room
# without them is as it was, and its reasons and record never force `targets`
# or `policies`: the absent path costs nothing and needs nothing (POL-002).
#
# Rooms and slots share one unit-name space (`capsule-netns-<n>`, `microvm@<n>`)
# and one `nixosConfigurations` space, which is why a room may not take a slot's
# name, or either image's name.
#
# Each refusal's message is a value in `reasons` (`null` when there is none) and
# is exactly what `instances` throws, so a suite can assert *why* as well as
# *that* — a `tryEval` verdict carries no message.
{lib}: {
  rooms,
  slotNames,
  targets,
  policies,
}: let
  inherit (builtins) attrNames concatStringsSep isAttrs isInt isList isNull isString mapAttrs match stringLength toJSON;

  # mkfleet.nix's `vms` keys that are not slots (`hello`, and `capsule` the
  # probe target's image). Oubliette's own names, not a target's.
  reservedNames = ["hello" "capsule"];

  # A systemd instance name needing no escaping, a directory, a nix attr.
  unitSafe = n: match "[a-z0-9][a-z0-9_-]*" n != null;
  # A subset of NixOS's `users.users` names, and its 31-character limit.
  userSafe = u: match "[a-z_][a-z0-9_-]*" u != null && stringLength u < 32;
  # NixOS's normal-user range: it asserts at least 1000 for one, and allocates
  # its own system accounts from 30000 up (`nixbld*` among them, in a room).
  uidSafe = uid: isInt uid && uid >= 1000 && uid <= 29999;

  # A repo's name is a path component and a ref name on the host, checked at run
  # time by `refuseToken` (host/quarantine.nix): empty, `.`, `..` and anything
  # outside [A-Za-z0-9._-] are refused there, so refuse exactly that set here.
  # A declared target can still be unusable as a repo — host/profile-name.nix
  # admits `foo+bar` — which is why this is its own check (RV-015 F-6).
  repoSafe = t: match "[A-Za-z0-9._-]+" t != null && t != "." && t != "..";

  # One clause of a reason: empty when nobody offends, else "<what>: <who>".
  clause = what: offenders:
    lib.optional (offenders != []) "${what}: ${concatStringsSep ", " offenders}";
  # Null when no clause offends, else the whole message. It cites the decision
  # that made the rule, so each field of `reasons` is traceable to its own.
  refusal = decision: rule: clauses:
    if clauses == []
    then null
    else "rooms.nix: ${rule} (${decision}); ${concatStringsSep "; " clauses}";

  roomNames = attrNames rooms;
  userPairs =
    lib.concatMap
    (r: lib.mapAttrsToList (u: v: {inherit r u v;}) rooms.${r}.users)
    roomNames;
  userNamed = p: "${p.r}/${p.u}";
  uidNamed = p: "${userNamed p} (${toJSON p.v.uid})";

  # Each predicate below assumes the ones before it, so a malformed user is
  # its one reason and never a missing-attribute abort.
  shaped = p: isAttrs p.v && removeAttrs p.v ["uid" "keys"] == {};
  hasUid = p: shaped p && p.v ? uid;
  # A uid another user of the same room also holds; each room is its own guest.
  shared = p:
    lib.any (o: o.r == p.r && o.u != p.u && hasUid o && o.v.uid == p.v.uid) userPairs;

  # Repos, policy and work volume come together or not at all (DEC-048).
  present = d: {
    repos = d ? repos;
    policy = d ? policy;
    "sizes.work" = (d.sizes or {}) ? work;
  };
  absent = r: attrNames (lib.filterAttrs (_: here: !here) (present rooms.${r}));
  partial = r: let a = absent r; in a != [] && lib.length a < 3;
  partialNamed = r: "${r} (no ${concatStringsSep ", " (absent r)})";

  # As for users: every predicate over a room's repos assumes it is shaped.
  reposShaped = r: let
    d = rooms.${r};
  in
    d
    ? repos
    && isAttrs d.repos
    && d.repos ? user
    && d.repos ? targets
    && removeAttrs d.repos ["user" "targets"] == {}
    && isString d.repos.user
    && isList d.repos.targets
    && lib.all isString d.repos.targets;
  repoRooms = lib.filter reposShaped roomNames;
  repoPairs =
    lib.concatMap
    (r: map (t: {inherit r t;}) rooms.${r}.repos.targets)
    repoRooms;
  repoNamed = p: "${p.r}/${p.t}";

  reasons = {
    names =
      refusal "DEC-038" "a room's name is its unit name, so it must be unique and unit-safe"
      (
        clause "slot name" (lib.filter (n: builtins.elem n slotNames) roomNames)
        ++ clause "reserved image name" (lib.filter (n: builtins.elem n reservedNames) roomNames)
        ++ clause "not unit-safe ([a-z0-9][a-z0-9_-]*)" (lib.filter (n: !unitSafe n) roomNames)
      );
    users =
      refusal "DEC-038" "a room's user is a non-root login with keys and a uid of its own"
      (
        clause "root" (map userNamed (lib.filter (p: p.u == "root") userPairs))
        ++ clause "not { uid; keys; }" (map userNamed (lib.filter (p: !shaped p) userPairs))
        ++ clause "no uid" (map userNamed (lib.filter (p: shaped p && !hasUid p) userPairs))
        ++ clause "no keys" (map userNamed (lib.filter (p: shaped p && (p.v.keys or []) == []) userPairs))
        ++ clause "uid not a number in 1000-29999" (map uidNamed (lib.filter (p: hasUid p && !uidSafe p.v.uid) userPairs))
        ++ clause "uid shared within a room" (map uidNamed (lib.filter (p: hasUid p && shared p) userPairs))
        ++ clause "not user-safe ([a-z_][a-z0-9_-]*, under 32 characters)" (map userNamed (lib.filter (p: !userSafe p.u) userPairs))
      );
    repos =
      refusal "DEC-048" "a room's repos, policy and work volume come together, and each repo is a declared target"
      (
        clause "partial, so declare all of repos, policy and sizes.work" (map partialNamed (lib.filter partial roomNames))
        ++ clause "repos not { user; targets = [ <target name> ]; }" (lib.filter (r: rooms.${r} ? repos && !reposShaped r) roomNames)
        ++ clause "no targets" (lib.filter (r: rooms.${r}.repos.targets == []) repoRooms)
        ++ clause "not a declared target" (map repoNamed (lib.filter (p: !(targets.byName ? ${p.t})) repoPairs))
        ++ clause "named twice" (lib.unique (map repoNamed (lib.filter (p: lib.count (o: o == p) repoPairs > 1) repoPairs)))
        ++ clause "not repo-safe ([A-Za-z0-9._-]+, and not . or ..)" (map repoNamed (lib.filter (p: !repoSafe p.t) repoPairs))
        ++ clause "user not a declared user of the room" (map (r: "${r}/${rooms.${r}.repos.user}") (lib.filter (r: !(rooms.${r}.users ? ${rooms.${r}.repos.user})) repoRooms))
      );
    policy =
      refusal "DEC-046" "a room's policy is one the fleet declares"
      (
        clause "not in policies.everything" (map (r: "${r} (${toJSON rooms.${r}.policy})") (lib.filter (r: rooms.${r} ? policy && !(builtins.elem rooms.${r}.policy policies.everything)) roomNames))
      );
  };

  recordOf = name: decl: {
    inherit name;
    ns = "room-${name}";
    uplink = null;
    socket = "/run/capsule-room/${name}/ssh.sock";
    inherit (decl) users sizes;
    # Each repo's path is the target derivation's, read and never re-spelt.
    repos =
      if decl ? repos
      then {
        inherit (decl.repos) user;
        targets =
          map (t: {
            name = t;
            inherit (targets.byName.${t}) guestPath;
          })
          decl.repos.targets;
      }
      else null;
    policy = decl.policy or null;
  };
in {
  inherit reasons;
  instances =
    if !(isNull reasons.names)
    then throw reasons.names
    else if !(isNull reasons.users)
    then throw reasons.users
    else if !(isNull reasons.repos)
    then throw reasons.repos
    else if !(isNull reasons.policy)
    then throw reasons.policy
    else mapAttrs recordOf rooms;
}
