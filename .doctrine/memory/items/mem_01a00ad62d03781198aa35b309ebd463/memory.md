The CLI appends `#nixosConfigurations.<name>.config.microvm.declaredRunner`
itself, so `-f …#capsule` asks for that attribute **of** `packages.capsule` and
the error reads as a missing output.

With **no `-f` at all** it defaults to the flake at `/etc/nixos` — not a git repo
on this host — and fails as `fatal: '/etc/nixos' does not appear to be a git
repository`, **naming neither the missing flag nor the fact that it substituted a
path you never typed.**

Use `just up <name>` from the consumer checkout (`/srv/fleet`), which passes
`{{justfile_directory()}}`. It also needs root, for `/var/lib/microvms` and the
gcroots. Run from oubliette itself, `-f` and `just up` name the **fixture**
(`alpha`/`beta`, target `fixture`), never a real slot.

`microvm -u` takes no `-f`, **correctly** — it re-reads the flake ref recorded in
`/var/lib/microvms/<name>/flake`, which for every slot here (a b c d e f j) is
the bare path **`/srv/fleet`** since the SL-004 cutover (2026-10-17). A bare path
reads the **working tree**, so a refresh picks up an uncommitted `flake.lock`.
After a guest change use `just refresh-build <name>`, which reads `ActiveState`
rather than `is-active` — `auto-restart` is the worst moment to update under.

The recorded path is a durable host value, not a checkout location: moving the
consumer means re-pointing every `/var/lib/microvms/*/flake`. Before the cutover
the refs were split across two spellings of this checkout
(`/home/david/dev/microvm-spike`, `/home/david/dev/oubliette`), so read the
files before assuming either.
