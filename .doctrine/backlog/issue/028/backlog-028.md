# ISS-028: Two suites mkFleet ships to consumers assume the fixture's names

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

`mkFleet` hands `fragmentsCases` and `profileCases` the caller's declarations, and
the shared `just build` runs both on every consumer. Both held only for the
fixture, so a consumer's gate went red while oubliette's stayed green.

- `fragmentsCases` read the rooms `lounge` and `assistant` by name. `/srv/fleet`
  declares only `assistant`, so eval stopped at `attribute 'lounge' missing`
  (`fragments-cases.nix:190`). A consumer with `rooms = {}` stopped at `assistant`.
- `profileCases` compared target names in name order with a glob in filename
  order. `goad` sorts before `goad-walk`, but `goad-walk.json` sorts before
  `goad.json` (`-` is below `.`). The first failure hid this one.

Fix: a case picks its room by what the room selects, and logs `skip` where none
fits. `profileCases` sorts the expected names as filenames.

Regression: `templateCases` forces `fragmentsCases` over the template's `rooms = {}`,
and the fixture target `tooled` is now `fixture-tooled`, a pair with the same
sort shape. Both were watched going red before the fix.

Not covered: `skip` means a consumer without a `postgresql-18` room runs no
postgresql cases. Oubliette's fixture still runs them all.
