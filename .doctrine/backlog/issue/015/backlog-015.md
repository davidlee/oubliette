# ISS-015: The target input names a path on one desktop, so the flake is unfetchable anywhere else

`inputs.target.url` was `git+file:///home/david/dev/doctrine`, and the committed
`flake.lock` pinned that path. Anyone else cloning oubliette could not evaluate
the guest image, and `~/flakes` carried `inputs.target.follows = "nixpkgs"`
partly to stay fetchable from darwin.

Two layers, only one a defect:

1. **Fetchability** (fixed here): the input is now
   `github:davidlee/doctrine/edge` (doctrine is public), so the lock pins a
   pushed rev anyone can fetch.
2. **`target.nix`'s `path`** still names this host's checkout. That is
   configuration, not breakage: confining another repo means editing
   `target.nix` anyway (NOTES item 16; README "Pointing it at a different repo").

Cost accepted: a doctrine change needs a **push** before `nix flake update
target` sees it. Unpushed work is tried with `--override-input` on a build, never
on `nix flake lock` (which writes the local path back into the lock).
`microvm -c` takes no override, so a created slot always gets the locked rev.
Recorded as `mem.fact.oubliette.target-input-reads-pushed-edge`, superseding
`mem.fact.oubliette.git-file-inputs-read-committed-head`.

Considered and not taken: an in-repo placeholder target so the flake names no
real project. Purer under POL-002, but a second target to maintain, and doctrine
is public and already the worked example.
