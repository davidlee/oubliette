# DEC-055: A room's door is one ordered list of ssh options, rendered as argv words for oubliette's doors and as an ssh_config for clients

<!-- Knowledge record body — context, detail, links. The structured, queried
     fields live in the sister `record-NNN.toml`; this prose is free-form and is
     never structurally parsed (the storage rule). -->

Amended by RV-023 F-2/F-6 (design review, 2026-10-20): optionsOf also carries GlobalKnownHostsFile none, for every door, so no door consults /etc/ssh/ssh_known_hosts* beside the room's one store (DEC-047); room-door.nix takes rooms.stateDirOf as an argument.