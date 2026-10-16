Two sharp edges hit authoring SL-004's design run (2026-10-16):

- **Sections materialise in text order of their ids**, so `sec-10` lands between `sec-1` and `sec-2` in design.md. With ten or more sections, assign bodies to ids in that order (SL-004 put its second section in `sec-10`) rather than expecting numeric order.
- **A `needs` edge to a node created in the same `declare` payload is refused** (`unknown node: inq-2`). Declare the nodes in one apply, then add the `needs` edges in a second.

Also: editing slice-NNN.md after `doctrine slice research <id>` drifts the baseline, and `explore.research` refuses to discharge until `doctrine slice research <id> --restamp`.