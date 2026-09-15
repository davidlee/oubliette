Found in SL-002 PHASE-02 (`vm/reset-home.nix`, commit `87e682b`).

`writeShellApplication` sets `errexit`, `nounset` and `pipefail`, but bash does not
carry `errexit` into a command substitution (`inherit_errexit` is off). So in

```bash
agentSessions() {
  local sessions
  sessions=$(loginctl list-sessions --no-legend)   # fails...
  while read -r id _; do ...; done <<<"$sessions"   # ...and this runs on ""
}
working=$(agentSessions | awk '...')
```

a failed `loginctl` left `sessions` empty, the loop succeeded, `pipefail` saw
status 0, and `working` was empty: **"nobody is working"**. The guest reset would
have quiesced the agent and deleted `$HOME` on a failed read.

- **Return the failure explicitly** in any function whose output is captured:
  `sessions=$(loginctl list-sessions --no-legend) || return`. The caller's
  top-level `x=$(...)` then fails and errexit does fire there.
- The dangerous shape is a *listing* whose empty answer means "safe to proceed".
  Ask of every such listing what an error prints.
- A fixture that stubs the whole function (`agentSessions() { cat file; }`) cannot
  see this: the stub's failure is its last command, so it propagates. It took
  running the shipped text, see [[mem.pattern.oubliette.fake-guest-tools-on-path]].
