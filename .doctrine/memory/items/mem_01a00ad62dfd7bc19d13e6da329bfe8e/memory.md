The assignment record's root is the module's `moduleState`, which mkFleet sets to
its declared `stateDir` (`DEC-054`), **deliberately** — a slot is a module-path
thing, so a record for a devshell capsule would describe a slot that does not
exist (`host/cli.nix`, `recordRoot`). `/var/lib/capsule` survives only as the
*default* of `moduleState`, a test seam. `quarantineOf` **searches both homes**,
because either shape can collect.

So a devshell `capsule <name> unit|purpose|provision` writes the **live** record
whatever `CAPSULE_STATE` says, and **there is no throwaway root to try one
against** from the command line (a case suite can, by passing `moduleState`): the
generation only goes up, so an experiment is a hand-edit to undo.

Related: **`capsule-adopt` has no transport**, so it reads whichever quarantine
the environment points at. Every other host-side program resolves a capsule and
goes through the relay; this one just reads a directory, so inside the repo it
silently reads the **devshell** quarantine.
`CAPSULE_STATE=<the declared stateDir>` is what points it at the module path's.
