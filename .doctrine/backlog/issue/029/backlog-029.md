# ISS-029: A declared default that moves does not reach a slot whose rendered state already exists

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

Found drafting SL-010 (design sec-4, D-1). Inferred from reading
`host/services.nix`, not reproduced on a host.

A slot's allowlist link is seeded by tmpfiles `L` (create if absent) at the
slot's declared policy. When the operator changes that declared policy in
`capsules.nix` and the slot's record holds no override, the existing link still
points at the old policy after rebuild and reboot. `capsule <n> policy` with no
argument then prints the new declared value (`effectivePolicy`) while the proxy
serves the old one.

SL-010's model door state file (`f`, create if absent) has the same shape. The
design closes it for starts through the front end by re-rendering the
effective value at `capsule <n> start`, and leaves the residual for a bare
`systemctl start microvm@<n>`. The policy link has no re-render at all.

Candidate fix: the front end re-renders both at `start`, or an activation step
re-renders every slot whose record holds no override. When the declared policy
narrows, the stale link fails open.
