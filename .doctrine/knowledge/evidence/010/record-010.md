# EVD-010: Two tool sets in one room cost four gigabytes of new closure and two of store image

SL-006 PHASE-07's live rung, 2026-10-19, on this host: the `assistant` room from
the consumer at `7f63d55` (oubliette `cc72b97`), declaring `doctrine` and
`goad-walk` as its repos. `docs/probes.md` is the source for these figures:
section *Two repos in one room, and the door that carries them*, and its
*Figures* row. This record cites them and does not own them.

- **Baseline: the repo-less room**, the `assistant` runner before the change.
  It is **not** `EVD-007`'s slot image, so this figure and `EVD-007`'s are two
  different subjects, each measured with `nix path-info -S` on a runner.
- **The confound.** The raw runner delta (4.28 → 9.81 GiB) is not the price of
  two tool sets. The consumer's nixpkgs moved in its own commit just before the
  rung, so the base changed too. A runner's closure also counts the store twice:
  once as paths, once as the erofs image that copies them.
- **The clean arithmetic**, as set operations over `nix-store -qR`: **4.24 GiB of
  tool-set paths are new to the room**. The two sets' union is 5.01 GiB, the
  room already held 0.77 GiB of it, and the sets share only 0.08 GiB with each
  other. The guest-side cost is the store image, **+1.95 GiB erofs**, paid once
  per room image.

Related to `EVD-007`: that record is the price of the flavour composition on a
slot's floor; this one is the price of a second floor in one image (design
sec-10, "a tools-set change is a rebuild and a reboot").

**What it does not prove** (`STD-001`, `ADR-003`): how much of the delta is the
nixpkgs bump, beyond the set arithmetic, since no build isolated either change;
that the figure scales linearly with more repos (`CHR-018`), because the two sets
share almost nothing and a third could share more; any run-time cost, such as a
build through `session` or `/work`'s growth (`RSK-007`); that the 32 GiB sparse
`room-work.img` costs disk beyond what it holds. n = 1, by hand, hence
confidence `medium`.
