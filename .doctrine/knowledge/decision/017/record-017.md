# DEC-017: A slot's declared profile also selects its image

<!-- Knowledge record body — context, detail, links. The structured, queried
     fields live in the sister `record-NNN.toml`; this prose is free-form and is
     never structurally parsed (the storage rule). -->


## The split, against the ledger (SL-003 reconcile)

This decision lands what four closed ledger items left as the limit. The ledger
takes no new edges (`ADR-002`), so they are cited here in prose:

- **NOTES item 21** made every declared capsule one flake value, so "one image,
  N capsules" was structural. Now it is one value *per target*: a declared
  slot's attribute is the image its `profile` names (`fleet.nix`).
- **NOTES item 28** removed the slot default. A declared slot with no `profile`,
  or one naming no target in `targets/`, now throws at eval, naming the slot.
  That is the same refusal on the build axis.
- **NOTES item 51** made host programs independent of which target this host
  confines. This decision extends that to the guest image: one per target,
  selected by a value.
- **NOTES item 52** pins a slot to the document bytes it was provisioned under.
  `DEC-023` adds that a profile verb proceeds only when the running image names
  the same target.

`DEC-016` (every slot declares doctrine until a slot can boot another image) is
superseded: that condition is now met.
