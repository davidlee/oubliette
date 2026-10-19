# DEC-056: Room clients bind the door's parent directory and the room's state directory, check host keys strictly, and never write known_hosts

<!-- Knowledge record body — context, detail, links. The structured, queried
     fields live in the sister `record-NNN.toml`; this prose is free-form and is
     never structurally parsed (the storage rule). -->

Amended by RV-023 F-3 (design review, 2026-10-20): the module makes /run/capsule-room at boot (tmpfiles d 0755 root root, derived from socketOf) when rooms exist, so a jail started before any relay has a directory to bind.