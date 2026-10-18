# rooms.nix — from a room declaration to its guest records. SL-005 design sec-2,
# DEC-038.
#
# Pure: no host values. mkfleet.nix applies it once, to the declared `rooms` and
# the slot names, and is the one binding site; rooms-cases.nix applies it to
# fixtures. A room is a guest that is not a slot: its record mirrors a slot's
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
}: let
  inherit (builtins) attrNames concatStringsSep isAttrs isInt isNull mapAttrs match stringLength toJSON;

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

  # One clause of a reason: empty when nobody offends, else "<what>: <who>".
  clause = what: offenders:
    lib.optional (offenders != []) "${what}: ${concatStringsSep ", " offenders}";
  # Null when no clause offends, else the whole message.
  refusal = rule: clauses:
    if clauses == []
    then null
    else "rooms.nix: ${rule} (DEC-038); ${concatStringsSep "; " clauses}";

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

  reasons = {
    names =
      refusal "a room's name is its unit name, so it must be unique and unit-safe"
      (
        clause "slot name" (lib.filter (n: builtins.elem n slotNames) roomNames)
        ++ clause "reserved image name" (lib.filter (n: builtins.elem n reservedNames) roomNames)
        ++ clause "not unit-safe ([a-z0-9][a-z0-9_-]*)" (lib.filter (n: !unitSafe n) roomNames)
      );
    users =
      refusal "a room's user is a non-root login with keys and a uid of its own"
      (
        clause "root" (map userNamed (lib.filter (p: p.u == "root") userPairs))
        ++ clause "not { uid; keys; }" (map userNamed (lib.filter (p: !shaped p) userPairs))
        ++ clause "no uid" (map userNamed (lib.filter (p: shaped p && !hasUid p) userPairs))
        ++ clause "no keys" (map userNamed (lib.filter (p: shaped p && (p.v.keys or []) == []) userPairs))
        ++ clause "uid not a number in 1000-29999" (map uidNamed (lib.filter (p: hasUid p && !uidSafe p.v.uid) userPairs))
        ++ clause "uid shared within a room" (map uidNamed (lib.filter (p: hasUid p && shared p) userPairs))
        ++ clause "not user-safe ([a-z_][a-z0-9_-]*, under 32 characters)" (map userNamed (lib.filter (p: !userSafe p.u) userPairs))
      );
  };

  recordOf = name: decl: {
    inherit name;
    ns = "room-${name}";
    uplink = null;
    socket = "/run/capsule-room/${name}/ssh.sock";
    inherit (decl) users sizes;
  };
in {
  inherit reasons;
  instances =
    if !(isNull reasons.names)
    then throw reasons.names
    else if !(isNull reasons.users)
    then throw reasons.users
    else mapAttrs recordOf rooms;
}
