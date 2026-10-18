**Fact.** In a guest whose root is tmpfs (every capsule and room image), a
`users.users.<u>` with no `uid` gets a fresh allocation on every boot.
NixOS's `update-users-groups.pl` allocates normal users upward from 1000, in
`mapAttrsToList` (name) order, and remembers them only in
`/var/lib/nixos/uid-map`, which lives on the tmpfs root. Add a user whose name
sorts earlier and every later user's uid shifts by one, so their homes on the
persistent volume now belong to someone else. A top-level `chown` in a seed
hides this, because the top directory looks right.

**Persisting `uid-map` cannot fix it**: `/home` (the volume) is mounted by
systemd *after* activation (`neededForBoot = false`), so activation never sees
a file kept there.

**How to apply.** Declare every guest user's uid: the capsule's `agent` is
`uid = 1000` (`vm/capsule.nix`), and a room user is `{ uid; keys; }` with a uid
in 1000-29999 (`rooms.nix`, RSK-012, a22f882). Refuse a bad uid in the library
with its own reason before NixOS's own asserts (`>= 1000`, unique) fire at image
eval with theirs. `nixbld*` sit at 30001+, which is why the ceiling is 29999.
Check that `systemd.sysusers` and `userborn` are off, since they change the
allocator.
