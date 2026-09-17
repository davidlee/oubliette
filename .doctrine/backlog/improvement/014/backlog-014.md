# IMP-014: setup --force leaves the archive to its caller, and the only caller doing it is in another repo

**Two provisioning verbs, two answers to "what happens to what the slot held",
and the round trip anyone actually drives uses the one that does nothing.**

`archiveRefs` (`host/cli.nix:1387`) is called from exactly one place —
`handoff` (`:2097`), which collects the destination, fetches it, and archives its
refs under `refs/capsule/<slot>/gen/<g>/` before anything is forced over it. That
is handoff's decision 3, and it is what makes its force safe.

`setup --force` declines the same job, explicitly and in writing (`:1907`):

> `--force` drops that chain and provisions. **Nothing archives it**: a
> quarantine holds what the last collect took and no more, so collect first if
> that chain is worth keeping.

Which is an honest decision, not an oversight — and it puts the archive in the
caller's hands. **The caller is doctrine.** `scripts/oubliette.sh`'s `cmd_send`
does the whole of handoff's decision 3 by hand, around `setup`:

```
collect → fetch → archive_refs → drop the guest's state chain → setup --force
```

## What is duplicated, and where it will drift

| oubliette | doctrine's copy | how a divergence shows |
| --- | --- | --- |
| `archiveRefs` (`host/cli.nix:1387`) | `archive_refs`, a line-for-line port whose comment admits it | the ref layout is **this repo's**; a change to it makes the port a no-op that archives nothing |
| `guestDropState` + the `stales` scan (`:1916`) | an ssh'd `git update-ref -d` per stage | doctrine hand-builds a git command for the guest, which is the one boundary `host/git-channel.nix` exists to own |
| `quarantine.stateRefsOf` | `GUEST_STATE_REFS=refs/capsule/state`, a constant | a rename here is silent there |

Both copies of the archive returned quietly when they moved nothing — the
failure mode being that an archive which moved *nothing* reads exactly like one
that had *nothing to move*, while the force is armed either way. doctrine's copy
is loud as of `2f577fc70`; `archiveRefs` here still has the bare
`[ "$moved" -gt 0 ] || return 0` at `:1397`.

This is the `NOTES item 20` shape one level out, and the same rule `CLAUDE.md`
states for the two paths: *don't grow a second implementation — if a unit needs
something, it comes from the same program.* Here a second **repo** grew one.

## What this is not

Not `ISS-009`. That is about what a provision leaves on the *volume* — the
previous unit's untracked and ignored files. This is about what a provision
leaves in the *ref space*, and who moves it.

## Directions, none chosen

1. `setup` archives when it forces, the way `handoff` does — collapses the two
   verbs' answers into one and deletes doctrine's port.
2. A `capsule <slot> archive` verb, so a caller that wants handoff's decision 3
   around `setup` asks for it instead of reimplementing it. Keeps the
   documented "nothing archives it" default intact.
3. Leave it, and make the port's obligation explicit in
   `contract-doctrine.md` — the boundary already has a Role for what doctrine
   must supply, and "archive before you force" would be the first entry that is
   a *behaviour* rather than a value. Cheapest, and the one that keeps two
   implementations.

(1) and (2) both need the `g = -` case decided: `handoff` skips the archive for a
slot nothing has ever assigned, and `setup` can be handed one.

## Evidence rung (`STD-001`)

The duplication is **read**, not run: three call sites and one port, cited above.
Nothing has been observed drifting — the ref layout has not moved since the port
was written, which is exactly why a drift would be invisible today.
