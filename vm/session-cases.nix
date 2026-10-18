# What `session` decides: SL-006 design sec-3.
#
# The third kind of check (CLAUDE.md), over the room's one per-repo launcher,
# and the second whose subject ships in the *guest*. Every branch here is one a
# live room reaches only with a booted guest whose `/etc/room/repo` tree exists,
# so the suite is where they get exercised at all.
#
# **Handed a fixture tree, and it renders its own subject on purpose**, as
# `vm/reset-home-cases.nix` does. The program's `root` is a build-time value,
# fixed at `/etc/room/repo` by the construction a room ships, so the shipped
# store path can only ever look there, and a render against a store-path tree is
# the only way to run its text past a refusal. The render differs from the
# shipped one in `root` alone. The shipped store path runs too, for the cases
# that refuse before it reads the tree: `/etc/room/repo` does not exist in a
# build sandbox (a premise below), so it cannot reach anything real.
#
# The tree holds two made-up repos, so no target is named here (POL-002): `kit`,
# with a clone and a tool set, and `bare`, with a clone and none. Each clone is a
# symlink to a real directory, so a working directory that is the logical path
# rather than the physical one is caught.
#
# **And it finds the shipped program in an evaluated room's image**, by name in
# its `systemPackages`, and asserts it is the same store path as `shipped`: one
# construction, on the guest's `PATH`.
#
# Both rules for writing a case apply: each refusal asserts its reason as well as
# its status, and each case starts from `fresh`.
{
  pkgs,
  lib,
  # The unapplied vm/session.nix, rendered here against the fixture tree.
  session,
  # The one construction every room with repos ships (mkfleet.nix), at its default root.
  shipped,
  # The evaluated `config` of a room with repos, or `null` when the caller
  # declares none, in which case the image block says it was skipped.
  image,
}: let
  # A tool set: one marker binary, found only through `tools/bin`.
  kitTools = pkgs.writeShellScriptBin "kit-marker" "echo kit-marker";

  # Writes where it ran and the `PATH` it was handed to the file the case names,
  # so no case depends on `session`'s own stdout.
  printer = pkgs.writeShellScript "session-printer" ''
    printf '%s\n' "$PWD" "$(pwd -P)" "$PATH" >"$SESSION_REPORT"
  '';

  tree = pkgs.runCommand "session-cases-tree" {} ''
    mkdir -p $out/real/kit $out/real/bare $out/kit $out/bare
    ln -s $out/real/kit $out/kit/clone
    ln -s ${kitTools} $out/kit/tools
    ln -s $out/real/bare $out/bare/clone
  '';

  fixture = session {
    inherit pkgs;
    root = "${tree}";
  };

  # The program an evaluated room ships, found by name and never rebuilt here.
  inImage =
    if image == null
    then null
    else
      lib.findFirst (p: lib.getName p == "session")
      (throw "sessionCases: session is not in the evaluated room's environment.systemPackages")
      image.environment.systemPackages;
in
  pkgs.runCommand "capsule-session-cases" {} ''
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

    tree=${tree}
    fx=${fixture}/bin/session
    sh=${shipped}/bin/session
    export SESSION_REPORT=$PWD/report

    fresh() { rm -f out err "$SESSION_REPORT"; }
    # Invoke, capture both streams, keep the status.
    run() { fresh; rc=0; "$@" >out 2>err || rc=$?; }
    line() { sed -n "$1p" "$SESSION_REPORT"; }
    # refuses <label> <reason (ERE)> <program> <args...>
    refuses() {
      local label=$1 reason=$2
      shift 2
      run "$@"
      ck "$label exits 2" 2 "$rc"
      ckt "  by reason" grep -qE -- "$reason" err
      ckt "  printing nothing to stdout" test ! -s out
    }
    grammar='is not a repo name'
    usage='^usage: session <repo> -- <argv'

    # ------------------------------------------------------------------ premises
    ckt "premise: no /etc/room/repo in the sandbox, so the shipped copy can only refuse" \
      test ! -e /etc/room/repo
    ckt "premise: the marker is not on the caller's PATH" test -z "$(command -v kit-marker || true)"

    # --------------------------------------------------------------------- usage
    for prog in "$fx" "$sh"; do
      which=fixture
      [ "$prog" = "$fx" ] || which=shipped
      refuses "$which: a repo with no -- before the command" "$usage" "$prog" kit true
      refuses "$which: a repo and nothing else" "$usage" "$prog" kit
      refuses "$which: no arguments" "$usage" "$prog"
      refuses "$which: a -- with nothing after it" "$usage" "$prog" kit --
      refuses "$which: a word where the -- belongs" "$usage" "$prog" kit x -- true
      refuses "$which: a repo with a slash" "$grammar" "$prog" a/b -- true
      refuses "$which: ." "$grammar" "$prog" . -- true
      refuses "$which: .." "$grammar" "$prog" .. -- true
      refuses "$which: an empty repo" "$grammar" "$prog" "" -- true
      refuses "$which: a repo with a space" "$grammar" "$prog" "a b" -- true
      refuses "$which: a repo that is not in the tree" 'no such repo' "$prog" nope -- true
    done
    refuses "shipped: a repo only the fixture tree has" 'no such repo' "$sh" kit -- true

    # ----------------------------------------------------------------------- run
    run "$fx" kit -- ${printer}
    ck "a repo with a set runs the command" 0 "$rc"
    ck "  in the clone's physical path" "$tree/real/kit" "$(line 2)"
    ck "  which is \$PWD as well as pwd -P (cd -P)" "$tree/real/kit" "$(line 1)"
    ck "  with tools/bin ahead of the caller's PATH, and nothing else added" \
      "$tree/kit/tools/bin:$PATH" "$(line 3)"

    run "$fx" kit -- kit-marker
    ck "a tool in the set is found by bare name" kit-marker "$(cat out)"

    run "$fx" bare -- ${printer}
    ck "a repo with no set runs the command" 0 "$rc"
    ck "  in its clone's physical path" "$tree/real/bare" "$(line 2)"
    ck "  as \$PWD too" "$tree/real/bare" "$(line 1)"
    ck "  with the caller's PATH exactly" "$PATH" "$(line 3)"

    run "$fx" kit -- printf '%s\n' 'a b' -x --
    ck "argv passes untouched: a space, a leading -, and a second --" \
      "$(printf '%s\n' 'a b' -x --)" "$(cat out)"

    run "$fx" kit -- true
    ck "a command that succeeds exits 0" 0 "$rc"
    ckt "  and session prints nothing of its own" test ! -s out -a ! -s err
    run "$fx" kit -- false
    ck "a command's status is session's (exec)" 1 "$rc"

    # --------------------------------------------------------------------- image
    ${
      if inImage == null
      then ''
        echo "skip   no declared room has repos, so no image is checked" >>"$log"
      ''
      else ''
        ck "the image ships the one construction on its PATH" ${shipped} ${inImage}
      ''
    }

    [ "$fail" = 0 ] || exit 1
    cp "$log" $out
    cat $out
  ''
