# RSK-012: Room user uids are reassigned in name order on every boot

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

## The risk

A room's root fs is tmpfs and its `/home` is a persistent volume. `vm/room.nix`
declared each user with no `uid`, so on every boot NixOS allocated one afresh:
`nixos/modules/config/users-groups.nix` builds the user spec with
`mapAttrsToList` (sorted by name), and `update-users-groups.pl` hands normal
users the lowest free uid from 1000 up, remembering them only in
`/var/lib/nixos/uid-map` — on the tmpfs root, so forgotten every boot.

The symptom: a room with `bob` (1000) gains `aaron`. Next boot `aaron` is 1000
and `bob` is 1001. Every file under `/home/bob` still belongs to 1000, now
`aaron`. It hides well: `room-seed` runs `install -d -o bob /home/bob` every
boot, which re-chowns the **top-level directory** to the new uid, so `ls -ld
/home/bob` looks right while its contents belong to someone else. Removing a
user shifts every later one the other way.

Why persisting `uid-map` cannot fix it: `/home` is a volume systemd mounts
after activation, and activation is when the allocator runs, so it never sees a
map kept there.

## The fix (SL-005 PHASE-10)

The uid is declared: a room user is `users.<u> = { uid; keys; }`. `rooms.nix`
refuses, with its reason in `reasons.users` (pinned by `roomsCases`), a user not
of that shape, a missing uid, a uid outside 1000-29999 (NixOS's normal-user
range; its system accounts, `nixbld*` among them, sit at 30000 and up), and two
users of one room on one uid. `vm/room.nix` sets `users.users.<u>.uid` from the
record, and `roomImages` refuses an image whose user's uid is not the record's.
`roomsCases` pins that `bob`'s uid is unchanged when `aaron` is added.

Declared rather than derived from the name (POL-003): a hash of the name would
make its formula part of the volume's format, so any later change to it would
re-own every home silently — this risk moved into a code diff.

Not exercised: no room has booted with a declared uid; a uid surviving a real
reboot over a real volume is SL-005 PHASE-09's to see.
