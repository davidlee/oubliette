# ISS-014: A guest's clock stops across a host suspend and nothing corrects it

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

Seen on capsule c, 2026-09-28. Evidence is the host's copy of the guest's
serial console (`journalctl -u microvm@c`) and the host journal.

```
02:58 AEST  host suspends to RAM (S3)
07:00       host resumes: 4h02m asleep
07:22       reboot broadcast in the guest is stamped 17:20:36 UTC;
            the real time was 21:22 UTC, 4h02m later
```

A guest's clock does not advance while the host is suspended, and nothing
catches it up afterwards. `timedatectl` in the guest reports
`NTPSynchronized=no`: the guest has no default route (`POL-001`), so
timesyncd has nothing to reach. The offset persists until the guest reboots.

Consequence: every Claude process in the capsule hung after the resume, and
restarting one hung too. Both clearing on reboot is consistent with clock
skew plus TCP connections left dead by 4h of sleep. That the skew is the
cause is inferred, not reproduced.

Options (unweighed):
- the host sets the guest's clock on resume (a `post-resume` hook, or
  `capsule` sets it over the admin ssh on `start`/`status`);
- serve time on the host end of the guest's link, allowed by the perimeter;
- `status` shows guest clock offset, so the fault is at least visible.

What was not checked: whether kvm-clock would have caught up on its own
given time, or whether chrony's `makestep` over a host-side source is
enough. Related: `mem.fact.oubliette.guest-clock-is-utc`.
