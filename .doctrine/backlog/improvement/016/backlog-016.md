# IMP-016: ~/flakes reads the fleet's net instead of repeating vm-capsule and 3128

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

`~/flakes/features/virt/capsule.nix:83,104-105` spells the tap name
`vm-capsule` and the proxy port `3128` that `net.nix` declares, so a change to
`net` silently desyncs the devshell path's firewall opening and forward drop.
Once SL-004 gives `net` a home in the consumer flake, that flake can export it
(e.g. `outputs.net`) and `~/flakes` read `inputs.fleet.net.tap` /
`.proxyPort`. Raised as RV-012 F-5 (pre-existing, not SL-004's).
