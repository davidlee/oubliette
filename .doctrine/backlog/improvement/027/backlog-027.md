# IMP-027: fragmentsCases: negative cases for the unpinned room rules and persistence mechanisms

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

From RV-026 F-5 (SL-009 audit). `fragments-cases.nix` pins the elevation rule
(case 7) and the persistence rules (case 9) by one deliberate break each with a
clean control. These have no such case:

- the door's password-auth, root-login and default-route rules (`roomChecks`);
- the bind's `.mount` in `room-persist.before`, and the bind in `local-fs.target`;
- `room-persist`'s script text (umask, mkdir only when missing);
- an unselected fragment's `guestModule` never being evaluated (case 6 shows
  nothing rendered, not that nothing was forced — a `throw` module would show it).

Live evidence covers the ordering on one boot (SL-009 PHASE-05, ASM-005), not
regression. Each new case: assert the reason, and mutate to watch it go red.
