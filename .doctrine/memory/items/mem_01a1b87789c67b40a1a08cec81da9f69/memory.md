A program that decides something from a file's content (systemd `ExecCondition`, a guard, a gate) must treat any content but the exact expected bytes as "no". Three shell idioms each let a malformed file through:

- `grep -qx on file` succeeds if **any** line is `on` — `on\noff\n` passes (RV-027 F-10).
- `[ "$(cat file)" = on ]` — command substitution drops NUL bytes and strips trailing newlines, so `o\0n\n` and `on\n\n` pass (RV-027 F-11).
- `printf 'on\n' | exec cmp -s -- - file` inside an `if` — the pipeline's last command runs in a subshell, so `exec` does not end the script and control falls through to whatever follows (found while testing the F-11 repair).

What works: `printf 'on\n' | cmp -s -- - "$f"; exit` — byte comparison, explicit exit. `cmp` exits 1 on difference and 2 on an unreadable file; both are a skip for `ExecCondition` (only 255 fails the unit).

Test it with the malformed rows, not only a plain wrong token: an invalid-token fixture alone passes with the grep bug. Design: SL-010 sec-4, sec-6 `modelDoorOpenCases`.

Related: a plain `mv tmp target` where `target` is a directory exits 0 and moves the file *into* it; `mv -T` refuses. SL-010 PHASE-04 uses `-T` in `recordWrite`.
