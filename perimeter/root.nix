# Where the devshell path keeps its state: the checkout a human runs from, or
# the one `CAPSULE_ROOT` names. One spelling, because four copies had already
# become two answers — `quarantineOf` had dropped `MICROVM_SPIKE_ROOT` — and the
# front end now reads a link `vm` writes under this root, so the two must agree
# (SL-003 design sec-4, RV-010 F-4). A shell assignment, spliced; sets `root`.
''root="''${CAPSULE_ROOT:-''${MICROVM_SPIKE_ROOT:-$PWD}}"''
