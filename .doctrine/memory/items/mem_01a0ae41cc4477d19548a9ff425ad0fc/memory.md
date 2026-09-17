`/reconcile` writes per-slice artefacts by **direct edit** to `design.md` under
the authored-truth honour model. Those edits do not reach the design run's
runtime sections.

**Observed** (SL-002, run `dr-01a0a2ae-bcb8-7b80-a3f3-53dcbaf0706e`, locked at
revision 75): six deviation fixes written into `design.md` across five sections,
after which `doctrine design show --full` still reported
`changes_since_baseline=0`, all eight sections `review=current`, and every
section fingerprint unmoved. The run cannot see the file it produced.

**Inferred, not observed:** `doctrine design materialise` is documented as
"render runtime sections into authored prose", so re-materialising this run would
render the pre-reconcile text over the file and drop the edits. Nobody has run it
to find out, and finding out costs the edits — so treat it as a hazard, not a
measurement.

**What to do:** after a reconcile pass, `design.md` is ahead of its run. Do not
re-materialise a locked run whose slice has been reconciled. If a design run must
be reopened after reconcile, carry the reconcile edits back into the run's
sections first, or they are lost with no diff to notice — the same shape as
[[mem.fact.oubliette.review-pass-stale-is-a-snapshot-not-a-gap]], where the run's
own bookkeeping and the truth on disk disagree and only one of them is loud.
