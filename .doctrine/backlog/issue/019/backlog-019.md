# ISS-019: A moved policy directory leaves every slot's allowlist link dangling

**A slot's allowlist link stores an absolute path into `policyDir`, and nothing
re-points it when `policyDir` moves.** Found 2026-10-17, after the SL-004
cutover moved the fleet's policies from `~/dev/microvm-spike/perimeter` (this
repo's old checkout path) to `/srv/fleet/perimeter`.

## The mechanism

`host/services.nix` makes each link with tmpfiles `L` (not `L+`): create when
absent, leave alone when present. That is deliberate — an assigner's selection
must survive a boot — but it cannot tell an *assigner's* link from a *stale*
one. So every link from before the cutover survived it:

```
/var/lib/capsule-allowlist/{a..j} -> /home/david/dev/microvm-spike/perimeter/egress-allow.txt
```

## What it does

`capsule-proxy-<slot>` binds the link's target at start, and systemd fails it
at the NAMESPACE step (status 226) on the missing path, every 3 s, forever.
Slot `j` had been in that loop since the cutover. A proxy already running when
the path vanished (`a`) keeps serving until its next restart. **Fail-closed**:
no proxy, no egress — so nothing leaked, but no slot could start a working
session.

## Remedy taken

`capsule j policy build` re-pointed `j` (generation 2) and its proxy came up;
the same verb re-pointed `b`..`i`, whose proxies were down, and then `a`,
restarting its live proxy under a working agent. Every re-point bumped a record generation for a selection that
did not change — the verb is the only tool, not the right one.

Run it with the module's binary (`/run/current-system/sw/bin/capsule`): from
inside this checkout the devshell's fixture copy shadows it and refuses every
real slot as unknown (`fact.oubliette.devshell-programs-shadow-the-modules`).

## Design options

- The link names a policy *by filename* and the proxy resolves it against
  `policyDir` at start — the selection stops encoding a location.
- Or the record stays the truth and the link is derived from it at proxy start
  (`ExecStartPre`), so a moved directory heals on the next start.
- Either way, `capsule all status` should say a link dangles rather than show
  the proxy as `activating`.
