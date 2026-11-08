# What the model door's condition program decides — SL-010 design sec-4 and
# sec-6, `RV-027` `F-10` and `F-11`.
#
# The third kind of check (CLAUDE.md), over `capsule-model-door-open`, run as
# shipped: `<declared> <override-file>`, exit 0 meaning the door is open. Only
# two things open it: no override file with `on` declared, and an override
# holding exactly `on\n` whatever is declared. Every other byte string closes
# it, and a program that only *looked* for `on` (a line search, a command
# substitution that drops NULs and trailing newlines) would open it for
# `on\noff\n` or `o\0n\n`. So each row is a byte-exact file written with
# `printf`, and the exit status is asserted for both declared values: `cmp`
# says 1 for differing content and 2 when it cannot read the file, and those
# two are different findings.
#
# **What it cannot see:** what systemd does with the status. The unit's
# `ExecCondition=` reading 1 as "skip" and 2 as "failed" is the module's, and
# `hostModuleUnits` is the nearest check to it; this suite pins the program's
# answer and not the use made of it.
#
# The unreadable row needs a uid that cannot read the file. A root build user
# reads anything, so the precondition is asserted and its failure *fails* the
# suite rather than skipping it: a skipped row is a case that passes for the
# wrong reason.
{
  pkgs,
  lib,
  # The program every real call site runs; the store path is the subject.
  program,
}:
pkgs.runCommand "capsule-model-door-open-cases" {} ''
  fail=0
  log=$PWD/log
  : >"$log"
  ck() { # name wanted got
    if [ "$3" = "$2" ]; then echo "ok   $1" >>"$log"
    else echo "FAIL $1: got '$3', wanted '$2'" >>"$log"; fail=1; fi
  }
  prog=${lib.getExe program}
  run() { "$prog" "$1" "$2" >/dev/null 2>&1 && echo 0 || echo $?; }
  mkdir files

  # row <name> <printf format> <exit if declared on> <exit if declared off>
  row() {
    printf "$2" >"files/$1"
    ck "$1, declared on" "$3" "$(run on "files/$1")"
    ck "$1, declared off" "$4" "$(run off "files/$1")"
  }

  ck "no override, declared on" 0 "$(run on files/absent)"
  ck "no override, declared off" 1 "$(run off files/absent)"
  row on-newline      'on\n'      0 0
  row off-newline     'off\n'     1 1
  row other           'yes\n'     1 1
  row no-newline      'on'        1 1
  row on-off          'on\noff\n' 1 1
  row off-on          'off\non\n' 1 1
  row on-blank        'on\n\n'    1 1
  row nul-inside      'o\0n\n'    1 1
  row nul-before-nl   'on\0\n'    1 1
  row nul-leading     '\0on\n'    1 1
  row empty           '''         1 1

  printf 'on\n' >files/unreadable
  chmod 000 files/unreadable
  if [ "$(id -u)" != 0 ] && ! cat -- files/unreadable >/dev/null 2>&1; then
    echo "ok   precondition: this uid cannot read the unreadable override" >>"$log"
    ck "unreadable, declared on" 2 "$(run on files/unreadable)"
    ck "unreadable, declared off" 2 "$(run off files/unreadable)"
  else
    echo "FAIL precondition: this uid can read a mode-000 file (uid $(id -u)); the unreadable row cannot be exercised" >>"$log"
    fail=1
  fi

  cat "$log"
  [ "$fail" = 0 ] || exit 1
  cp "$log" $out
''
