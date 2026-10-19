# DEC-054: The host's state root is a fleet declaration: mkFleet's tenth argument, and the module reads it

<!-- Knowledge record body — context, detail, links. The structured, queried
     fields live in the sister `record-NNN.toml`; this prose is free-form and is
     never structurally parsed (the storage rule). -->

Amended by RV-023 F-4 (design review, 2026-10-20): the eval refusal narrows stateDir to an absolute path over [A-Za-z0-9._+/-] with no '..' component, which covers ssh's list/token reading and the value's unquoted splices into generated shell (host/cli.nix:937, host/volume-root.nix:76).