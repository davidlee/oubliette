# IMP-024: Pin UpdateHostKeys off in the strict room-client render

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

From RV-024 F-9 (SL-008 audit). The strict client render (host/room-client.nix,
via host/room-door.nix `optionsOf`) relies on openssh disabling `UpdateHostKeys`
implicitly when `UserKnownHostsFile` is overridden, for "a client never writes
known_hosts". Nothing pins it, and room-client-cases case 6(c) cannot catch a
regression because the fixture sshd offers one host key. Do: render
`UpdateHostKeys no` for `checking = "yes"`, and pin `updatehostkeys false` under
`ssh -G` in case 1. The read-only bind already makes a write fail rather than land.
