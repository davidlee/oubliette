# What the one root program on the volume path decides — SL-002 design sec-3.
#
# The third kind of check (CLAUDE.md), over `capsule-volume-root`. Every branch
# here is one a live host reaches only by deleting or overwriting a real slot's
# volume as root, so the suite is where they get exercised at all.
#
# **Handed a fixture pool, and it renders its own subject on purpose**, as
# `host/policy-cases.nix` does. The helper's roots and its lock are *build-time*
# arguments, never run-time ones, because it runs as root and a later
# password-less grant (`IMP-010`) must not be pointable at `/`. So the shipped
# store path cannot be aimed at a sandbox, and a render against one is the only
# way to run the text. The render differs from the shipped one in those values
# and in `tools` alone; the shipped render is built too, and read for the one
# line the fixture's `tools` replaces.
#
# `tools` is the three steps a sandbox cannot provoke: a filesystem small enough
# to refuse a clone (`freeBytes`), a second uid (`asImageOwner`), and a failure
# between two lines (`commitImage`). The owner stub runs its command as the build
# user and logs it, so a case asserts *which* acts went through the drop — the
# whole of `RV-003` `F-1`'s fix, since no sandbox has a VMM racing a symlink. The
# commit stub logs whether the marker was already there when it ran, because the
# marker's ordering against the commit is the invariant sec-3's crash table rests
# on, and only the moment of the commit can see it.
#
# Both rules for writing a case apply: each refusal asserts its reason as well as
# its status, and nothing a refusal should not have made is left behind. Each case
# starts from `fresh`, so none inherits the previous case's residue. Each of these
# was applied to `host/volume-root.nix` and watched turning exactly its own cases
# red (SL-002 PHASE-01): the marker written after the commit; a failed commit
# removing a marker it did not write; the EXIT trap dropped; the lock not taken;
# a leftover copy not removed first; the copy run as root rather than as the
# owner. The trap's first case passed with the trap gone, which is why the copy
# now also fails *after* the temporary image exists.
{
  pkgs,
  lib,
  capsules,
}: let
  # Four slots, none of them this host's, one per precondition: a source, a
  # destination with everything, one that was created but has no record
  # directory, and one never created at all.
  fixture =
    capsules
    // {
      instances = capsules.instancesOf {
        src = {index = 0;};
        dst = {index = 1;};
        norec = {index = 2;};
        never = {index = 3;};
      };
      volumeLock = ''"$CASE_ROOT/run/volume.lock"'';
      volumeReserve = 4096;
    };
  helper = import ./volume-root.nix {
    inherit pkgs lib;
    capsules = fixture;
    microvms = ''"$CASE_ROOT/microvms"'';
    moduleState = ''"$CASE_ROOT/state"'';
    tools = ''
      freeBytes() {
        if [ -n "''${CASE_FREE:-}" ]; then echo "$CASE_FREE"
        else df --output=avail -B1 "$1" | tail -n 1; fi
      }
      commitImage() {
        local m
        m="$CASE_ROOT/state/slot/$(basename "$(dirname "$2")")/scrub-pending"
        if [ -e "$m" ]; then echo "marker present" >> "$CASE_LOG"
        else echo "marker absent" >> "$CASE_LOG"; fi
        [ -z "''${CASE_COMMIT_FAIL:-}" ] || return 1
        asImageOwner mv -T -- "$1" "$2"
      }
      # The command and the name it acts on, which is enough to tell the copy's
      # temporary image from the image and from the marker. Refusing one command
      # by name is the only failure a sandbox can put after the copy exists.
      asImageOwner() {
        echo "$1 $(basename "''${*: -1}")" >> "$CASE_OWNER_LOG"
        [ "$1" != "''${CASE_OWNER_FAIL:-}" ] || return 1
        "$@"
      }
    '';
  };
  # This host's values and the real `tools`, for the lines a fixture replaces.
  shipped = import ./volume-root.nix {inherit pkgs lib capsules;};
