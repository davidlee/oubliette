Found writing vmCases (SL-003 PHASE-01, 412b77f).

- **nixpkgs coreutils is multi-call.** `exec -a "microvm@capsule" sleep 60` sets
  argv[0], and the multi-call binary dispatches on argv[0], so it is no longer
  `sleep`. To stand up a process whose `pgrep -f` name is the VMM's, run
  `exec -a "microvm@<name>" bash -c 'sleep 60; :'`. The trailing `:` keeps bash
  from exec-ing its last command in place, which would replace the named
  process with `sleep` and lose the name.
- **A bare `wait` on a stub VMM hangs the suite on the very bug under test.**
  If the program under test fails to stop the stub, the suite blocks forever
  rather than reporting. Send KILL first, then `wait` the named pid and read its
  status: 143 (TERM) means the program stopped it, and 137 (KILL) means the suite
  had to. `wait -n` must name its pids
  (`mem.fact.oubliette.capsule-host-children-orphan`).
