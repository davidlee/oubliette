# RSK-009: Two concurrent cargo builds exceed a capsule's memory ceiling

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

Seen on capsule c, 2026-09-28, while running doctrine's `SL-269` under a
capsule orchestrator plus worker. The guest's kernel OOM-killed `rustc` twice
(`journalctl -u microvm@c`):

```
00:26 AEST  Killed process (rustc) anon-rss:2891804kB
02:21 AEST  Killed process (rustc) anon-rss:2783252kB
```

The guest sees ~5.9 GiB (`target.nix` `sizes.mem = 6144`). Resident at the
time: three Claude processes (~380 MB each), the tmpfs root, and two cargo
runs at once, the orchestrator's gate and the worker's build. One rustc for
doctrine's largest crate is ~2.8 GB, so two cannot fit. The first kill
probably explains an "unexplained worker interruption" reported earlier the
same night.

The kernel OOM killer worked: the guest did not thrash or wedge. The hang
reported afterwards is `ISS-014`, not this.

Levers, cheapest first:
- the agent's side: one cargo process at a time. That lever belongs to the
  target's workflow, not to this repo. `jobs` (from `sizes.vcpu`) helps
  less, because a single rustc is the large term;
- zram swap in the guest: compressed swap in RAM, no host mount, target
  agnostic, so it would go in `vm/`;
- raise `sizes.mem`: a fleet cost, since the VMM never gives pages back
  (see the comment on `sizes` in `target.nix`, and `docs/probes.md`).
