# What the quarantine's ingestion bound refuses — SL-006 PHASE-01.
#
# The third kind of check (CLAUDE.md) over a *library* rather than a program,
# arranged as `host/profile-cases.nix` is: `host/quarantine.nix` ships shell
# fragments, so what a suite can run is each fragment spliced into the smallest
# `main` that exercises it. The fragments are handed here from the same binding
# `mkfleet.nix` gives every caller, so there is one text and this suite is not a
# second render of it.
#
# **Three subjects.** The bounded fetch (`boundedFetch`: the `ulimit -f`
# ceiling, `transfer.fsckObjects`, `--no-tags`, `--atomic`), the token bound at
# both of its exit statuses (`refuseToken`, `checkToken = refuseToken 1`), and
# the policy lookup (`policyLimits`) over a fixture vocabulary that is no host's,
# since an undeclared name and a policy that may not collect are what a host's
# own declaration exists not to contain.
#
# What a live host reaches only destructively or not at all is every branch
# here: a pack over the ceiling, a malformed object, a tag riding along, and a
# ref lock held in a real quarantine half way through a two-refspec fetch. Each
# of those is a fault offered to a quarantine holding a retained exhibit.
#
# What it **cannot** reach is the transport. The fetch runs over `file://`
# between local bare repositories; the real one is ssh into a guest, and
# `pkgs.openssh` in the channel's `runtimeInputs` cannot be stubbed (CLAUDE.md),
# so a real collect through the fragment is the live rung (RV-015 F-5).
#
# Two rules for a case here, as everywhere: assert the **reason** and not only
# the status, since a refusal for the wrong reason is a different program
# passing; and each bound was watched going red against a mutated copy of the
# fragment (the phase sheet's findings).
{
  pkgs,
  lib,
  # `host/quarantine.nix` as every caller gets it, never a second render.
  quarantine,
}: let
  # `boundedFetch <repo> <maxBytes> <url> <refspec>...`, called the way every
  # caller calls it: behind `||`, which turns errexit off inside the function and
  # its subshell — so a step that fails has to stop the fetch on its own.
  fetchProbe = pkgs.writeShellApplication {
    name = "capsule-quarantine-fetch-probe";
    runtimeInputs = [pkgs.git];
    text = ''
      ${quarantine.boundedFetch}
      boundedFetch "$@" || exit $?
    '';
  };

  # The token bound at both statuses its callers use: 1 for every slot program,
  # 2 for a refusal that is a different kind of answer.
  tokenProbe = pkgs.writeShellApplication {
    name = "capsule-quarantine-token-probe";
    text = ''
      case "$1" in
        check) ${quarantine.checkToken ''"$2"'' "'tok $2'"} ;;
        refuse2) ${quarantine.refuseToken 2 ''"$2"'' "'tok $2'"} ;;
      esac
      echo passed
    '';
  };

  # A declared vocabulary that is no host's (POL-003): one policy that may
  # collect and one that may not, each with its own ceiling so the case can tell
  # them apart.
  policies = {
    everything = ["open" "sealed"];
    policies = {
      open = {
        collectMaxPackBytes = 1024;
        mayCollect = true;
      };
      sealed = {
        collectMaxPackBytes = 2048;
        mayCollect = false;
      };
    };
  };

  policyProbe = pkgs.writeShellApplication {
    name = "capsule-quarantine-policy-probe";
    text = ''
      ${quarantine.policyLimits policies}
      policyLimits "$1" || { echo "undeclared; declared: ${quarantine.policyNames policies}"; exit 3; }
      printf '%s %s\n' "$maxBytes" "$may"
    '';
  };
