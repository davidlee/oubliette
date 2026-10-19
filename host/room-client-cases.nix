# A room client's bundle (host/room-client.nix, `DEC-057`): `etc/ssh_config`
# and `bin/ssh`, the door to room `<r>` for a client on this host and its jail.
# The subject is the **shipped** bundle at the caller's first declared room, and
# the shipped `roomDoor.words` (host/room-door.nix) it must agree with.
#
# The third kind of check (CLAUDE.md), over a build product rather than a
# program: `ssh -G` reads the bundle's config the way a client's ssh will, and
# connects to nothing.
#
# 1. the bundle's config, resolved: strict checking, the room's alias, its one
#    trust store, no global known_hosts, and a ProxyCommand that is socat by
#    store path to the record's socket; one `Host *` and no user or identity;
#    the passthru;
# 2. `Host *`: the same ProxyCommand whatever the client calls the room —
#    `room-<r>`, `net.guest` (the fixture's `10.99.0.2`) or `<r>`;
# 3. the other render, `words` at `accept-new`, names the same alias, store,
#    global setting and ProxyCommand;
# 4. the binds: the door's parent and the room's state directory, nothing else;
# 5. `bin/ssh` is openssh's, linked rather than wrapped.
#
# **Handed a fixture** for case 6, and it is the fixture this suite says it has:
# the same builder at state root `/build/state`, with the record's socket moved
# under it (as `roomVerbsCases` moves one), since a sandbox cannot write the
# declared root nor make a socket under `/run` (RV-023 F-8). A fixture `sshd -i`
# that accepts nobody stands behind that socket (host/fixture-sshd.nix, RV-023
# F-5): the bundle's ssh refuses it before the key is learned, an `accept-new`
# door learns it, and the bundle's ssh then reaches authentication and writes
# nothing (`DEC-056`).
#
# **The absent path**: a fleet with no rooms has no bundle, the suite is handed
# `room = null`, and it says so and passes.
#
# **Not pinned** (STD-001): authentication itself; a real jail's bind of the two
# directories; `/run/capsule-room` surviving a relay stop (`ASM-004`, the live
# rung's); a host with a global known_hosts entry, since a sandbox has none
# (cases 1 and 3 pin the option that ignores one).
{
  pkgs,
  lib,
  # host/programs.nix's `roomDoor`, for the other render.
  roomDoor,
  # The declared state root (mkFleet's `stateDir`), for the values spelled here.
  stateDir,
  # The fleet's guest address (`net.guest`), one name a client may use.
  guest,
  # The first declared room's name, its record and its shipped bundle; all null
  # with no rooms.
  room,
  record,
  bundle,
  # The same builder at `/build/state`, the record's socket moved under it.
  fixture,
}: let
  esc = lib.escapeShellArg;
  fixtureSshd = import ./fixture-sshd.nix {inherit pkgs;};
  cases = ''
    room=${esc room}
    state=${esc stateDir}
    socket=${esc record.socket}
    guest=${esc guest}
    # Spelled here rather than read from the bundle, so a passthru or a render
    # that drifted from the convention goes red (A7).
    kh=$state/room/$room/known_hosts
    cfg=${bundle}/etc/ssh_config

    # ----------------------------------------------- 1. the bundle's config
    run ssh -G -F "$cfg" anyhost
    ck "1: ssh -G over the bundle's config resolves" 0 "$rc"
    cp "$here/out" "$here/g1"
    ck "  stricthostkeychecking true" "stricthostkeychecking true" "$(opt stricthostkeychecking g1)"
    ck "  hostkeyalias room-$room" "hostkeyalias room-$room" "$(opt hostkeyalias g1)"
    ck "  userknownhostsfile, the room's one trust store" "userknownhostsfile $kh" "$(opt userknownhostsfile g1)"
    ck "  globalknownhostsfile none" "globalknownhostsfile none" "$(opt globalknownhostsfile g1)"
    ck "  proxycommand is socat by store path to the record's socket" ok "$(proxied g1)"
    ck "  one Host line, and it is Host *" "Host *" \
      "$(grep -iE '^[[:space:]]*(host|match)([[:space:]]|=)' "$cfg" 2>/dev/null)"
    ck "  no user and no identity" "" \
      "$(grep -iE '^[[:space:]]*(user|identityfile|identitiesonly|certificatefile|identityagent)([[:space:]]|=)' "$cfg" 2>/dev/null)"
    ck "  passthru room" "$room" ${esc bundle.room}
    ck "  passthru hostKeyAlias" "room-$room" ${esc bundle.hostKeyAlias}
    ck "  passthru knownHosts" "$kh" ${esc bundle.knownHosts}
    ck "  passthru socket is the record's" "$socket" ${esc bundle.socket}
    ck "  passthru config is the file etc/ssh_config is" ${bundle.config} "$(readlink -f "$cfg")"

    # ----------------------------------------------- 2. Host *, three names
    for dest in "room-$room" "$guest" "$room"; do
      run ssh -G -F "$cfg" -l x "$dest"
      ck "2: destination $dest gets the room's proxycommand" ok "$(proxied out)"
    done

    # ----------------------------------------------- 3. the other render
    run ssh -G -F /dev/null ${roomDoor.words {
      checking = "accept-new";
      inherit room;
      inherit (record) socket;
      knownHosts = roomDoor.knownHostsOf stateDir room;
    }} anyhost
    ck "3: ssh -G over the words resolves" 0 "$rc"
    cp "$here/out" "$here/g3"
    for k in hostkeyalias userknownhostsfile globalknownhostsfile proxycommand; do
      ck "  $k is the bundle's" "$(opt "$k" g1)" "$(opt "$k" g3)"
    done
    ck "  and globalknownhostsfile none of its own" "globalknownhostsfile none" "$(opt globalknownhostsfile g3)"
    ck "  stricthostkeychecking accept-new" "stricthostkeychecking accept-new" "$(opt stricthostkeychecking g3)"

    # ----------------------------------------------- 4. the binds
    # The door's parent, not the door's own directory: that is the relay's
    # RuntimeDirectory and goes on every stop (DEC-056).
    binds=(${lib.escapeShellArgs bundle.binds})
    ck "4: two binds" 2 "''${#binds[@]}"
    ck "  the first is the socket's grandparent" "$(dirname "$(dirname "$socket")")" "''${binds[0]-}"
    ck "  the second is the trust store's directory" "$(dirname "$kh")" "''${binds[1]-}"
    ck "  which is the room's state directory" "$state/room/$room" "''${binds[1]-}"
    ck "  and the first holds the socket" yes "$(under "''${binds[0]-}" "$socket")"
    ck "  and the second the trust store" yes "$(under "''${binds[1]-}" "$kh")"

    # ----------------------------------------------- 5. bin/ssh
    ck "5: bin/ssh is a link, not a wrapper" yes "$([ -L ${bundle}/bin/ssh ] && echo yes || echo no)"
    to=$(readlink -f ${bundle}/bin/ssh || true)
    ck "  to openssh's ssh, executable" yes \
      "$([[ $to =~ ^/nix/store/[a-z0-9]{32}-openssh-[^/]+/bin/ssh$ ]] && [ -x "$to" ] && echo yes || echo "no: $to")"
    run ${bundle}/bin/ssh -V
    saw "OpenSSH_"

    # ----------------------------------------------- 6. a fixture sshd
    # A writable root, or nothing below means what it says (RV-023 F-8).
    if [ "$NIX_BUILD_TOP" != /build ]; then
      echo "FAIL 6: the sandbox's root is '$NIX_BUILD_TOP', not /build, so the fixture's root is not writable here" >&2
      exit 1
    fi
    echo "ok   6: the sandbox's root is /build" >>"$log"
    fsock=${esc fixture.socket}
    fkh=${esc fixture.knownHosts}
    fbinds=(${lib.escapeShellArgs fixture.binds})
    for p in "$fsock" "$fkh" "''${fbinds[@]}"; do
      ck "  $p is under the fixture's root" yes "$(under /build/state "$p")"
    done
    ck "  the fixture has two binds" 2 "''${#fbinds[@]}"
    ck "  and they followed the socket" "$(dirname "$(dirname "$fsock")")" "''${fbinds[0]-}"

    # The state the case needs, produced rather than inherited: the room's
    # directory as tmpfiles makes it, and an sshd behind the record's socket.
    mkdir -p -m 0700 /build/state/room/"$room"
    mkdir -p "$(dirname "$fsock")" /build/fixture-sshd
    sshd_fixture /build/fixture-sshd
    trap stopListeners EXIT
    serve "$fsock" "$sshd_exec"
    door=(-o BatchMode=yes -o ConnectTimeout=10 -l x "room-$room" true)

    # (a) Strict, and no key known: refused at the key, and nothing written.
    run ${fixture}/bin/ssh -F ${fixture}/etc/ssh_config "''${door[@]}"
    ck "6 (a): the bundle refuses a key it has not learned, 255" 255 "$rc"
    saw "Host key verification failed"
    never "Permanently added"
    ck "  and writes no known_hosts" absent "$([ -e "$fkh" ] && echo present || echo absent)"

    # (b) An `accept-new` door, the shipped words, learns the key.
    run ssh ${roomDoor.words {
      checking = "accept-new";
      inherit room;
      inherit (fixture) socket knownHosts;
    }} "''${door[@]}"
    ck "6 (b): an accept-new door learns the key and fails at auth, 255" 255 "$rc"
    saw "Permanently added"
    saw "Permission denied"
    ck "  filing one key, the fixture's, under the room's alias" \
      "room-$room $(cut -d' ' -f1,2 /build/fixture-sshd/hostkey.pub)" "$(cat "$fkh" 2>/dev/null)"
    cp "$fkh" "$here/kh.b" 2>/dev/null || :

    # (c) Strict, the key known: past the key, and still writes nothing.
    run ${fixture}/bin/ssh -F ${fixture}/etc/ssh_config "''${door[@]}"
    ck "6 (c): the bundle then reaches auth, 255" 255 "$rc"
    saw "Permission denied"
    never "Host key verification failed"
    ck "  and leaves known_hosts as (b) left it" same "$(cmp -s "$fkh" "$here/kh.b" && echo same || echo changed)"
    ck "  and no other known_hosts exists" "$fkh" "$(find /build -name 'known_hosts*' -type f)"
  '';
