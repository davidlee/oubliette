`ssh` sends its argv as one string to the remote user's shell. So
`capsule assistant ssh agent -- env -i session repo -- sh -c 'cmd1; cmd2'` reaches the
guest with the inner quoting gone, and everything after the first `;` runs in the
remote login shell — not under `env -i`, not inside `session`. That reads as a
pass: it did once in SL-007 PHASE-05.

Quote the whole payload as one string, escaping what the remote shell must see:

    capsule assistant ssh agent -- "env -i /run/current-system/sw/bin/session doctrine -- sh -c 'echo PATH=\$PATH; command -v git'"
