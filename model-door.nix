# model-door.nix — whether a declared model door is one this host can use.
# SL-010 design sec-2; `DEC-069`, `DEC-071`.
#
# `net.modelDoor` is the one socket the model relay listens on
# (`{port; socket;}`), and each slot's `modelDoor` is `"on"` or `"off"`: the
# state that slot's relay starts in. Both ends of the declaration are spliced —
# the port into socat's address text, the socket into a path this host reads —
# so a declaration is refused rather than repaired.
#
# Its own file rather than a reason in `capsules.nix` (which decides slot
# records) or in `net` (which carries the value): these refusals cross the two
# axes — a slot field checked against a host declaration — so they belong to
# neither, and get `state-dir.nix`'s shape. `mkfleet.nix` reads `value` where it
# reads `stateDir`'s, so every caller's eval refuses, the consumer's included.
#
# Five refusals, each naming the field, the declared value and the decision:
#
#   1. a slot whose `modelDoor` is neither "on" nor "off" (DEC-069). The field
#      is the relay's state at start, and there are two.
#   2. a slot that declares `modelDoor` while `net.modelDoor` is absent
#      (DEC-071). An absent door is a declaration that no slot has one, so a
#      slot claiming a state would claim a relay no unit provides.
#   3. a port that is not an integer in 1024-65535, or that is `net.proxyPort`
#      or 22 (DEC-071). The upper bound is there because the port is spliced
#      into socat's address text; the lower bound because the relay runs with
#      an empty capability set and nothing lowers the namespace's
#      `ip_unprivileged_port_start`, so a lower one would pass eval and fail to
#      bind; `net.proxyPort` and sshd's 22 because the host already owns them.
#   4. a socket that is not a path this host can splice (DEC-071). The test —
#      absolute, over [allowed], every component a name — is `state-dir.nix`'s,
#      moved to host-path.nix so it is stated once (SL-010 design sec-2 D-4);
#      it is also the spelling socat reads as one address, since the set
#      excludes the `,` and `:` that separate its options and addresses.
#   5. a socket under a tree the relay's hardening hides (DEC-071):
#      `ProtectHome = "tmpfs"` masks /home, /root and /run/user, `PrivateTmp`
#      masks /tmp and /var/tmp. The slot's owner could open such a socket and
#      the relay could not see it, so the refusal names the setting that masks
#      it.
#
# `builtins.isInt` is asked before any comparison: a declared port that is a
# string compared with `<` is a type error, and a type error is not a `throw`,
# so `builtins.tryEval` would not catch it.
#
# Pure. `reasons` holds each refusal, `null` when there is none, and `value` is
# exactly what the first of them throws, in the order above — so a suite can
# assert *why* as well as *that* (model-door-cases.nix). Otherwise `value` is
# `net.modelDoor` as declared: `null` when absent.
{lib}: {
  modelDoor,
  slots,
  proxyPort,
}: let
  inherit (builtins) attrNames concatStringsSep elem isInt toJSON;

  hostPath = import ./host-path.nix {inherit lib;};
  inherit (hostPath) allowed;

  # The trees the relay's hardening hides and the setting that hides each, one
  # list so a tree and its setting cannot be spelled apart.
  maskedTrees = [
    {
      tree = "/home";
      setting = "ProtectHome";
    }
    {
      tree = "/root";
      setting = "ProtectHome";
    }
    {
      tree = "/run/user";
      setting = "ProtectHome";
    }
    {
      tree = "/tmp";
      setting = "PrivateTmp";
    }
    {
      tree = "/var/tmp";
      setting = "PrivateTmp";
    }
  ];
  under = tree: path: path == tree || lib.hasPrefix "${tree}/" path;
  maskOf = path: lib.findFirst (m: under m.tree path) null maskedTrees;

  absent = modelDoor == null;
  port =
    if absent
    then null
    else modelDoor.port or null;
  socket =
    if absent
    then null
    else modelDoor.socket or null;
  why =
    if absent
    then null
    else hostPath.why socket;
  mask =
    if absent
    then null
    else maskOf socket;

  # A slot's `? modelDoor` rather than its value: a field declared null is a
  # declaration too, and refusal 1 is what refuses it, not silence.
  slotNames = attrNames slots;
  doorSlots = lib.filter (n: slots.${n} ? modelDoor) slotNames;
  badSlots = lib.filter (n: !(elem slots.${n}.modelDoor ["on" "off"])) doorSlots;

  reasons = {
    slotValue =
      if badSlots == []
      then null
      else "model-door.nix: a slot's modelDoor is either on or off (DEC-069, SL-010 design sec-2); not: ${concatStringsSep ", " (map (n: "slots.${n}.modelDoor = ${toJSON slots.${n}.modelDoor}") badSlots)}";
    undeclared =
      if absent && doorSlots != []
      then "model-door.nix: net.modelDoor is absent, so no slot may declare modelDoor (DEC-071, SL-010 design sec-2); declared by: ${concatStringsSep ", " (map (n: "${n} (${toJSON slots.${n}.modelDoor})") doorSlots)}"
      else null;
    port =
      if !absent && !(isInt port && port >= 1024 && port <= 65535 && port != proxyPort && port != 22)
      then "model-door.nix: net.modelDoor.port ${toJSON port} must be an integer in 1024-65535 other than net.proxyPort (${toJSON proxyPort}) and 22 (DEC-071, SL-010 design sec-2)"
      else null;
    socket =
      if why != null
      then "model-door.nix: net.modelDoor.socket ${toJSON socket} ${why} — it must be an absolute path over [${allowed}] whose every component is a name, not empty, '.' or '..' (DEC-071, SL-010 design sec-2)"
      else null;
    masked =
      if mask == null
      then null
      else "model-door.nix: net.modelDoor.socket ${toJSON socket} is under ${mask.tree}, which the relay's ${mask.setting} hides from its unit: the slot's owner could open that socket and the relay could not see it (DEC-071, SL-010 design sec-2)";
  };

  # The order is sec-2's, so a declaration breaking two rules throws the first.
  first = lib.findFirst (r: r != null) null [reasons.slotValue reasons.undeclared reasons.port reasons.socket reasons.masked];
in {
  inherit reasons;
  value =
    if first != null
    then throw first
    else modelDoor;
}
