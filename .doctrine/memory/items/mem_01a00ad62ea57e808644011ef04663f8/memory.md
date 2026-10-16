The `oubliette` input is `github:davidlee/oubliette`, so `nix flake update
oubliette` needs the commit **pushed** — but `just system-switch` passes
`--override-input oubliette git+file:///home/david/dev/microvm-spike`, a symlink
to this checkout, and **that is what actually lands**. A lock update alone
changes nothing.

The override reads **committed HEAD** there, and it will happily build from a
**dirty** tree — after which the next build from HEAD **silently loses whatever
was dirty**.

Related: **a generation bump is not evidence a code change landed.** Four
consecutive rebuilds here had nothing between them.

**Correction (2026-10-16):** ~/flakes justfile:14 now overrides with `git+file:///home/david/dev/oubliette/`, not the microvm-spike symlink. SL-004 replaces this input with the consumer flake (`fleet`), so both ways move to it.

**Hazard until SL-004 PHASE-09:** the override builds this checkout's working tree, whose module is now bound to the **fixture** (slots `alpha`/`beta`), not the real slots. A `system-switch`, `system-build` or `update-local` through that override would replace the live host's units with the fixture's. Its rewrite is PHASE-09's, when `~/flakes` overrides the consumer (`fleet`) instead.
