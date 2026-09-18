# The capsules this host runs. Its own file for the same reason as net.nix and
# target.nix — several places need these values and none of them may spell them
# twice — and, like both, a *value*: it says which capsules exist and what each
# is called on the wire. What a capsule is made of is the units' business
# (docs/plan-c-implementation.md); nothing here reads the system or does work.
#
# What is deliberately NOT here is the host<->guest link. Under netns every
# capsule gets the same tap name, the same /30 and the same MAC, because each
# lives in its own namespace — that is the whole point of the shape, and it is
# what makes one guest image serve all of them (NOTES item 17). Those stay flat
# in net.nix. The only addressing that cannot be identical is each namespace's
# uplink to the aggregator, since the aggregator has a single routing table:
#
#   root ns          eg-rt      10.101.0.1/30   forwards, masquerades, and is
#                                               where the resolver stub must
#                                               also listen (~/flakes)
#   cap-egress ns    eg-up      10.101.0.2/30   the aggregator: every capsule's
#                    cap-<name> 10.100.<i>.1/30 proxy leaves through here, and
#                                               the drops between them live here
#   cap-<name> ns    up-<name>  10.100.<i>.2/30 the capsule's way out
#                    vm-capsule 10.99.0.1/30    net.nix, identical in every one
#
# That map is `probe/netns-egress.sh`'s, which is where it was verified
# (docs/probes.md) — the probe builds its own links because it must run without
# the units, so the names differ there and the shape does not.
let
  policies = import ./policies.nix;
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
  # statement is that these two names say nothing at all.
  #
  # Ten, which is Plan D D2's pool (docs/plan-d-fleet.md). It waited for the
  # guard to stop making one broken slot the whole host's problem: the audit set
  # is declared ∩ present now, so a slot that never came up is capacity that does
  # not exist rather than a refusal, and only a *present and wrong* namespace is
  # fleet-wide (NOTES item 30, run on this host).
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
  # `everything` is this host being a dev host out loud, rather than by nobody
  # having thought about it.
  #
  # `profile`, where a slot declares one, is which target the slot serves when
  # nobody has said otherwise — the operator's **convenience**, not a control, so
  # the perimeter's sentence above does not carry over: an unassigned slot with no
  # target is a perfectly fine state. There is no `profiles` set beside it,
  # because an assigner is unconstrained in `profile` by design
  # (docs/contract-assignment.md, *Who may assign*). Only the name's *shape* is
  # checked here (`misprofiled`, below); whether a document backs it is run-time
  # state outside the store, so `profileLoad` (host/profile.nix) checks that, at
  # use (SL-001 design sec-2).
  #
  # Every slot declares `doctrine` because this host builds one guest image and
  # it is doctrine's (`DEC-016`): a slot declaring another target would boot this
  # image anyway. A split waits on a slot having its own image (`IMP-006`). The
  # literal repeats `target.nix`'s `name` on purpose (`DEC-012`) — renaming the
  # target leaves these naming a document that no longer exists, and every verb
  # on them refuses loudly, at use.
  declared = {
    a = {
      index = 0;
      policy = "build";
      policies = policies.everything;
      profile = "doctrine";
    };
    b = {
      index = 1;
      policy = "build";
      policies = policies.everything;
      profile = "doctrine";
    };
    c = {
      index = 2;
      policy = "build";
      policies = policies.everything;
      profile = "doctrine";
    };
    d = {
      index = 3;
      policy = "build";
      policies = policies.everything;
      profile = "doctrine";
    };
    e = {
      index = 4;
      policy = "build";
      policies = policies.everything;
      profile = "doctrine";
    };
    f = {
      index = 5;
      policy = "build";
      policies = policies.everything;
      profile = "doctrine";
    };
    g = {
      index = 6;
      policy = "build";
      policies = policies.everything;
      profile = "doctrine";
    };
    h = {
      index = 7;
      policy = "build";
      policies = policies.everything;
      profile = "doctrine";
    };
    i = {
      index = 8;
      policy = "build";
      policies = policies.everything;
      profile = "doctrine";
    };
    j = {
      index = 9;
      policy = "build";
      policies = policies.everything;
      profile = "doctrine";
    };
  };

  # Carved into a /30 per capsule by index, so the aggregator's route and NAT
  # cover every capsule without enumerating them.
  uplinkNet = "10.100.0.0/16";

  # A capsule's link *in the aggregator*, and the wildcard the interface-pair
  # drop matches. One prefix, so the rule cannot drift from the names it drops.
  capLink = "cap-";

  # Where a capsule's way in lives. Its identity is its namespace and this
  # socket, never the VMM's name — one image means every VMM is `microvm@capsule`
  # (CLAUDE.md). Exposed as a function because a probe's throwaway capsule is not
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
  # clone only; growth of images already here is `RSK-007`.
  volumeReserve = 20 * 1024 * 1024 * 1024;

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
      addr = "10.100.${toString index}.2";
      peer = "${capLink}${name}"; # inside the aggregator
      gw = "10.100.${toString index}.1";
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
  assert rejected
  == []
  || throw "capsules.nix: '${builtins.head rejected}' cannot name a slot — over 11 characters (IFNAMSIZ), or the aggregator's own name";
  assert !reused || throw "capsules.nix: two slots declare the same index, so they would share an uplink /30";
  assert undeclared
  == []
  || throw "capsules.nix: slot '${builtins.head undeclared}' names no policy, or names one policies.nix does not declare, or one outside its own `policies` set";
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
      addr = "10.101.0.2";
      peer = "eg-rt";
      # The host end: default route, NAT for `uplinkNet`, and the address the
      # host's resolver stub has to answer on for a capsule to keep the host's
      # DoT chain (docs/plan-c-implementation.md; a `~/flakes` edit).
      peerAddr = "10.101.0.1";
      prefix = 30;
      # The wildcard half of every instance's `uplink.peer`.
      linkPattern = "${capLink}*";
    };
  }
