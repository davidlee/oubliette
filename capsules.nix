# The capsules a host runs, from its declaration. Oubliette's *function*: the
# slots, the uplink network, the aggregator's two addresses and the volume
# reserve are the caller's (its `fleet` argument to `lib.mkFleet`, a consumer's `capsules.nix`; DEC-026); the interface and
# namespace names, the /30s, the socket and lock paths and the refusals below
# are oubliette's, and no host spells them. Like the `net` declaration and `targets/`, nothing
# here reads the system or does work: it says which capsules exist and what each
# is called on the wire. What a capsule is made of is the units' business
# (docs/plan-c-implementation.md).
#
# What is deliberately NOT here is the host<->guest link. Under netns every
# capsule gets the same tap name, the same /30 and the same MAC, because each
# lives in its own namespace — that is the whole point of the shape, and it is
# what lets one target's image serve every slot bound to it (NOTES item 17). Those stay flat
# in the caller's `net`. The only addressing that cannot be identical is each namespace's
# uplink to the aggregator, since the aggregator has a single routing table.
# The names in this map are constants; the addresses are the caller's
# declaration's (`uplinkNet`, `egressAddr`, `egressPeerAddr`), shown as declared:
#
#   root ns          eg-rt      10.101.0.1/30   forwards, masquerades, and is
#                                               where the resolver stub must
#                                               also listen (~/flakes)
#   cap-egress ns    eg-up      10.101.0.2/30   the aggregator: every capsule's
#                    cap-<name> 10.100.<i>.1/30 proxy leaves through here, and
#                                               the drops between them live here
#   cap-<name> ns    up-<name>  10.100.<i>.2/30 the capsule's way out
#                    vm-capsule 10.99.0.1/30    the caller's `net`, identical in every one
#
# That map is `probe/netns-egress.sh`'s, which is where it was verified
# (docs/probes.md) — the probe builds its own links because it must run without
# the units, so the names differ there and the shape does not.
#
# `policies` is its own axis, applied first: the `undeclared` refusal reads the
# vocabulary, and this file reads no declaration file of its own.
{policies}:
# The declaration: a host's slots, its addressing and its volume reserve.
{
  slots,
  addressing,
  volumeReserve,
}:
# The `let` sits on its own line: the header above is the file's signature.
let
  profileNameOk = import ./host/profile-name.nix;

  # The slots. Names, not a count — and the index is *declared*, not taken from
  # list position: deriving it from position means deleting a name renumbers its
  # neighbours, and an existing volume, socket and uplink /30 all silently change
  # hands.
  #
  # A slot's name is abstract and carries no meaning (docs/plan-d-fleet.md §0),
  # which is the decision the rest of this file's shape now rests on: `a` is not
  # doctrine's and `b` is not the spare, so nothing may infer what a slot holds
  # from what it is called. What a slot is assigned to is a record, and it does
  # not exist yet (docs/contract-assignment.md) — until it does, the honest
  # statement is that these names say nothing at all.
  #
  # A declaration is not a reservation. Nothing the module generates is
  # `wantedBy` anything, so no namespace, tap, volume or VMM exists until some
  # capsule starts — an idle slot is a name, an index, three unit files and nine
  # loaded unit instances, six of which are microvm.nix's own templates. Both
  # halves are measured: 3% of a module eval, and one page of PID 1 for the
  # seventy-two units the eight new slots added
  # (docs/probes.md#what-ten-declared-slots-cost).
  # `policy` is the host operator's declared choice for a slot nobody has
  # assigned, and `policies` is the set an assigner may select within — two
  # fields because they are two statements, and the second is what makes
  # `capsule <slot> policy <name>` safe to delegate (NOTES item 36, item 25).
  #
  # A declared default is not item 28 softening. A slot's *name* has no default
  # because a name that means nothing cannot be guessed on a human's behalf. A
  # slot's *policy* has one because **absence is not a state a perimeter may be
  # in**: a slot whose record names none must still run something, and the
  # operator's declaration is the only candidate that is not the assigner's.
  #
  # `profile` is which target the slot serves when nobody has said otherwise.
  # For *resolution* it is the operator's **convenience**, not a control. There is
  # no `profiles` set beside it, because an assigner is unconstrained in `profile`
  # by design (docs/contract-assignment.md, *Who may assign*). Only the name's *shape* is
  # checked here (`misprofiled`, below); whether a document backs it is run-time
  # state outside the store, so `profileLoad` (host/profile.nix) checks that, at
  # use (SL-001 design sec-2).
  #
  # **For a declared slot, `profile` is also the build binding** (SL-003,
  # `DEC-017`): the slot boots the image of the target it names (fleet.nix), and
  # a declared slot naming no target in `targets/`, or none at all, throws at
  # eval there. This file does not import `targets/` to check it (`DEC-012` alt
  # B). So the convenience above is still true of *resolution*: an assigner may
  # name another target. But a verb under an assignment whose target is not the
  # image this slot booted is refused at use (host/cli.nix, `bootedTarget`),
  # because this slot cannot serve it. Moving a slot to another target is a
  # change in the declaration, then `just refresh-build <slot>` and a restart.
  declared = slots;

  # Carved into a /30 per capsule by index, so the aggregator's route and NAT
  # cover every capsule without enumerating them. A slot's index is the third
  # octet, so the declared network must be a /16 written `a.b.0.0/16`; the
  # first two octets are every uplink's (`uplinkPrefix`), refused below if not.
  inherit (addressing) uplinkNet;
  uplinkMatch = builtins.match "([0-9]+\\.[0-9]+)\\.0\\.0/16" uplinkNet;
  uplinkPrefix = builtins.head uplinkMatch;

  # A capsule's link *in the aggregator*, and the wildcard the interface-pair
  # drop matches. One prefix, so the rule cannot drift from the names it drops.
  capLink = "cap-";

  # Where a capsule's way in lives. Its identity is its namespace and this
  # socket, never the VMM's name — every image is hostName `capsule`, so every VMM is
  # `microvm@capsule` whichever target it runs (fleet.nix, DEC-032). Exposed as a function because a probe's throwaway capsule is not
  # an instance and must not invent a second convention for the same path.
  socketOf = name: "/run/capsule/${name}/ssh.sock";

  # One volume operation at a time on this host (SL-002 design sec-2). The root
  # helper holds it exclusively for its whole run and `capsule <slot> start`
  # takes it shared, so a start cannot land between the helper's `fuser` and its
  # act. Host-wide rather than per slot: a clone takes seconds, and per-slot
  # locks would buy that back with ordering rules. Beside `socketOf` because both
  # live under `/run/capsule`.
  volumeLock = "/run/capsule/volume.lock";

  # Bytes a clone must leave free for non-root writers. The running VMMs are
  # `microvm`, and they grow their sparse images into `df`'s `avail`, so a clone
  # that spent it to zero would stop every running guest's writes. It bounds the
  # clone only; growth of images already here is `RSK-007`. The figure is the
  # declaration's (`volumeReserve`, an argument above).

  # `policy` and `policies` are optional *here* and required of a real slot by the
  # assertion below, so the one caller that constructs instances which are not
  # slots — `guardCases`'s fixture, which is about namespaces and knows nothing
  # about controls — stays two lines. `profile` is optional everywhere: a slot
  # that declares none falls through to the next step of the front end's
  # resolution.
  recordOf = name: {
    index,
    policy ? null,
    policies ? [],
    profile ? null,
  }: {
    inherit name index policy policies profile;
    ns = "${capLink}${name}";
    socket = socketOf name;
    uplink = {
      dev = "up-${name}"; # inside the capsule's namespace
      addr = "${uplinkPrefix}.${toString index}.2";
      peer = "${capLink}${name}"; # inside the aggregator
      gw = "${uplinkPrefix}.${toString index}.1";
      prefix = 30;
    };
  };

  instancesOf = builtins.mapAttrs recordOf;

  names = builtins.attrNames declared;

  # IFNAMSIZ is 15 and the longest prefix above spends 4 of it. `egress` is
  # rejected for a different reason: the aggregator's namespace shares that
  # prefix, so a capsule of that name would collide with it.
  rejected =
    builtins.filter (n: builtins.stringLength n > 11 || n == "egress") names;

  # A slot naming a policy the vocabulary does not declare, or one outside its
  # own declared set, is a perimeter nobody can resolve — the first dangles the
  # symlink the proxy reads, and the second says two different things about who
  # may choose. Both are eval-time refusals: a declaration that cannot be
  # satisfied should never reach a host.
  undeclared =
    builtins.filter
    (n: let
      d = declared.${n};
    in
      !(builtins.elem (d.policy or null) policies.everything)
      || !(builtins.elem d.policy (d.policies or [])))
    names;

  # A declared profile whose name is not one — empty, `.`, `..`, the reserved
  # `-`, or holding a character the front end's rendered text cannot carry
  # (host/profile-name.nix). A function of the declared set so a case can apply
  # the very function the assertion uses to a set no host declares.
  misprofiledIn = declared:
    builtins.filter
    (n: let
      p = declared.${n}.profile or null;
    in
      p != null && !(profileNameOk p))
    (builtins.attrNames declared);
  misprofiled = misprofiledIn declared;

  # An index is what carves a capsule's /30 out of `uplinkNet`, so two capsules
  # sharing one is two capsules on one wire — silently, and only once both are
  # up. Refuse at eval instead.
  reused =
    builtins.length names
    != builtins.length (builtins.attrNames (builtins.listToAttrs
      (map (n: {
          name = toString declared.${n}.index;
          value = null;
        })
        names)));
