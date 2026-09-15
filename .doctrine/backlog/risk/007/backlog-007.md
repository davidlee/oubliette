# RSK-007: Sparse volume images can outgrow the host filesystem's non-root space

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

Each slot's `capsule-work.img` is a 32 GiB sparse file on `/var/lib/microvms`,
which is this host's ext4 root filesystem. The VMM runs as `microvm`, so an image
grows into the space available to **non-root** writers, not into the 5% root
reserve.

Measured 2026-09-15 (`df -B1`, `stat -f`): 107 GiB available to non-root, about
100 GiB more in the root reserve, and the filesystem reads 94% used. The user
reports that at about 95% it becomes unwritable in practice, which is the reserve
boundary.

Five created slots (`a`..`e`) can each grow by up to about 32 GiB minus what they
already allocate, so their combined headroom can exceed the 107 GiB with no clone
involved. When that happens, every running guest's `/work` and every non-root
host writer gets `ENOSPC` together.

Found while disposing `RV-001` `F-9` (SL-002). That slice bounds only its own
clone, by a declared reserve; it does not address growth of existing images.
`capsule all status`'s `alloc` column and free line (SL-002 sec-6) make the
exposure visible without closing it.
