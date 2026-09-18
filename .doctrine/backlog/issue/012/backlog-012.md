# ISS-012: A provision records a leading flag as its base ref

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

`recordProvisioned` (host/cli.nix) takes the ref it records as `base.ref` from
its third argument, which `provisionSlot` fills with the *original* argv's first
word (`ref="${3--}"`). `capsule-provision` accepts flags on either side of the
ref (host/git-channel.nix, argument parsing), so `capsule a provision --force
<ref>` records `base.ref = "--force"`, and `--profile X <ref>` records
`"--profile"`. `handoff` is unaffected: it passes the tip first.

Pre-existing. Found by the third adversarial pass on SL-001's design (`fnd-44`)
and parked there: SL-001 rewrites `recordProvisioned`'s order but no rule it
states rests on `base.ref`.

Likely repair: take the ref from the program rather than re-parsing argv in the
front end, which would be a second parser for one grammar. For example,
`capsule-provision` prints the ref it resolved on a line the front end reads, as
it already prints `guest is at <commit>`.