in
  pkgs.runCommand "capsule-room-client-cases" {
    # openssh for the client's `ssh -G`, the fixture sshd and its host key;
    # socat for the fixture's listener. The bundle carries its own of both.
    nativeBuildInputs = [pkgs.openssh pkgs.socat];
  } ''
    export HOME=$PWD
    here=$PWD

    fail=0
    log=$here/log
    : >"$log"
    shown() { sed 's/^/    out: /' "$here/out" >&2; sed 's/^/    err: /' "$here/err" >&2; }
    ck() {
      if [ "$2" = "$3" ]; then echo "ok   $1" >>"$log"
      else echo "FAIL $1: got '$3', wanted '$2'" >&2; shown; fail=1; fi
    }
    saw() {
      if grep -qF -- "$1" "$here/err"; then echo "ok   ...and says '$1'" >>"$log"
      else echo "FAIL missing reason '$1'" >&2; shown; fail=1; fi
    }
    never() {
      if grep -qF -- "$1" "$here/err"; then echo "FAIL said '$1' and should not have" >&2; shown; fail=1
      else echo "ok   ...and never says '$1'" >>"$log"; fi
    }
    run() { rc=0; "$@" >"$here/out" 2>"$here/err" || rc=$?; }
    : >"$here/out"; : >"$here/err"
    # One option's line of an `ssh -G` output.
    opt() { grep -m1 "^$1 " "$here/$2" || :; }
    # yes when DIR is non-empty and PATH is strictly beneath it.
    under() { if [ -n "$1" ] && [[ $2 == "$1"/* ]]; then echo yes; else echo no; fi; }
    # An `ssh -G` output's proxycommand, judged on its own: socat by store path,
    # executable, to the record's socket. Independent of any other output, so
    # one destination's red cannot colour another's.
    proxied() {
      local line w1 rest
      line=$(opt proxycommand "$1")
      [ -n "$line" ] || { echo "no proxycommand"; return; }
      read -r _ w1 rest <<<"$line"
      if ! [[ $w1 =~ ^/nix/store/[a-z0-9]{32}-socat-[^/]+/bin/socat$ ]] || [ ! -x "$w1" ]; then
        echo "first word '$w1'"; return
      fi
      [ "$rest" = "- UNIX-CONNECT:$socket" ] || { echo "rest '$rest'"; return; }
      echo ok
    }

    ${fixtureSshd}

    ${
      if room == null
      then ''echo "skip no room is declared, so there is no bundle to pin" >>"$log"''
      else cases
    }

    # A red run shows its ok lines too, so a mutation's signature reads whole.
    if [ "$fail" != 0 ]; then sed 's/^/log: /' "$log" >&2; exit 1; fi
    cp "$log" $out
    cat $out
  ''
