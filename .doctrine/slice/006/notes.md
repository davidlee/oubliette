# Notes SL-006: Assistant room over many repos: clones, tools and a per-repo git channel

Durable per-slice scratchpad — tracked in git. The place to lift anything from a
disposable phase sheet (`.doctrine/state/.../phase-NN.md`) that must survive
`rm -rf` before the slice close-out audit harvests it.

## Harvest
<!-- single-copy: updated in place each harvest; ids only, never restated content -->
fresh-as-of: 2026-10-19 · implementation complete (PHASE-07), before audit · 4c1d210

### Produced
- PHASE-01..07 done (commits 6f103c7..4c1d210 on 3a52d2e); `doctrine check gate` rc 0 at 4c1d210
- PHASE-01 quarantine fragments + `quarantineCases`; PHASE-02 room fields in `rooms.nix` + REV-007 (POL-003 rooms row); PHASE-03 `/work`, clones, `session`; PHASE-04 `capsule-room-git` + `roomGitCases`; PHASE-05 front end's room push/collect/forget-host-key; PHASE-06 docs, template, contracts, Plan F; PHASE-07 live rung (consumer `/srv/fleet` 7f63d55 on oubliette cc72b97)
- EVD-010 + docs/probes.md *Two repos in one room…* — the live rung's record and figures
- ISS-021 — answered by DEC-043; RSK-011 — answered by DEC-047 (live evidence in 8fb6db7)
- ISS-024 — raised live, fix in 4c1d210 (tmpfiles parent rules + `unparented` check); the live host takes it at the user's next rebuild
- minted: ISS-023 — the slot channel's profile reader leans on an ambient jq; IMP-017 — `session`'s git rides an unpromised system PATH; IMP-018 — `just up`/`refresh-build` cannot serve a room; CHR-018 — the assistant room takes the rest of the user's repos; ISS-025 — slot `pkgs.git` vs the target tool set's git collide silently (`ignoreCollisions`); rooms unaffected
- for reconcile (phase sheets' Findings): departures from design — banner check is a prefix match, not D9's exact; `--` ends `capsule-room-git`'s options (D1); banner branches are suite-reachable, against sec-8/DEC-050's "live-only"; `profileLoad` behind `refuseToken 2`, not `select`; `push` added via a `roomVerbs` list, so the verb-collision throw does not cover a room named `push`; `boundedFetch` adds `|| exit 1` after `ulimit` (slot tightening)
- for reconcile: stale prose — DEC-040's title ("pinned and not built"); docs/contract-target.md:19-25
- for reconcile: PHASE-07 was never flipped in_progress, so no code-start boundary is recorded; PHASE-02's range was tightened by `record-delta`
- `.doctrine` changes committed with each piece; this harvest commits ISS-025 and one memory separately

### Learned
- mem.fact.oubliette.tmpfiles-needs-every-parent-declared — an undeclared parent is made root:root, refused, and a switch reports success
- EVD-010 — what two tool sets cost a room, against the repo-less room (figures in docs/probes.md)
- friction observations (24253c4, 9c45d55): named-orchestrator children hand back to the seat; a sweep commit reset a phase's index; `just` hides a cached suite's output; a phase sheet's line refs predated the file
- friction: `doctrine design apply` processes a batch in lexical subject order, so declare nodes before edges

### Open
- DEC-044 — held provisional by the user's word (no fleet extras in a room)
- ISS-023, ISS-025, IMP-017, IMP-018, CHR-018 — follow-up work, outside this slice
- satan SL-023 relay — the user's act; relay text delivered in session, satan side not done
- live rung not exercised: wrong-repo collect, socket-present-no-banner 75 (suite only), auth failure, oversize pack, a build through `session`

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
