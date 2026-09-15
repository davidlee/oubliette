Observed 2026-09-15 driving `SL-002`'s design run (doctrine at this host's `~/.cargo/bin`).

- **`body`, `resolution` and `dispose` are refused as inert on an `inq-` subject.**
  A disposition is its own declaration: `{"subject":"cp-N","disposes":"inq-N","dispose":{"form":"create","kind":"decision",...}}`,
  then `{"subject":"inq-N","lifecycle":"resolved"}` in the same batch. Resolving
  without the `cp-` refuses with *cannot resolve without a disposition*. A
  `create` disposition mints the record (`DEC-NNN`) in state `proposed`; move it
  with `doctrine knowledge status DEC-NNN accepted`.
- **Children cannot name a parent declared in the same batch** (*unknown node*).
  Declare roots in one submission and children in the next.
- **`agent_declaration` and `checkpoint_act` bump the revision but print no
  event row.** Confirm with the revision number, not the output.
- **Adding an inquiry node invalidates `graph-reviewed`** (`act_invalidated`), so
  the agent redeclares the blocking set and the user re-reviews.
- The payload flag is `--input <file>`, not `--payload-file`.
