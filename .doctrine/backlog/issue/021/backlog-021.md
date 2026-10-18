# ISS-021: DEC-040 puts a room's clone at guestPath, which is off the room's volume

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

`DEC-040` pins a room's guest clone at "the target's `guestPath`". `guestPath`
is `${volumePath}/<name>` (`targets/default.nix:26`), i.e. under `/work`. A
room has one volume, `room-home.img` at `/home` (SL-005 design sec-5), so a
clone at `guestPath` sits on the root filesystem and is lost on every stop,
which `DEC-031` makes routine.

Found reading satan's SL-023 against SL-005 during SL-005 planning. satan's
design assumes a third path (`/work/repos/satan`, satan SL-023 design.md:518).

Nothing in SL-005 builds a clone, so nothing breaks now. The follow-on room
git-channel slice must settle where a room's clones live — a second volume at
`/work`, or a room-relative clone path — and amend `DEC-040` through a
superseding record.

**Fixed (2026-10-19, SL-006 PHASE-07), by `DEC-043`.** A room that declares repos
gets a second volume, `room-work.img`, at `/work`. Each clone sits at its
target's `guestPath` on that volume, so `DEC-040`'s clone clause stands as
written. Live, on `assistant` (runsheet bundle `~/sl006-live/bundle.txt`):

- **A5:** `/work` is `/dev/vdc` (ext4), apart from `/home` on `/dev/vdb`.
  `room-work.img` is 34359738368 B and was made on first start. Both clones are
  `1001:100 700`.
- **A14:** across a stop and start, the clones, their uids, HEAD
  (`job/sl006-live-1` at `fa1b71a2…`), `refs/host/*` and the host key were all
  identical. The seed did not re-init.

Record: `docs/probes.md`, *Two repos in one room*. Not exercised: a fresh volume
after `room-work.img` is deleted, and `/work`'s growth (`RSK-007`).
