`doctrine revision apply` auto-lands only `status` rows. A `modify POL-NNN`
(or any introduce/create/move/prose) row is printed as "surfaced for manual
handling" and the REV moves to `started`; the policy's `.md` is untouched.

Do: put the REV's before/after text into the policy file by hand (e.g.
`.doctrine/policy/003/policy-003.md` — the slugged dir is a symlink to it),
then `doctrine revision status REV-NNN done`, and commit both together.

Seen twice: REV-004 (SL-005) and REV-008 (SL-008). Also: `revision new` takes
no body, so the REV's prose goes straight into `revision-NNN.md`.
