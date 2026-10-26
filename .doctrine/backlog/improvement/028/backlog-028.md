# IMP-028: A start whose door probe fails says why only by waiting a minute

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

## Observed (2026-10-26)

After a host switch that removed nushell, `capsule assistant start` sat for a
minute with no output, and `capsule assistant ssh satan` failed with:

```
/run/current-system/sw/bin/nu: No such file or directory
Connection closed by UNKNOWN port 65535
```

The guest was healthy: it booted, its sshd ran, and the door socket returned an
`SSH-2.0-OpenSSH_10.6` banner. The cause was on the host. ssh runs
`ProxyCommand` through `$SHELL -c`, every door is a `ProxyCommand`
(`socat - UNIX-CONNECT:<socket>`), and the caller's terminal still carried
`SHELL=/run/current-system/sw/bin/nu`. Reproduced by running the probe argv
under that `SHELL` (rc 255, same message); it exits 0 in 0.2 s under a valid
`SHELL`.

## Gap

`answers()` in `host/cli.nix` runs the probe with `>/dev/null 2>&1`, and
`waitAnswers` retries it every second for 60 s. A probe that fails *fast and
for a host-side reason* is reported only as "the guest did not answer ssh within
a minute", followed by the unit's tail. That tail is the guest's boot, which
here was clean. The message that names the cause goes to `/dev/null`.

This applies to slots and rooms alike, wherever `waitAnswers` is used.

## Proposal

Keep the last failed attempt's stderr and print it with the timeout refusal.
Asserting *why* it failed, and not only that it did, is the case-suite rule
(CLAUDE.md, "assert the reason"). A `roomVerbsCases` case could cover it with a
door whose ProxyCommand fails, for example under an unrunnable `SHELL`.

Not chosen here: pinning `SHELL` inside the front end for its ssh calls. That
would close this one cause but leave every other fast failure (a missing key,
a refused auth) just as silent.
