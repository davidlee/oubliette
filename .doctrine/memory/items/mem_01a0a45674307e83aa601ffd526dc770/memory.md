Read on this host 2026-09-15 (`stat`): `/var/lib/microvms` is `microvm:kvm 0775`,
each `/var/lib/microvms/<slot>` is `root:kvm 0775`, each image is
`microvm:kvm 0644`, and `microvm` (uid 970) is in `kvm`. **Every VMM runs as
`microvm`, whichever slot it serves**, so a running VMM on slot `c` can rename,
replace or symlink anything in slot `b`'s directory.

So a root program that does a **path-based** act in there (`cp` to a name,
`chown`, `chmod`, `rm` then create) has a symlink race any running VMM can win:
root ends up changing the owner or mode of an arbitrary file, overwriting one, or
copying a file `microvm` cannot read into an image it can. A `fuser` on the image
does not help, because the racer is a *different* slot's VMM, and the one-image
lever means every VMM is `microvm@capsule`.

The fix `capsule-volume-root` uses (SL-002 design sec-3, `RV-003` `F-1`) is to do
every create, modify, rename or remove in an image directory **as the image
owner**: `setpriv --reuid=microvm --regid=kvm --init-groups -- …`. A won race
then gains nothing the VMM does not already have, a copy the owner makes needs
no `chown`, and a swapped source the owner cannot read fails the copy. Root keeps
only what writes nothing through that directory: locks, `fuser`, `stat`, and
files in directories `microvm` cannot write, such as the operator's
`/var/lib/capsule/slot/<slot>/`.

No sandbox has a second uid, so a suite can only log which acts went through the
drop and grep the shipped render for the `setpriv` line. That the drop works
under `sudo -k` is a live exercise. See
[[mem.fact.oubliette.dead-guest-is-not-a-dead-vm]].
