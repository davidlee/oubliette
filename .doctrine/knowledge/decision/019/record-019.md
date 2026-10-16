# DEC-019: Each target's tool-set flake is a literal input, mapped by name in flake.nix and passed to the image as a value

<!-- Knowledge record body — context, detail, links. The structured, queried
     fields live in the sister `record-NNN.toml`; this prose is free-form and is
     never structurally parsed (the storage rule). -->

**Pending supersession (SL-004, 2026-10-16):** DEC-025 pairs each target with its flake (`targets.<name> = {decl; flake}`), so the separate name→flake map and the throw that guards it go away. Superseded at SL-004's reconcile.