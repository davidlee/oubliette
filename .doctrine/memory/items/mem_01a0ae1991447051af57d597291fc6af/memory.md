`capsule <slot> baseline` ends attached, and Ctrl-C leaves the run going in the
guest. What it leaves is **two** `agent` sessions:

| session | State | scope contents |
| --- | --- | --- |
| the run | **closing** | `run.sh` → the target's build command → e.g. `cargo test` |
| the log tail | **active** | `tail -n +1 -f --pid=<run>` over a *second* ssh |

The run's sshd logs `Received disconnect … disconnected by user` and the scope
survives it, because NixOS leaves `KillUserProcesses` off. That is the mechanism
`ASM-001` bet on, and it holds.

**The tail is the surprise.** It is a separate login, it stays `active` rather
than `closing` after its host-side client dies, and it outlives the disconnect
because `tail -f` blocks without writing, so the remote end never notices. Any
idle check therefore sees two sessions after an interrupted baseline, and a
refusal lists both.

Related: [[mem.fact.oubliette.a-closing-session-lives-as-long-as-its-work]].
