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

Proposed control: zram in the guest, set in `vm/capsule.nix`. Not in
`target.nix` or the target's `toolsPackage`: it is kernel and systemd
configuration, not a tool, and any target with a large build would want it
(`POL-002`). The shape the host already runs (`~/flakes/modules/nixos/oom.nix`):

```nix
zramSwap = {
  enable = true;
  algorithm = "zstd";
  memoryPercent = 50;
};
boot.kernel.sysctl."vm.swappiness" = 150; # prefer zram over dropping page cache
```

Take only that block from the host module. The rest of it is the desktop's
(earlyoom's browser preferences, the `user-1000` slice, a swapfile), and a
swapfile on the volume would spend disk, which is the binding constraint
(`docs/probes.md`).

Check before relying on it:
- `vm/capsule.nix` locks kernel modules at boot, and `zram` is a module.
  `zramSwap` is believed to list it in `boot.kernelModules`, which loads before
  the lock, as `i8042` does in `vm/common.nix`. Confirm with `swapon --show` in
  a booted guest.
- Compressed pages still count against `sizes.mem`, so zram only helps as far
  as rustc's memory compresses, and it spends vCPU. Probe it: two concurrent
  builds with and without zram, recording peak memory, OOM kills and wall
  clock, with the figures going into `docs/probes.md`.
- It gives nothing back to the host (the VMM keeps every page it has
  touched). The host's own zram can already swap a capsule's cold pages; that
  is the host's policy, in `~/flakes`, not this repo's.
