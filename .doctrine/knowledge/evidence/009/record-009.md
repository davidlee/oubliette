# EVD-009: Disk is tighter than it was, and status now reads the same number

<!-- Knowledge record body — context, detail, links. The structured, queried
     fields live in the sister `record-NNN.toml`; this prose is free-form and is
     never structurally parsed (the storage rule). -->

Re-take of `EVD-005` (`SL-002` PHASE-05 `EX-3`). `docs/probes.md`'s *Figures*
row is the source, and this record cites it rather than copying it.

Host disk under `/var/lib`: **92 GiB available of 1.78 TiB, 95% used**
(`df /var/lib`, 2026-09-17), down from 166 GiB / 91% on 2026-08-13. Same disk,
same filesystem: `/dev/nvme0n1p2`, **ext4 — so still no reflink**, and a cloned
volume is still a real copy of the source's *allocated* blocks, its high-water
mark rather than its current usage.

**What changed besides the number.** The figure was hand-measured and lived only
here; `capsule status` now prints it. `DEC-009`'s `volumes:` line reads the same
`df` `avail` the clone's fit check reads, beside a per-slot `alloc` that is that
slot's high-water mark — so what a clone of a given slot would cost, and whether
it fits, are both on one screen. Read on 2026-09-17:

    volumes: 92G free on /var/lib/microvms, 20G of it kept back from clones (2 outside the pool: capsule, capsule-b)

with `a` 3.3G, `d` 6.8G and `e` 1.6G — **all three stopped**, which is the
column's point: every other measured cell on a stopped slot's row is `-`.

**The margin is the finding.** 92 GiB free less `capsules.volumeReserve`'s 20
GiB leaves ~72 GiB a clone may spend, and the largest slot is 6.8 GiB. So
cloning is not near the limit today, but the disk lost 74 GiB in five weeks and
this row is what bounds the number of capsules. Growth of images already here is
`RSK-007`, and it is the term this row does not price.

The parenthesis also made `CHR-013` visible without anyone listing the
directory: `capsule` and `capsule-b`, two pre-slot state directories that are
not declared slots.

Supersedes [[EVD-005]]. Bears on `QUE-004`, and on `IMP-001` — clone semantics
are where the no-reflink fact becomes a design constraint rather than a number.
