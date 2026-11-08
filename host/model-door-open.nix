# The relay's `ExecCondition` (SL-010 design sec-4, `D-1` resolved): may slot
# `<n>`'s model door be open on this activation? It takes `<declared>
# <override-file>`: the declaration as an argument (the unit's own text, so the
# unit carries it) and the override's path, in `modelDoorDir` beside the
# allowlist links — reachable by the unit, not by the record. Exit 0 means open;
# every other status skips the unit.
#
# **Bytes, compared — never searched, never substituted** (`RV-027` `F-10`,
# `F-11`). A static `wants` alone would bring an `off` slot's door back at its
# next VM start, so the answer is read at activation, and what it reads is a
# byte string. A line search (`grep -qx on`) admits `on\noff\n`; a command
# substitution (`[ "$(cat "$2")" = on ]`) drops NUL bytes and trailing
# newlines, admitting `o\0n\n`. `cmp` against the verb's exact `on\n` admits
# neither, and the verb writes only `on\n` or `off\n`, so the strict match
# costs nothing.
#
# **The trailing `exit` is load-bearing.** A pipeline's last command runs in a
# subshell, so `... | cmp -s` cannot itself be the program's answer: without
# the `exit`, a matching override would fall through to the declaration and
# report that instead. With it, `cmp`'s status — 0, 1 or 2 — is the program's.
#
# **Statuses:** 0 open; 1 the override holds any other content, or there is no
# override and the declaration is not `on`; 2 the override cannot be read.
# `ExecCondition` skips the unit on 1-254 (only 255 is a failure), so 2 skips
# too, and every path but 0 closes the door.
{pkgs}:
pkgs.writeShellApplication {
  name = "capsule-model-door-open";
  runtimeInputs = [pkgs.diffutils];
  text = ''
    if [ -e "$2" ]; then
      printf 'on\n' | cmp -s -- - "$2"; exit
    fi
    [ "$1" = on ]
  '';
}
