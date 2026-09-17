`doctrine design show <SL> --format status` can report

```
sections     8 (0 with outstanding review)
changes      0 since the declared baseline
review_pass  STALE — it no longer covers current content
```

on a run that is **locked, fully attested and accepted**. The three readings
disagree because `review_pass` is computed from one field the other two do not
touch.

**Where it comes from.** `.doctrine/state/slice/NNN/design.toml` holds
`[review.pass]` with a `review = "RV-NNN"` and a `covered` map of
section → fingerprint. A `review_disposed` act updates the `review` id; at
`SL-002` it left `covered` at the **previous** disposal's snapshot. So the run
compares today's section fingerprints against an attestation set several
revisions old and reports STALE forever after.

**How to settle it in one read**, rather than trusting or distrusting the flag:

```sh
doctrine design show <SL> --full     # current per-section fingerprints
grep -A12 '^\[review.pass' .doctrine/state/slice/NNN/design.toml
awk '/^\[\[review.attestation\]\]/{f=1} f&&/^\[review.pass\]/{exit} f' \
  .doctrine/state/slice/NNN/design.toml | grep -E '^id|^subject|^fingerprint' | paste - - -
```

If every section has an attestation at its **current** fingerprint, and
`cpa-design-accepted`'s `covered` map matches the current set, the design is
reviewed at the content it holds and the flag is about the snapshot alone. That
is the evidence to lean on — an attestation and a human acceptance act are
stronger than the scalar either way.

Defect is in the doctrine CLI's `review_disposed` write, not in this repo;
`SL-002`'s run `dr-01a0a2ae-bcb8-7b80-a3f3-53dcbaf0706e` (revisions 58 → 72) is a
clean reproduction. Raised and dispositioned as `RV-006` `F-5`.
