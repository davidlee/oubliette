# What the two devshell VM verbs do with argv — `ISS-002`.
#
# The third kind of check (CLAUDE.md) over `host/vm-name.nix`, which is a
# *library*: what a suite can run is the fragment spliced into something with a
# `main`, and here the two shipped programs already are that. So both subjects
# are the store paths the devshell hands a human, never a second render — which
# is also what makes this suite fail if only one of them is rewired.
#
# The one thing tying `vm` to this host is its last line, `exec nix run`, and it
# is reached by exactly one case below. Everything else is a refusal that lands
# before it, which is the point: the fix is the ordering, not the messages.
# `vm-stop`'s tie is a running VMM, so nothing here goes past its argv.
#
# Both rules for writing a case apply. The reason is asserted and not only the
# status — `vm --help` exiting 0 while making `.vm/--help/` is the bug itself, so
# every refusal also asserts that no state was invented. And each was watched
# going red against the programs as they shipped before this: `--help` created
# the directory, `--nope` created one too, and `vm a b` ran the first argument.
{
  pkgs,
  # `vm` and `vm-stop` as the devshell installs them.
  vm,
  vm-stop,
}:
pkgs.runCommand "capsule-vm-cases" {} ''
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

  # A root of this suite's own, so `.vm/` is a thing that either appeared or did
  # not. `vm` reads `CAPSULE_ROOT` before `$PWD`, which is the same knob a human
  # running a capsule out of a checkout uses.
  export CAPSULE_ROOT=$PWD/root
  mkdir -p "$CAPSULE_ROOT"

  # `nix` is not in `vm`'s `runtimeInputs` — it is the host's, resolved from
  # PATH — so a stub is what lets the non-refusing cases run to their last line
  # and say where they stood and what they asked for. A build that succeeds does
  # what `--out-link booted` does: it points `booted` at a runner. That runner is
  # a stub too, and says it ran and from where, which is what `vm` execs.
  # `NIX_FAIL` makes the build fail without touching the link, as nix does.
  mkdir -p stub runner/bin
  {
    echo '#!/bin/sh'
    echo 'echo "cwd $PWD" >"$NIX_LOG"'
    echo 'echo "argv $*" >>"$NIX_LOG"'
    echo '[ -z "''${NIX_FAIL:-}" ] || exit 1'
    echo 'ln -sfn "$RUNNER" booted'
  } >stub/nix
  {
    echo '#!/bin/sh'
    echo 'echo "ran from $PWD" >"$RUN_LOG"'
  } >runner/bin/microvm-run
  chmod +x stub/nix runner/bin/microvm-run
  export PATH=$PWD/stub:$PATH NIX_LOG=$PWD/nixlog RUNNER=$PWD/runner RUN_LOG=$PWD/runlog

  # A VMM as the process table sees one: every capsule image is hostName
  # `capsule` (DEC-020), so its runner is `microvm@capsule` whatever slot it
  # serves. The sandbox has its own netns, and this process is in it, so
  # `own_vms` finds it with nothing stubbed — which is the point of the case:
  # the lookup is the shipped one.
  #
  # bash rather than `sleep`, because coreutils' `sleep` is a multi-call binary
  # that dispatches on argv[0] and refuses one it does not know; the trailing
  # `:` stops bash exec'ing the sleep in its own place and losing the name.
  vmm_up() { (exec -a microvm@capsule bash -c 'sleep 300; :') & vmm=$!; }

  # Whether the run left anything behind. `.vm/` and not `.vm/<name>`: the bug
  # made a directory named after the argument, and a suite that looked for one
  # name would pass for the next mistake.
  litter() { [ -e "$CAPSULE_ROOT/.vm" ] && echo yes || echo no; }

  # ------------------------------------------------------ asking for the usage
  #
  # `ISS-002` as found: the exit status was already 0 and the state directory was
  # already there.
  rc=0; ${vm}/bin/vm --help >out 2>err || rc=$?
  ck "vm --help is a question, not a name" 0 "$rc"
  ckt "  answered on stdout" grep -q '^usage: vm <name>' out
  ck "  and nothing was created" no "$(litter)"

  rc=0; ${vm}/bin/vm -h >out 2>err || rc=$?
  ck "the short form is the same question" 0 "$rc"
  ckt "  with the same answer" grep -q '^usage: vm <name>' out
  ck "  and nothing was created" no "$(litter)"

  # ----------------------------------------------------------- no name at all
  #
  # Unchanged behaviour, pinned because it is the one refusal that predates the
  # fix and the usage now comes from a fragment that could drop it.
  rc=0; ${vm}/bin/vm >out 2>err || rc=$?
  ck "vm with no name still refuses" 1 "$rc"
  ckt "  on stderr, since it is an error" grep -q '^usage: vm <name>' err
  ck "  and nothing was created" no "$(litter)"

  # -------------------------------------------------------- an option, not a name
  rc=0; ${vm}/bin/vm --nope >out 2>err || rc=$?
  ck "an unknown option is refused" 2 "$rc"
  ckt "  naming the option and not the flake" grep -q 'vm: not an option: --nope' err
  ck "  and nothing was created" no "$(litter)"

  # ------------------------------------------------------------ more than one
  #
  # Silently running the first argument is how `vm capsule --foo` becomes a VM
  # boot nobody asked for.
  rc=0; ${vm}/bin/vm capsule hello >out 2>err || rc=$?
  ck "two arguments are refused" 2 "$rc"
  ckt "  saying how many arrived" grep -q 'one name, and this is 2 arguments' err
  ck "  and nothing was created" no "$(litter)"
  ck "  and nix was never asked" no "$([ -e $NIX_LOG ] && echo yes || echo no)"

  # ----------------------------------------------------- a name that is a path
  #
  # `.vm/$name` is a path built from the argument, so a name carrying a
  # separator writes outside the state directory.
  rc=0; ${vm}/bin/vm ../elsewhere >out 2>err || rc=$?
  ck "a name that is a path is refused" 2 "$rc"
  ckt "  as a name and not as a missing attribute" grep -q 'vm: not a VM name: ' err
  ck "  and nothing was created" no "$(litter)"
  ckt "  least of all above the root" test ! -e "$CAPSULE_ROOT/../elsewhere"

  # ------------------------------------------- a capsule already running here
  #
  # Every devshell capsule is `net.guest` on a tap in the root namespace, so one
  # runs at a time, and a second start fails at the tap — *after* a build would
  # already have repointed `booted` at an image that is not the one running
  # (DEC-024, RV-010 F-2). So the refusal comes before the build, and before any
  # state is made.
  vmm_up
  rc=0; ${vm}/bin/vm c >out 2>err || rc=$?
  ck "a start while a capsule VMM runs here is refused" 1 "$rc"
  ckt "  saying why" grep -q 'a capsule is already running in this namespace' err
  ck "  and nix was never asked" no "$([ -e $NIX_LOG ] && echo yes || echo no)"
  ck "  and nothing was created" no "$(litter)"
  kill "$vmm" 2>/dev/null || true; wait "$vmm" 2>/dev/null || true

  # ------------------------------------------------------------- a real name
  #
  # A slot letter rather than `capsule`, so what the build asks nix for is the
  # argument and not a default that happens to match. It builds into a link
  # called `booted` beside the volume, and runs *through* that link — so the
  # link names the image that is running, which is what the front end reads.
  rc=0; ${vm}/bin/vm c >out 2>err || rc=$?
  ck "a declared name runs" 0 "$rc"
  ckt "  under its own state directory" test -d "$CAPSULE_ROOT/.vm/c"
  ckt "  which is where the build stood" grep -qx "cwd $CAPSULE_ROOT/.vm/c" "$NIX_LOG"
  ckt "  and the attribute is the name it was given, built to booted" \
    grep -qx "argv build --out-link booted $CAPSULE_ROOT#c" "$NIX_LOG"
  ckt "  and the runner run is the one booted names" \
    grep -qx "ran from $CAPSULE_ROOT/.vm/c" "$RUN_LOG"
  ck "  and booted names the runner the build produced" "$RUNNER" \
    "$(readlink "$CAPSULE_ROOT/.vm/c/booted")"
  ckt "  whose booted/bin/microvm-run is what the front end will read" \
    test -x "$CAPSULE_ROOT/.vm/c/booted/bin/microvm-run"

  # --------------------------------------------------- a build that fails
  #
  # The link names the last image that booted here until a build replaces it,
  # and a failed build replaces nothing: no runner is started, and what the
  # link said, it still says.
  mkdir -p other/bin
  ln -sfn "$PWD/other" "$CAPSULE_ROOT/.vm/c/booted"
  rm -f "$RUN_LOG"
  rc=0; NIX_FAIL=1 ${vm}/bin/vm c >out 2>err || rc=$?
  ckt "a failed build fails the start" test "$rc" -ne 0
  ck "  and leaves the link as it was" "$PWD/other" "$(readlink "$CAPSULE_ROOT/.vm/c/booted")"
  ck "  and runs nothing" no "$([ -e "$RUN_LOG" ] && echo yes || echo no)"

  # ------------------------------------------------- the other consumer
  #
  # `vm-stop` never made a directory, so its half of `ISS-002` was only ever the
  # wrong answer to a right question: `--help` went looking for a VMM. Nothing
  # here gets past argv, which is the whole of what the fragment owns.
  rc=0; ${vm-stop}/bin/vm-stop --help >out 2>err || rc=$?
  ck "vm-stop --help is a question too" 0 "$rc"
  ckt "  naming itself, not its sibling" grep -q '^usage: vm-stop <name>' out

  rc=0; ${vm-stop}/bin/vm-stop >out 2>err || rc=$?
  ck "vm-stop with no name refuses" 1 "$rc"
  ckt "  on stderr" grep -q '^usage: vm-stop <name>' err

  rc=0; ${vm-stop}/bin/vm-stop --nope >out 2>err || rc=$?
  ck "vm-stop refuses an option" 2 "$rc"
  ckt "  by its own name" grep -q 'vm-stop: not an option: --nope' err

  # ----------------------------------------------- a slot that is not `c`
  #
  # ISS-016: `own_vms` grepped `microvm@$name`, and the process is
  # `microvm@capsule` whatever the slot — so it matched `c` by the accident of a
  # prefix and nothing else. `vm-stop b` then reported "down" over a running VMM
  # and never reaped it. The guest is not reachable from a sandbox, so the halt
  # fails and this goes straight to the VMM, which is the half under test.
  vmm_up
  rc=0; ${vm-stop}/bin/vm-stop b >out 2>err || rc=$?
  ck "vm-stop b finds the capsule VMM in this namespace (ISS-016)" 0 "$rc"
  ckt "  and terminates it" grep -q 'terminating the VMM' out
  # Whatever vm-stop did, KILL it now and read the status: 143 is vm-stop's
  # TERM, 137 is this KILL, which is what a VMM nobody reaped dies of. Never a
  # bare `wait`, which would hang the suite on exactly the bug.
  kill -KILL "$vmm" 2>/dev/null || true
  vrc=0; wait "$vmm" 2>/dev/null || vrc=$?
  ck "  which died of the TERM it sent" 143 "$vrc"

  [ "$fail" = 0 ] || exit 1
  cp "$log" $out
  cat $out
''
