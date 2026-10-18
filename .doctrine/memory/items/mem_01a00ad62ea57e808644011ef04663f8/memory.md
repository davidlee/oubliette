`~/flakes` builds the fleet two ways, and only one of them is the lock.

Since the SL-004 cutover (2026-10-17) `~/flakes` takes **`fleet`** — the private
consumer, `git+ssh://git@github.com/davidlee/oubliette-fleet`, with only
`inputs.nixpkgs.follows` — and reaches oubliette through it
(`fleet.inputs.oubliette`). `nix flake update fleet` needs the consumer commit
**pushed**, and the consumer's own lock needs oubliette pushed.

But `just system-switch` (and `system-build`, `update-local`) passes a local
override built by `~/flakes/bin/dev-checkouts`: `fleet` resolves to
`$FLAKES_FLEET`, default **`/srv/fleet`**, as `--override-input fleet
git+file:///srv/fleet` — and **that is what actually lands**. A lock update
alone changes nothing. **But the override swaps only the fleet's own tree:
the fleet's inputs stay at `~/flakes`' lock**, not the consumer's. So
oubliette reaches the host at whatever `fleet/oubliette` `~/flakes/flake.lock`
pins, and a consumer bump alone changes nothing either. Seen 2026-10-18 at
SL-005's ninth argument: `/srv/fleet` locked oubliette `f2ce48c` and passed
`rooms`; the switch evaluated it against `~/flakes`' `63cc360` and failed with
`called with unexpected argument 'rooms'`. An oubliette change lands by:
oubliette pushed → consumer bumped, committed, **pushed** → `nix flake update
fleet` in `~/flakes` → switch.

The override reads **committed HEAD** there, and it will happily build from a
**dirty** tree — after which the next build from HEAD **silently loses whatever
was dirty**.

Do **not** shim the target inputs (`fleet.inputs.doctrine.follows = "nixpkgs"`):
the host module evaluates each target's guest image, which reads the target
flake's `packages`, and eval fails with `attribute 'packages' missing`.

Related: **a generation bump is not evidence a code change landed.** Four
consecutive rebuilds here had nothing between them. And the override once bit:
between SL-004 PHASE-07 and the cutover it read oubliette's working tree, whose
module was the fixture's, and system-1101 shipped `alpha`/`beta` units in place
of a–j.
