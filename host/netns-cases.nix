# What `capsule-netns` does to a kernel, asserted at build time against a stub
# one — SL-005 design sec-3.
#
# The third kind of check (CLAUDE.md), over the program that builds every slot's
# namespace. Its interesting branches are a namespace with no uplink and an `up`
# that fails half way, and a live host reaches the second only by breaking a
# rule load under a real unit.
#
# **Handed a fixture, and it says so**: a stubbed kernel and a scratch
# `/etc/netns`. `host/netns.nix` takes `tools` and `etcNetns` as arguments for
# exactly this — `writeShellApplication` puts `runtimeInputs` ahead of `PATH`, so
# a stub `ip` has to be *the* `ip`, and a stub cannot reach `up`'s own write of
# the resolver file into a build sandbox's read-only `/etc`. Everything else is
# the shipped text: the same function, applied once here with substitutes for
# those two and nothing more. The records it runs over come from the two
# constructors the units use — `casesCapsules.instancesOf` for a slot and
# `rooms.nix` for a room — and every case's environment is the subject's own
# `capsuleEnv` over its record, so the program is driven with what a unit would
# carry.
#
# The stubs log their argv, one line each, to `$CALLS`. `ip netns exec` runs its
# command, so the inner `sysctl`, `nft` and `ip route` log a second line and the
# heredoc reaches `nft`'s stdin; `nft` fails on request (`NFT_RC`). `ip netns
# pids` prints nothing — no VMM — so `down`'s refusal is never asked about a pid.
#
# What it does not prove (STD-001): that a real kernel accepts these calls, that
# any unit carries this environment or runs this program for a room (PHASE-05),
# or anything about live teardown. It is the call sequence against stubs.
{
  pkgs,
  lib,
  net,
  # `casesCapsules` (mkfleet.nix): the aggregator, uplink net and slot records.
  capsules,
  # `import ./netns.nix`, unapplied: the subject is applied once, below.
  netns,
  # `import ../rooms.nix`, unapplied: the room record's constructor.
  rooms,
}: let
  # The substitutes for a kernel — the suite's, not the program's, as in
  # host/guard-cases.nix.
  stubs = let
    log = name: ''echo "${name} $*" >>"$CALLS"'';
    ip = pkgs.writeShellScriptBin "ip" ''
      ${log "ip"}
      case "$1 $2" in
        "netns list") cat "$NS_FILE" ;;
        "netns exec") shift 3 && exec "$@" ;;
      esac
    '';
    nft = pkgs.writeShellScriptBin "nft" ''
      ${log "nft"}
      cat >>"$NFT_IN"
      [ "''${NFT_RC:-0}" = 0 ] || echo "nft: stub refuses the ruleset" >&2
      exit "''${NFT_RC:-0}"
    '';
    sysctl = pkgs.writeShellScriptBin "sysctl" (log "sysctl");
  in [ip nft sysctl pkgs.gnugrep pkgs.coreutils];

  # A fixed path, because the program's is fixed at build. The sandbox's `/tmp`
  # is private and writable; each case recreates it.
  etcNetns = "/tmp/netns-cases-etc";

  subject = netns {
    inherit pkgs lib net capsules etcNetns;
    tools = stubs;
  };
  program = lib.getExe subject.programs.capsule;

  slot = (capsules.instancesOf {a = {index = 0;};}).a;
  room =
    (rooms {inherit lib;} {
      rooms.r = {
        users.ada = ["ssh-ed25519 AAAA fixture"];
        sizes = {};
      };
      slotNames = [slot.name];
    })
    .instances
    .r;

  slotEnv = subject.capsuleEnv slot;
  roomEnv = subject.capsuleEnv room;
  egressNs = capsules.egress.ns;
  inherit (slot.uplink) dev peer addr gw;
  uplinkPrefix = toString slot.uplink.prefix;

  # Namespace, loopback, forwarding off: what both shapes build first.
  base = ns: [
    "ip netns add ${ns}"
    "ip -n ${ns} link set lo up"
    "ip netns exec ${ns} sysctl -q -w net.ipv4.ip_forward=0"
    "sysctl -q -w net.ipv4.ip_forward=0"
    "ip netns exec ${ns} sysctl -q -w net.ipv4.conf.all.forwarding=0"
    "sysctl -q -w net.ipv4.conf.all.forwarding=0"
  ];
  ruleLoad = ns: [
    "ip netns exec ${ns} nft -f -"
    "nft -f -"
  ];
  # The tap guard rule, as `up` renders it: the no-uplink shape's whole
  # perimeter beside forwarding off (POL-001).
  guardRule = [
    "table ip capsule-guard"
    ''iifname "${net.tap}" ip daddr != ${net.host} drop''
  ];
  # What only an uplink calls for: building the veth and its route, moving the
  # peer, and `undo_up` deleting it. A guest with no uplink makes none of them.
  uplinkOnly = ["veth" "netns ${egressNs}" "route" "link del"];

  # `want` is the exit status and `calls` the whole of `$CALLS`, in order.
  # `says` must appear in the program's output, `lacks` must not appear in
  # `$CALLS` (redundant with `calls`, but it names the reason when it fails),
  # `rules` must appear in what `nft` was fed, and `resolver` names the one
  # resolver file `up` leaves; without it, `etcNetns` must be left empty.
  cases = [
    {
      # Characterisation: the slot path is today's, line for line.
      name = "1 a slot's up builds the uplink, unchanged";
      arg = "up";
      env = slotEnv;
      want = 0;
      calls =
        base slot.ns
        ++ [
          "ip link add ${dev} type veth peer name ${peer}"
          "ip link set ${dev} netns ${slot.ns}"
          "ip link set ${peer} netns ${egressNs}"
          "ip -n ${slot.ns} addr add ${addr}/${uplinkPrefix} dev ${dev}"
          "ip -n ${egressNs} addr add ${gw}/${uplinkPrefix} dev ${peer}"
          "ip -n ${slot.ns} link set ${dev} up"
          "ip -n ${egressNs} link set ${peer} up"
          "ip netns exec ${slot.ns} ip route add default via ${gw}"
          "ip route add default via ${gw}"
        ]
        ++ ruleLoad slot.ns;
      rules = guardRule;
      resolver = {
        ns = slot.ns;
        content = "nameserver ${subject.resolver}";
      };
    }
    {
      name = "2 no uplink: no veth, route or resolver, and the guard rule is loaded";
      arg = "up";
      env = roomEnv;
      want = 0;
      calls = base room.ns ++ ruleLoad room.ns;
      lacks = uplinkOnly;
      rules = guardRule;
    }
    {
      # Refused before anything is built, so nothing is left to tear down.
      name = "3 a partial uplink group is refused naming both halves";
      arg = "up";
      env = removeAttrs slotEnv ["PEER" "ADDR" "GW" "UPLINK_PREFIX" "RESOLVER"];
      want = 1;
      says = "set: EGRESS_NS DEV; unset: PEER ADDR GW UPLINK_PREFIX RESOLVER";
      calls = [];
    }
    {
      name = "4 no uplink, the rule load fails: undo_up deletes the namespace and no peer";
      arg = "up";
      env = roomEnv // {NFT_RC = "1";};
      want = 1;
      says = "stub refuses the ruleset";
      calls = base room.ns ++ ruleLoad room.ns ++ ["ip netns del ${room.ns}"];
      lacks = uplinkOnly;
    }
    {
      name = "5 no uplink, down: the namespace is deleted and no peer";
      arg = "down";
      env = roomEnv;
      present = [room.ns];
      want = 0;
      calls = [
        "ip netns list"
        "ip netns pids ${room.ns}"
        "ip netns del ${room.ns}"
      ];
      lacks = uplinkOnly;
    }
  ];

  q = lib.escapeShellArg;
  lines = xs: q (lib.concatMapStrings (x: "${x}\n") xs);
  fail = name: what: ''
    {
      echo "FAIL ${name}: ${what}"
      sed 's/^/    out: /' out
      sed 's/^/    call: /' calls
    } >&2
    exit 1
  '';

  # Each case in its own subshell, so one red case does not hide the next: the
  # suite reports every failure and then fails. Errexit does not reach inside
  # an `||` list, so each step that sets up state says so when it fails.
  runCase = i: c: ''
    (
    mkdir case-${toString i} && cd case-${toString i} || exit 1
    rm -rf ${etcNetns} && mkdir ${etcNetns} || exit 1
    : >calls && : >nft-in || exit 1
    printf %s ${lines (c.present or [])} >ns || exit 1
    rc=0
    env -i PATH="$PATH" CALLS="$PWD/calls" NFT_IN="$PWD/nft-in" NS_FILE="$PWD/ns" \
      ${lib.concatStringsSep " " (lib.mapAttrsToList (k: v: "${k}=${q v}") c.env)} \
      ${program} ${c.arg} >out 2>&1 || rc=$?
    [ "$rc" = ${toString c.want} ] || {
      ${fail c.name "exit $rc, wanted ${toString c.want}"}
    }
    ${lib.optionalString (c ? says) ''
      grep -qF -- ${q c.says} out || {
        ${fail c.name "nothing matching ${c.says}"}
      }
    ''}
    ${lib.concatMapStrings (s: ''
        ! grep -qF -- ${q s} calls || {
          ${fail c.name "a call matching ${s}"}
        }
      '')
      (c.lacks or [])}
    printf %s ${lines c.calls} >want-calls
    diff want-calls calls >calls.diff || {
      sed 's/^/    diff: /' calls.diff >&2
      ${fail c.name "the call sequence differs (want < > got)"}
    }
    ${lib.concatMapStrings (s: ''
        grep -qF -- ${q s} nft-in || {
          ${fail c.name "nft was not fed ${s}"}
        }
      '')
      (c.rules or [])}
    ${
      if c ? resolver
      then ''
        [ "$(cat ${etcNetns}/${c.resolver.ns}/resolv.conf)" = ${q c.resolver.content} ] || {
          ${fail c.name "the resolver file is not ${c.resolver.content}"}
        }
      ''
      else ''
        [ -z "$(ls -A ${etcNetns})" ] || {
          ${fail c.name "${etcNetns} is not empty: $(ls -A ${etcNetns})"}
        }
      ''
    }
    echo "ok (${toString c.want}) ${c.name}" >>"$log"
    ) || failed=1
  '';

  # `capsuleEnv` is read at eval and asserted in the shell: a unit's
  # `Environment=` for a room carries nothing of an uplink, and a slot's is
  # today's eleven.
  envNames = env: q (toString (lib.attrNames env));
  envPin = name: env: want: ''
    if [ ${envNames env} = ${q want} ]; then
      echo "ok capsuleEnv for ${name}: ${want}" >>"$log"
    else
      echo "FAIL capsuleEnv for ${name}: got "${envNames env}", wanted ${want}" >&2
      failed=1
    fi
  '';
in
  pkgs.runCommand "capsule-netns-cases" {} ''
    log=$PWD/log
    : >"$log"
    failed=0
    ${envPin "a slot" slotEnv "ADDR DEV EGRESS_NS GW NS PEER PREFIX RESOLVER TAP TAP_ADDR UPLINK_PREFIX"}
    ${envPin "a room" roomEnv "NS PREFIX TAP TAP_ADDR"}
    ${lib.concatStrings (lib.imap1 runCase cases)}
    [ "$failed" = 0 ] || exit 1
    cp "$log" $out
    cat $out
  ''
