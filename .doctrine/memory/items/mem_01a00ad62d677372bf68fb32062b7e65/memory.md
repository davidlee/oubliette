Host keys live on the capsule's volume, so a fresh capsule presents new ones at
the same address — `known_hosts` refuses, and since the git channel rides ssh
that **blocks provisioning** rather than merely annoying `just ssh`.

`accept-new` does **not** fix it: the host is *changed*, not unknown.

`guestSsh` in `flake.nix` disables the check and keeps no record, injected via
`sshCommand`. **Sound only because the link is a host-created /30 with one peer**
— change it in the same commit as any change to the transport, and don't "fix" it
with a capsule-scoped `known_hosts`, which just accumulates one stale key per
capsule.

**Where they actually are, and the clone case** (SL-002 PHASE-06, 2026-09-17).
`/work/ssh/ssh_host_ed25519_key`, on the volume, named by `sshd_config`'s
`HostKey`. That is *why* `volume clone-from` hands the destination the source's
identity, and why the scrub deletes the key and re-runs `sshd-keygen`.

**The key changes twice across a clone**: once when the copy brings the source's
key in, once when the first `start`'s scrub replaces it. So
`just reset-known-hosts <slot>` run *before* the start does not cover the
scrub's key — the human door fails on the next `capsule <slot> admin` with
`REMOTE HOST IDENTIFICATION HAS CHANGED`.

Both doors were observed in the same run: `ssh`/`admin` are the **human** door
and check strictly; the internal transport does not, which is how
`capsule-inject` connects seconds after the key changed, inside the same
front-end invocation.