in
  pkgs.runCommand "capsule-quarantine-cases" {nativeBuildInputs = [pkgs.git];} ''
    export HOME=$PWD
    git config --global user.email c@example.invalid
    git config --global user.name cases
    git config --global init.defaultBranch main

    fail=0
    log=$PWD/log
    : >"$log"
    ck() {
      if [ "$2" = "$3" ]; then echo "ok   $1" >>"$log"
      else echo "FAIL $1: got '$3', wanted '$2'" >&2; sed 's/^/    /' out >&2; fail=1; fi
    }
    saw() {
      if grep -qF -- "$1" out; then echo "ok   ...and says '$1'" >>"$log"
      else echo "FAIL missing reason '$1' in:" >&2; sed 's/^/    /' out >&2; fail=1; fi
    }
    run() { rc=0; "$@" >out 2>&1 || rc=$?; }
    fetch() { run ${lib.getExe fetchProbe} "$@"; }
    # A fetch's exit as a word: git's own failures exit 1, 128 or 253 by kind,
    # and what a case asserts is that it refused, not which code it chose.
    verdict() { if [ "$rc" -ne 0 ]; then echo refused; else echo fetched; fi; }
    # The oid a ref names in a repository, or `absent`.
    oid() { git -C "$1" rev-parse -q --verify "$2" || echo absent; }
    # A fresh landing area each round, so no round inherits another's wreckage
    # (NOTES item 37). `files`, spelled: a held `.lock` means nothing to reftable.
    fresh() { rm -rf dest; git init -q --bare --ref-format=files dest; }

    big=1048576
    url=file://$PWD/src
    to=refs/capsule/x/heads

    git init -q src
    git -C src commit -q --allow-empty -m first
    git -C src branch a
    git -C src branch b
    a=$(git -C src rev-parse a)

    # ------------------------------------------------------------------ control
    fresh
    fetch dest "$big" "$url" "+refs/heads/a:$to/a"
    ck "a fetch under a generous ceiling lands" 0 "$rc"
    ck "  at the source's commit" "$a" "$(oid dest $to/a)"

    # ------------------------------------------------------------------ ceiling
    #
    # Same repository, same refspec, and only the ceiling differs from the round
    # after it — so the control is what makes this round discriminate.
    # Incompressible, so no pack or loose object of it fits under 64 KiB.
    head -c 262144 /dev/urandom >src/noise
    git -C src add noise
    git -C src commit -q -m noise
    git -C src branch -f a
    a=$(git -C src rev-parse a)
    fresh
    fetch dest 65536 "$url" "+refs/heads/a:$to/a"
    ck "a pack over the ceiling is refused" refused "$(verdict)"
    ck "  and nothing lands" absent "$(oid dest $to/a)"
    # SIGXFSZ, from the ulimit: the object writer killed rather than a refusal
    # git chose (git 2.55: "index-pack died of signal 25" — `unpack-objects`
    # without fsck, so the writer's name is not pinned).
    saw "died of signal"
    fresh
    fetch dest "$big" "$url" "+refs/heads/a:$to/a"
    ck "the same pack under a generous ceiling lands" "$a" "$(oid dest $to/a)"

    # A ceiling this process may not set — the hard limit already below it —
    # is a refusal, not an unbounded fetch: an empty commit, which lands under
    # any ceiling that took effect, so only the failed `ulimit` can refuse it.
    fresh
    (ulimit -f 128; fetch dest "$big" "$url" "+refs/heads/b:$to/b"; echo "$rc" >rc)
    rc=$(cat rc)
    ck "a ceiling that cannot be set is refused" 1 "$rc"
    ck "  and nothing lands" absent "$(oid dest $to/b)"
    saw "cannot modify limit"

    # --------------------------------------------------------------------- fsck
    #
    # A tree with a `.git` entry, which `capsule-adopt` relies on fsck to refuse
    # (NOTES item 34).
    blob=$(echo x | git -C src hash-object -w --stdin)
    tree=$(printf '100644 blob %s\t.git\n' "$blob" | git -C src mktree)
    bad=$(git -C src commit-tree -m dotgit "$tree")
    git -C src branch dotgit "$bad"
    fresh
    fetch dest "$big" "$url" "+refs/heads/dotgit:$to/dotgit"
    ck "a tree with a .git entry is refused" refused "$(verdict)"
    ck "  and nothing lands" absent "$(oid dest $to/dotgit)"
    saw "hasDotgit"

    # ---------------------------------------------------------------------- tag
    #
    # Tag auto-following would write refs/tags/* outside the namespace the
    # refspec names — the guest choosing where its refs land.
    git -C src tag -a -m t v1 a
    fresh
    fetch dest "$big" "$url" "+refs/heads/a:$to/a"
    ck "a tagged commit is fetched" 0 "$rc"
    ck "  and lands" "$a" "$(oid dest $to/a)"
    ck "  without its tag" "" "$(git -C dest for-each-ref refs/tags)"

    # ------------------------------------------------------------------- atomic
    #
    # Two refspecs, and the second one's lock held: one refspec failing would not
    # discriminate, since it fails with or without --atomic. What --atomic buys is
    # that the first does not land either (RV-015 F-5).
    fresh
    mkdir -p dest/$to
    : >dest/$to/b.lock
    fetch dest "$big" "$url" "+refs/heads/a:$to/a" "+refs/heads/b:$to/b"
    ck "a fetch with one ref locked is refused" refused "$(verdict)"
    ck "  and the other ref does not land either" absent "$(oid dest $to/a)"
    ck "  nor the locked one" absent "$(oid dest $to/b)"
    saw "b.lock"
    saw "File exists"

    # ------------------------------------------------------------------- tokens
    #
    # One bound, two statuses (RV-015 F-8), and the same reason at both.
    run ${lib.getExe tokenProbe} check ..
    ck "checkToken refuses '..' with 1" 1 "$rc"
    saw "opaque name"
    saw "tok .."
    run ${lib.getExe tokenProbe} refuse2 ..
    ck "refuseToken 2 refuses '..' with 2" 2 "$rc"
    saw "opaque name"
    run ${lib.getExe tokenProbe} refuse2 "a/b"
    ck "refuseToken 2 refuses a slash with 2" 2 "$rc"
    saw "opaque name"
    run ${lib.getExe tokenProbe} check ok
    ck "checkToken passes a token" 0 "$rc"
    saw "passed"
    run ${lib.getExe tokenProbe} refuse2 ok
    ck "refuseToken 2 passes a token" 0 "$rc"
    saw "passed"

    # ----------------------------------------------------------------- policies
    run ${lib.getExe policyProbe} open
    ck "a policy that may collect yields its ceiling" "0 1024 yes" "$rc $(cat out)"
    run ${lib.getExe policyProbe} sealed
    ck "a policy that may not yields its own" "0 2048 no" "$rc $(cat out)"
    run ${lib.getExe policyProbe} nobody
    ck "an undeclared name is not a policy" 3 "$rc"
    saw "declared: open sealed"
    run ${lib.getExe policyProbe} ""
    ck "nor is no name" 3 "$rc"

    [ "$fail" = 0 ] || exit 1
    cp "$log" $out
    cat $out
  ''