in
  assert uplinkMatch
  != null
  || throw "capsules.nix: uplinkNet must be a /16 written a.b.0.0/16, since a slot's index is the third octet of its /30, not '${uplinkNet}'";
  assert rejected
  == []
  || throw "capsules.nix: '${builtins.head rejected}' cannot name a slot — over 11 characters (IFNAMSIZ), or the aggregator's own name";
  assert !reused || throw "capsules.nix: two slots declare the same index, so they would share an uplink /30";
  assert undeclared
  == []
  || throw "capsules.nix: slot '${builtins.head undeclared}' names no policy, or names one the fleet's `policies` argument does not declare, or one outside its own `policies` set";
  assert misprofiled
  == []
  || throw "capsules.nix: slot '${builtins.head misprofiled}' declares a profile that is not a name — empty, `.`, `..`, the reserved `-`, or holding `/`, a newline, a tab, `$` or a backtick (host/profile-name.nix)"; {
    inherit uplinkNet socketOf volumeLock volumeReserve;

    # The shape check `misprofiled` applies to this host's slots, exported so
    # `profileCases` pins the function rather than a copy of it.
    inherit misprofiledIn;

    instances = instancesOf declared;

    # The same construction over a declaration that is not this host's, for the
    # one caller that must not follow this host's fleet size. `guardCases`
    # asserts what the guard *concludes* — one absent slot is a smaller fleet and
    # not a dead one — which is true at any size, so binding those cases here
    # would make widening the pool an edit to eleven expected strings and would
    # test today's declaration rather than the guard. Same seam as the guard's
    # `tools` (CLAUDE.md): what ties a program to this host is an argument, so a
    # case may substitute one.
    inherit instancesOf;

    # The aggregator. One per host, not per capsule, and the only place the
    # capsules' networks meet — which is why the drops between them live here
    # and not on any capsule's own link.
    egress = {
      ns = "${capLink}egress";
      dev = "eg-up";
      addr = addressing.egressAddr;
      peer = "eg-rt";
      # The host end: default route, NAT for `uplinkNet`, and the address the
      # host's resolver stub has to answer on for a capsule to keep the host's
      # DoT chain (docs/plan-c-implementation.md; a `~/flakes` edit).
      peerAddr = addressing.egressPeerAddr;
      prefix = 30;
      # The wildcard half of every instance's `uplink.peer`.
      linkPattern = "${capLink}*";
    };
  }