in
  pkgs.runCommand "capsule-volume-root-cases" {nativeBuildInputs = [pkgs.util-linux];} ''
    fail=0
    ck() {
      if [ "$2" = "$3" ]; then echo "ok   $1" >>"$log"
      else echo "FAIL $1: got '$3', wanted '$2'" >&2; fail=1; fi
    }
    ckt() {
      if "''${@:2}"; then echo "ok   $1" >>"$log"
      else echo "FAIL $1" >&2; fail=1; fi
    }
    log=$PWD/log
    : >"$log"

    export CASE_ROOT=$PWD/root CASE_LOG=$PWD/commits CASE_OWNER_LOG=$PWD/owner
    helper=${helper}/bin/capsule-volume-root
    size=$((64 * 1024 * 1024))
    reserve=${toString fixture.volumeReserve}

    img() { echo "$CASE_ROOT/microvms/$1/capsule-work.img"; }
    tmp() { echo "$CASE_ROOT/microvms/$1/capsule-work.img.clone"; }
    marker() { echo "$CASE_ROOT/state/slot/$1/scrub-pending"; }
    alloc() { echo $(($(stat -c '%b * %B' "$1"))); }
    run() { rc=0; "$helper" "$@" >out 2>err || rc=$?; }
    owned() { tr '\n' ',' <"$CASE_OWNER_LOG" | sed 's/,$//'; }

    # Every slot but `never` created; record directories for `src` and `dst`
    # only; a sparse source with bytes at both ends so a copy that lost either is
    # visible; no destination image, no marker, no lock held.
    fresh() {
      rm -rf "$CASE_ROOT"
      mkdir -p "$CASE_ROOT/run" "$CASE_ROOT/microvms/never" \
        "$CASE_ROOT/state/slot/src" "$CASE_ROOT/state/slot/dst"
      for s in src dst norec; do
        mkdir -p "$CASE_ROOT/microvms/$s/current/bin"
        printf '#!/bin/sh\n' >"$CASE_ROOT/microvms/$s/current/bin/tap-up"
        chmod +x "$CASE_ROOT/microvms/$s/current/bin/tap-up"
      done
      truncate -s "$size" "$(img src)"
      printf head | dd of="$(img src)" conv=notrunc status=none
      printf tail | dd of="$(img src)" bs=1 seek=$((size - 4)) conv=notrunc status=none
      : >"$CASE_LOG"
      : >"$CASE_OWNER_LOG"
      unset CASE_FREE CASE_COMMIT_FAIL CASE_OWNER_FAIL
    }
    # An old destination image the operator would lose, distinguishable from a copy.
    oldDest() { printf old >"$(img dst)"; }
    earlierMarker() { printf 'source=earlier at=then\n' >"$(marker dst)"; cp "$(marker dst)" before; }
    # Something holding a file open, the way a VMM holds its image: a process that
    # opened it and is doing nothing, waited for until the descriptor exists.
    hold() {
      sleep 1000 3<"$1" &
      holder=$!
      for _ in $(seq 200); do [ -e "/proc/$holder/fd/3" ] && break; sleep 0.01; done
    }
    release() { kill "$holder"; wait "$holder" 2>/dev/null || true; }

    # ------------------------------------------------------------------ premises
    #
    # Two cases below rest on the sandbox, and each would pass for the wrong
    # reason if it were false: a mode refuses no read to root, and a sparse check
    # on a filesystem that cannot hold holes proves nothing.
    ckt "premise: the sandbox is not root" test "$(id -u)" != 0
    fresh
    ckt "premise: the fixture source is sparse" test "$(alloc "$(img src)")" -lt "$size"

    # --------------------------------------------------------------------- usage
    fresh
    run
    ck "no sub-command is a usage error" 2 "$rc"
    ckt "  and says so" grep -q '^usage: capsule-volume-root' err
    run resize dst
    ck "an unknown sub-command is a usage error" 2 "$rc"
    run reset
    ck "reset with no slot is a usage error" 2 "$rc"
    run reset dst src
    ck "reset with two slots is a usage error" 2 "$rc"
    run clone src
    ck "clone with one slot is a usage error" 2 "$rc"
    run clone src dst --force
    ck "clone takes --identity and nothing else" 2 "$rc"

    # --------------------------------------------------------------------- reset
    fresh
    oldDest
    run reset capsule
    ck "reset refuses an undeclared name" 1 "$rc"
    ckt "  as undeclared" grep -q 'not a declared slot: capsule' err
    run reset ../dst
    ck "reset refuses a path for a name" 1 "$rc"
    ckt "  as undeclared" grep -q 'not a declared slot: \.\./dst' err
    ckt "  and deleted nothing" test -e "$(img dst)"

    fresh
    oldDest
    touch "$(marker dst)"
    hold "$(img dst)"
    run reset dst
    release
    ck "reset refuses an image held open" 1 "$rc"
    ckt "  as held open" grep -q 'held open' err
    ckt "  naming the pid that holds it" grep -qw "$holder" err
    ckt "  and deleted neither image nor marker" test -e "$(img dst)" -a -e "$(marker dst)"

    fresh
    touch "$(marker dst)"
    run reset dst
    ck "reset of a slot with no image succeeds" 0 "$rc"
    ckt "  saying it was already fresh" grep -q 'already fresh' out
    ckt "  and clears a stale marker" test ! -e "$(marker dst)"
    ck "  as root, since the record directory is not the image owner's" "" "$(owned)"

    fresh
    oldDest
    touch "$(marker dst)"
    run reset dst
    ck "reset deletes an image nothing holds" 0 "$rc"
    ckt "  the image is gone" test ! -e "$(img dst)"
    ckt "  and so is the marker, since a cold volume has no identity" test ! -e "$(marker dst)"
    ck "  the image was removed as its owner, and the marker as root" "rm capsule-work.img" "$(owned)"
    ckt "  and no other slot's image was touched" test -e "$(img src)"

    # ---------------------------------------------------------------------- lock
    #
    # Held on a descriptor of this shell's own, so there is no race to wait out;
    # the helper is run with that descriptor closed, so its lock is a second open
    # of the file and conflicts as another process's would.
    fresh
    oldDest
    exec 8<>"$CASE_ROOT/run/volume.lock"
    flock -n 8
    run reset dst 8>&-
    ck "reset refuses while another volume operation holds the lock" 1 "$rc"
    ckt "  by reason" grep -q 'another volume operation' err
    ckt "  and deleted nothing" test -e "$(img dst)"
    run clone src dst 8>&-
    ck "clone refuses while the lock is held" 1 "$rc"
    ckt "  by reason" grep -q 'another volume operation' err
    ckt "  and copied nothing" test ! -e "$(tmp dst)" -a ! -e "$(marker dst)"
    ckt "  and the destination is as it was" grep -qx old "$(img dst)"
    run 8>&-
    ck "a usage error takes no lock" 2 "$rc"
    exec 8>&-
    run reset dst
    ck "once the lock is released, reset acts" 0 "$rc"
    ckt "  and the image is gone" test ! -e "$(img dst)"

    # ---------------------------------------------------------- clone refusals
    #
    # After each: no record directory was made, no copy was left, no marker was
    # written. The helper runs as root, and a record directory root made would
    # refuse every later record write (sec-3 step 1).
    nothingMade() {
      ckt "  and made no record directory" test ! -e "$CASE_ROOT/state/slot/$1"
      ckt "  and left no copy" test ! -e "$(tmp "$1")" -a ! -e "$(img "$1")"
    }

    fresh
    run clone src src
    ck "clone refuses a slot onto itself" 1 "$rc"
    ckt "  as the same slot" grep -q 'same slot' err
    ckt "  and wrote no marker" test ! -e "$(marker src)"

    fresh
    run clone capsule dst
    ck "clone refuses an undeclared source" 1 "$rc"
    ckt "  as undeclared" grep -q 'not a declared slot: capsule' err

    fresh
    run clone src capsule
    ck "clone refuses an undeclared destination" 1 "$rc"
    ckt "  as undeclared" grep -q 'not a declared slot: capsule' err
    nothingMade capsule

    fresh
    rm "$(img src)"
    run clone src dst
    ck "clone refuses a source with no image" 1 "$rc"
    ckt "  as having no image" grep -q 'src has no image' err
    ckt "  and wrote no marker" test ! -e "$(marker dst)"

    fresh
    run clone src never
    ck "clone refuses a destination never created" 1 "$rc"
    ckt "  as never created" grep -q 'never created' err
    nothingMade never

    fresh
    run clone src norec
    ck "clone refuses a destination with no record directory" 1 "$rc"
    ckt "  as having none" grep -q 'no record directory' err
    nothingMade norec

    fresh
    hold "$(img src)"
    run clone src dst
    release
    ck "clone refuses a source held open" 1 "$rc"
    ckt "  naming the pid" grep -qw "$holder" err
    ckt "  and copied nothing" test ! -e "$(img dst)" -a ! -e "$(marker dst)"

    fresh
    oldDest
    hold "$(img dst)"
    run clone src dst
    release
    ck "clone refuses a destination held open" 1 "$rc"
    ckt "  naming the pid" grep -qw "$holder" err
    ckt "  and the destination is as it was" grep -qx old "$(img dst)"

    # ----------------------------------------------------------------------- fit
    fresh
    need=$(($(alloc "$(img src)") + reserve))
    export CASE_FREE=$((need - 1))
    run clone src dst
    ck "clone refuses when allocation plus reserve is one byte over free" 1 "$rc"
    ckt "  as not fitting" grep -q 'does not fit' err
    ckt "  naming the reserve" grep -q "$reserve" err
    ckt "  and copied nothing" test ! -e "$(img dst)" -a ! -e "$(tmp dst)" -a ! -e "$(marker dst)"
    ck "  and acted on nothing" "" "$(owned)"

    fresh
    export CASE_FREE=$need
    run clone src dst
    ck "clone proceeds when allocation plus reserve equals free" 0 "$rc"

    # ---------------------------------------------------------------- the copy
    fresh
    chmod 000 "$(img src)"
    run clone src dst
    ckt "a copy that cannot read its source exits non-zero" test "$rc" -ne 0
    ckt "  and writes no marker" test ! -e "$(marker dst)"
    ckt "  and no destination image" test ! -e "$(img dst)"

    # `cp` refuses an unreadable source before it creates anything, so the case
    # above cannot see the trap: it passed with the trap removed. A step that
    # fails once the temporary image exists can.
    fresh
    export CASE_OWNER_FAIL=chmod
    run clone src dst
    ckt "a copy that fails after the temporary image exists exits non-zero" test "$rc" -ne 0
    ckt "  and the trap removed the temporary image" test ! -e "$(tmp dst)"
    ck "  as the owner too" \
      "rm capsule-work.img.clone,cp capsule-work.img.clone,chmod capsule-work.img.clone,rm capsule-work.img.clone" \
      "$(owned)"
    ckt "  and wrote no marker" test ! -e "$(marker dst)"
    ckt "  and no destination image" test ! -e "$(img dst)"

    # A leftover the copy could not overwrite, so a helper that did not remove it
    # first fails here rather than passing on `cp`'s own truncation.
    fresh
    oldDest
    printf stale >"$(tmp dst)"
    chmod 000 "$(tmp dst)"
    run clone src dst
    ck "clone succeeds over a leftover copy from a killed run" 0 "$rc"
    ckt "  the destination is the source, byte for byte" cmp -s "$(img src)" "$(img dst)"
    ckt "  and still sparse" test "$(alloc "$(img dst)")" -lt "$size"
    ck "  mode 0644, as the runner's own images" 644 "$(stat -c '%a' "$(img dst)")"
    ckt "  the temporary name is gone" test ! -e "$(tmp dst)"
    ckt "  a marker naming the source was written" grep -q '^source=src ' "$(marker dst)"
    ck "  and it existed when the image was committed" "marker present" "$(cat "$CASE_LOG")"
    # `RV-003` `F-1`: root does no path-based act in a directory a VMM's uid can
    # write. Every one of them is here, in order, and the marker is not.
    ck "  every act in the image directory ran as the image owner" \
      "rm capsule-work.img.clone,cp capsule-work.img.clone,chmod capsule-work.img.clone,mv capsule-work.img,rm capsule-work.img.clone" \
      "$(owned)"

    # ------------------------------------------------------------ failed commit
    fresh
    oldDest
    export CASE_COMMIT_FAIL=1
    run clone src dst
    ck "a failed commit refuses" 1 "$rc"
    ckt "  by reason" grep -q 'could not move the copy into place' err
    ck "  after writing the marker first" "marker present" "$(cat "$CASE_LOG")"
    ckt "  then removing the marker this run wrote" test ! -e "$(marker dst)"
    ckt "  and the temporary image" test ! -e "$(tmp dst)"
    ckt "  and the old destination image is intact" grep -qx old "$(img dst)"

    fresh
    oldDest
    earlierMarker
    export CASE_COMMIT_FAIL=1
    run clone src dst
    ck "a failed commit over an earlier clone's marker refuses" 1 "$rc"
    ckt "  and keeps the marker it did not write, unchanged" cmp -s before "$(marker dst)"

    # ----------------------------------------------------------------- identity
    fresh
    run clone src dst --identity
    ck "clone --identity succeeds" 0 "$rc"
    ckt "  and writes no marker" test ! -e "$(marker dst)"
    ck "  not even for the commit" "marker absent" "$(cat "$CASE_LOG")"
    ckt "  and the copy is the source" cmp -s "$(img src)" "$(img dst)"

    fresh
    earlierMarker
    run clone src dst --identity
    ck "clone --identity over an earlier marker succeeds" 0 "$rc"
    ck "  keeping the marker until the commit" "marker present" "$(cat "$CASE_LOG")"
    ckt "  and removing it after, since the identity is kept on purpose" test ! -e "$(marker dst)"

    fresh
    oldDest
    earlierMarker
    export CASE_COMMIT_FAIL=1
    run clone src dst --identity
    ck "clone --identity whose commit fails refuses" 1 "$rc"
    ckt "  and the earlier clone stays marked" cmp -s before "$(marker dst)"

    # ---------------------------------------------------------- shipped render
    #
    # The one line every case above replaces, read from the store path a host
    # would run. Comments are dropped first so a sentence cannot satisfy it.
    code=$(grep -v '^[[:space:]]*#' ${shipped}/bin/capsule-volume-root)
    ckt "the shipped helper drops to microvm:kvm for acts in an image directory" \
      grep -qF 'setpriv --reuid=microvm --regid=kvm --init-groups -- "$@"' <<<"$code"
    ckt "  and its commit goes through the drop" grep -qF 'asImageOwner mv -T' <<<"$code"
    ckt "  and it chowns nothing" test -z "$(grep -wE 'chown' <<<"$code")"

    [ "$fail" = 0 ] || exit 1
    cp "$log" $out
    cat $out
  ''
