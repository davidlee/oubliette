# ISS-027: Intermittent SSH transport failure during room Git pushes

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

## Summary

A bulk sequence of `capsule assistant push <repo> <branch>` commands
intermittently loses the room SSH transport around the `satan` push. Running
`capsule assistant push satan main` on its own succeeds. Moving `satan` to the
start of the same sequence allowed one full run to complete quickly, with
`Already up to date` and `Already on 'main'` messages. This suggests an
order- or load-sensitive interaction in the room Git/SSH path, but does not
establish the cause.

The likely implementation area is `host/room-git.nix`. Each operation checks
the room socket, opens a separate SSH connection to read the `SSH-2.0-` banner,
closes it, then starts Git over a second SSH connection. Bulk sync repeats
this connection churn for every repository. The preflight is a plausible
contributor, not a proven cause.

## Observed failure

During a bulk push run:

```text
Everything up-to-date
f5050d6e1d3a47040432537d137c88ab4ac3abb5
capsule assistant push satan main
Connection closed by UNKNOWN port 65535
fatal: Could not read from remote repository.
Please make sure you have the correct access rights
and the repository exists.
capsule-room-git: push of main (26063ea8180d4fbb7282805679ee1dde120896ae) to room 'assistant' failed (see above).
error: recipe `assistant-push` failed ...
```

A subsequent run started with `pi` and failed before receiving an SSH banner:

```text
capsule assistant push pi main
capsule-room-git: room 'assistant' is not answering: no ssh banner through /run/capsule-room/assistant/ssh.sock.
```

The VM and relay remained active during inspection. Host relay logs showed TCP
resets from the guest around the reported interval. Later, commit
`26063ea8180d4fbb7282805679ee1dde120896ae` was present at guest
`refs/host/main`, with `/work/satan` on `main` and clean. It is unknown whether
the failed-looking attempt had updated the ref before the connection broke or
a later retry did so.

The push path selects room user `agent` from room repo configuration;
`satan` is the profile/repo name, making a repo/user name collision unlikely.

## Hypotheses

- Separate banner-only probes cause harmful connection churn or expose a race
  in the relay or guest sshd during a long series of repo operations.
- Earlier pushes trigger room-side work or consume resources that affect later
  pushes.
- The `satan` correlation is incidental: moving it first also changed whether
  it had pending work, since the later run reported `Already up to date`.

The bulk recipe appears to invoke pushes sequentially. Concurrent updates have
not been demonstrated; cumulative load or room-side work that outlives each
client command may be involved.

## Investigation

1. Repeat the exact bulk sequence with `satan` first and last; record timestamps
   and each command's exit status.
2. Compare runs where `satan` has a pending commit with runs where it reports
   `Already up to date`.
3. Correlate host relay journal entries with guest sshd logs/processes and the
   affected profile's Git receive/update hooks.
4. During a failure, check whether the banner probe receives EOF/FIN and how
   quickly its sshd child exits. Check unauthenticated sshd children and
   configured `MaxStartups` / `LoginGraceTime`.
5. Assess whether the banner probe can be removed or replaced with a check that
   avoids a second SSH connection while preserving the CLI's intended
   distinction between unavailable transport and authentication/Git errors.

## Evidence and limits

Confirmed from source and observation: a separate banner probe exists; the VM
and relay were active during inspection; the reported bulk failures varied
with ordering; standalone `satan` push works; and moving `satan` first allowed
one full run. The reordered run also reported `Already up to date`, so order
and pending work were not isolated.

Unconfirmed: that the banner probe causes the failure, that sshd startup limits
are reached, or that pushes overlap in time.

## Diagnosis and fix (2026-10-30)

**Cause (inferred, strongly consistent; not observed on the live room):**
sshd's `PerSourcePenalties`, on by default in the guest's OpenSSH 10.6p1. Its
`noauth` penalty is 1s per connection that closes without trying to
authenticate, and sshd refuses a source once its penalty passes `min` (15s).
The pre-flight above is exactly such a connection, and every connection
through the door arrives from one address, `net.host` (10.99.0.1, confirmed
from `$SSH_CONNECTION` in the room). So about fifteen pushes in quick
succession lock this host out until the penalty decays. That fits every
observation: the order sensitivity, a lone push succeeding,
`Connection closed by UNKNOWN port 65535` (refused at accept), the next run's
"no ssh banner", and a consumer-side `sleep` between pushes helping. The
`satan` correlation is position in the run, not the repo.

Not confirmed: the refusals themselves. The room's sshd journal was not
readable as `agent`, and a fixture `sshd -i` keeps no penalty table, so no
sandbox reaches this branch.

**Fix:** `vm/door.nix` sets `PerSourcePenaltyExemptList = net.host`, for
capsules and rooms alike. Only this host can reach the door, so the penalties
protected nothing. `fragmentsCases` case 10 pins the setting on the capsule
image and every fixture room (red before, green after); `just build` renders
it into `sshd.conf-final`, which NixOS validates with sshd.

**Open until:** a bulk `assistant-push` with the consumer's `sleep` removed
runs clean against a room rebuilt from this commit. Then resolve this item.

**Not done:** the pre-flight still opens a connection it never logs in on. With
the exemption that is harmless churn; removing it is a separate improvement
(Investigation step 5), not needed for this fix.
