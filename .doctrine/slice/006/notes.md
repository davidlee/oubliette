# Notes SL-006: Assistant room over many repos: clones, tools and a per-repo git channel

Durable per-slice scratchpad — tracked in git. The place to lift anything from a
disposable phase sheet (`.doctrine/state/.../phase-NN.md`) that must survive
`rm -rf` before the slice close-out audit harvests it.

## Harvest
<!-- single-copy: updated in place each harvest; ids only, never restated content -->
fresh-as-of: 2026-10-18 · design locked, lifecycle plan · HEAD (this commit)

### Produced
- DEC-043..DEC-051 (DEC-051 supersedes DEC-041); IDE-003 (model door, split out)
- design.md (11 sections, locked); RV-015 (waived, no findings)

### Learned
- friction: `doctrine design apply` processes a batch's declarations in
  lexical subject order (inq-1, inq-10, inq-11, … inq-2), so a `needs` or
  `adopt` pointing at a later-sorting subject in the same batch is refused as
  "unknown node". Declare nodes first, edges in a second submission.

### Open
- DEC-044 provisional by the user's word (no fleet extras in a room)
- ISS-021, RSK-011: close at implementation, by DEC-043 and DEC-047
- POL-003 rooms-row REV: needs the user's assent in the phase that moves it
- sequencing: implement after SL-005 PHASE-10 commits; live after SL-005 PHASE-09
- relay sec-6 to satan SL-023 (user's act), now that the design is locked

## Design review passes (2026-10-18)

What has reviewed this design, and what has not:

- **GPT (gpt-6-sol), informal, on the decision tree** before drafting. Five
  findings, all accepted: run-time `--room`/`--profile` instead of a baked
  repo table (POL-002), one `known_hosts` shared with satan's runner, a banner
  pre-flight so a trust failure is not "room down", satan's `/work/repos/<t>`
  path, and pi-env's custom `Connection` contract. Folded into DEC-045,
  DEC-047, DEC-050 and sec-6. It reviewed the decisions, not `design.md`.
- **satan SL-023's agent, on sec-6** as its consumer. Two corrections folded
  (commit 94cf91d): `guest_path` is checked in `preparing`, not at startup;
  the clone starts unborn and the clean-tree check is the runner's.
- **RV-015, GPT (gpt-6-sol) document-level pass** (user-requested before
  /plan). Seven findings plus one found adjudicating (F-8), all verified and
  fixed in the design: generic `session` over an `/etc/room/repo` tree (F-1, the
  user's choice — amends DEC-049); branch validation and push resolution before
  the pre-flight (F-2); the program wrapped on the module path (F-3); DEC-045's
  stale `viaSocket` (F-4); `quarantineCases` for the extracted fetch plus a slot
  collect on the live rung (F-5); repo-name grammar at eval (F-6); three
  `rooms.nix` fixture callers (F-7); `checkToken`'s exit status (F-8). The run
  was regressed locked → reviewing and the edit adopted, which invalidated the
  acceptance act: it relocks on the user's re-acceptance.
- **satan's two questions** (via the user): the room needs no guest address in
  satan's config (ProxyCommand + HostKeyAlias; `net.guest` is the relay's), and
  `session` is at `/run/current-system/sw/bin/session` — sec-6.

Superseded by RV-015 (the fetch extraction is now `quarantineCases` plus a live slot collect; `session` holds no repo table). Kept as written before it — what a further pass would probe, if one were wanted: whether sec-4's
extraction of the policy and fetch fragments changes `capsule-collect`'s
behaviour (its suites should be enough); whether `accept-new` over the room
socket is ever reachable by anything but this host's VM (DEC-047's premise);
whether `session`'s repo table, rendered into a per-room image, leaks a target
name into generic code (POL-002 — it should not: values only); and whether
the satan-facing exit-75 contract survives a relay that is up while the guest
sshd is not. None is judged to need a pass before planning: each is either a
case in sec-8 or a live-rung check.
