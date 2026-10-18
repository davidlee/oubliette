# IMP-018: just refresh-build and just up cannot serve a room

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

## The problem

`just refresh-build <name>` and `just up <name>` (`just/fleet.just`, ~:152 and
~:191) are slot-shaped. `up` asks `capsule <name> created`, and a room refuses
any verb outside `ssh, start, stop, push, collect, forget-host-key` with exit 2.
So `up` exits 2, and `refresh-build` ends in `up` whenever the guest was
running. Found while planning SL-006 PHASE-07 (its F-1).

So updating a room after a guest change is three commands by hand, which is
how PHASE-07's U1 ran:

    capsule <room> stop
    sudo microvm -u <room>
    capsule <room> start

## Shape

Either give rooms a `created` answer (a room is a guest the front end can ask
about), or make the recipes branch on whether the name is a room. The first
keeps `just` ignorant of the room/slot distinction. Also check `up`'s tap
refusal and its `microvm -c` arm against a room, which also needs a create on
first use (SL-005 PHASE-09).
