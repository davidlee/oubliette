# ISS-020: The fixture fleet writes allowlist links into this host's /var/lib

**Oubliette's own flake exports the fixture fleet's host module, and a host
that consumes it gets slots nobody declared.** Found 2026-10-17.

## Observed

```
/var/lib/capsule-allowlist/alpha -> /nonexistent/fixture-fleet/fixture/perimeter/egress-allow.txt
/var/lib/capsule-allowlist/beta  -> /nonexistent/fixture-fleet/fixture/perimeter/egress-allow.txt
```

root-owned, 10:16 — the minute of a `~/flakes` switch run with `--override-input
oubliette git+file:///home/david/dev/oubliette`. That switch stopped
`microvm@j` and its units; the next one, at 10:55, brought the `/srv/fleet`
fleet back. Read from the journal; which `~/flakes` attribute selected the
fixture module was not checked.

## The mechanism (inferred)

`flake.nix` outputs `fleet // { … }` where `fleet = mkFleet (import ./fixture
…)`, so `oubliette.nixosModules.*` is a working host module over `alpha` and
`beta`. `~/flakes` reading it instead of `fleet.nixosModules.*` evaluates and
switches cleanly — and tmpfiles `L` rules then leave the fixture's links behind
for good (ISS-019's mechanism).

## Options

- Export the fixture fleet's outputs under a name that cannot be mistaken for
  a host's (or not at all — `just` builds them from inside the repo).
- Clear the two residual links (owner's act; they are harmless — no unit reads
  them).
