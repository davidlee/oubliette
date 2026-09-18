Found in SL-001's audit (`RV-008` F-6, `host/record.nix`).

Bash ignores `errexit` for any command run on the left of `||` or `&&`, or as
an `if`/`while` condition, **and for everything that command runs**: function
bodies and `( … )` subshells included. `writeShellApplication`'s `set -e` does
not help. So

```bash
recordWrite() {
  (
    flock 9
    printf '%s' "$cur" | jq "$filter" > "$tmp"   # fails: $tmp is empty
    mv "$tmp" "$dir/assignment.json"             # runs anyway
    printf '%s' "$next"                          # subshell exits 0
  ) 9>"$dir/.lock"
}
recordWrite … || return 1                        # never fires
```

emptied the slot's record and reported success. On the plain verb the call was
not behind `||`, so errexit caught it. Adding the "check" was what broke it.

- **A function meant to be checked must fail on its own**: `cmd || exit 1` (in
  a subshell) or `|| return 1` on every step that can fail. Don't rely on
  errexit.
- Before adding `|| …` to a call, read the callee: *does every failing step
  stop it without errexit?*
- In a sandbox, a corrupt input file (`printf 'not json' > record`) is a free
  way to make a jq writer fail. You do not need a seam.

Sibling: [[mem.fact.oubliette.errexit-skips-a-captured-function]] (command
substitution does not inherit errexit).
