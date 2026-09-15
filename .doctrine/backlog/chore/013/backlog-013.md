# CHR-013: Remove the pre-slot capsule and capsule-b state directories

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

Found during `SL-002`'s exploration (2026-09-15). `/var/lib/microvms/` still holds
`capsule/` and `capsule-b/` next to the declared slots `a`–`e`. Both are dated
2026-08-13, before slots had letter names, and each has a `current` symlink, a
`flake` file and a `capsule-work.img` with **1.6 GiB allocated** (`du`,
2026-09-15).

**Why it is worth doing:**
- **Disk.** 3.2 GiB on the filesystem that bounds the fleet (`docs/probes.md`,
  the disk row).
- **A gcroot each.** `current` keeps an old runner closure alive.
- **`capsule` is `RSK-005`'s name.** A state directory named after the guest
  image rather than a slot is exactly what `microvm -c capsule` would create,
  with no perimeter. Its presence makes a real instance of that risk harder to
  notice.

**Before removing:** check that no unit references them
(`systemctl list-units 'microvm@capsule*'`), and that `pgrep -af microvm` shows
nothing holding either image. Then `sudo rm -rf` both directories. That is the
operator's call, and it is root.

**Not in `SL-002`:** `volume` refuses both, because neither is a declared slot
(`DEC-008`), so the new commands cannot clean these up.
