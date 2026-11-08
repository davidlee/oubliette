# CHR-019: Re-check the model door's PI_* env lines against the guest's pi 0.87.1, not pi 1.5.0 docs

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

SL-010's design (D-5) rests the three `.env` lines (`PI_OFFLINE`,
`PI_SKIP_VERSION_CHECK`, `PI_TELEMETRY`) on pi 1.5.0's documentation; the guest
runs pi 0.87.1 (PHASE-08 leg 4). Leg 4 shows the variables reach pi's
environment, not that 0.87.1 honours them. Also: `PI_SKIP_VERSION_CHECK` and
`PI_TELEMETRY` were already in pi's environ before `.env` landed (inferred from
the pi package wrapper, not established). Check 0.87.1's source or behaviour
(no outbound version or telemetry request with the proxy logged).
