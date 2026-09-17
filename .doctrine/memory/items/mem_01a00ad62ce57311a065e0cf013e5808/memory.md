`host/services.nix`'s `wrap` builds a package under the **same name** whose whole
text is `CAPSULE_STATE`/`CAPSULE_REPO` and `exec <inner>`. The five that keep
host state (`capsule`, `capsule-collect`, `capsule-provision`, `capsule-adopt`,
`capsule-brief`) are **three lines each** in `/run/current-system/sw/bin`.

So grepping one **reports a program that does not have the flag**, and every
generation shares the wrapper's store path whenever nothing it embeds moved —
which reads as *this host never rebuilt*.

**Both readings are wrong in the same direction and they corroborate each
other**: an interactive `PATH` here can also hold a third, staler `capsule` that
really is behind, so a verb list taken from `which capsule` agrees with the bad
grep and nothing contradicts either.

**Ask the program, don't read it** — `/run/current-system/sw/bin/capsule all
status`, or follow the `exec` line to the inner store path.

Cost a session, concluding the host was a version behind when it was current.

**A third reading that agrees with the other two** (SL-002 PHASE-06, 2026-09-17).
Inside the repo, the devshell's `capsule` and the module wrapper's **inner**
store path can be the *same path* — and that reads as "the host is built from
this source". It is not: it means the two copies are the same **build**, and if
the devshell has not been re-entered since the system was built, both are stale
together. Store-path equality between two copies says they agree, never that
either matches the tree.

This cost a wrong verdict in both directions in one session: first "the host is
current" from the two copies agreeing, then "the rebuild did not land" from
`readlink -f` on the wrapper, which contains none of the program's text.

**The sound freshness read, in one line:**

    P=$(grep -o '^exec /nix/store/[^ ]*' /run/current-system/sw/bin/capsule | awk '{print $2}')
    grep -c '<a marker the tree has>' "$P"

Better still, ask at the wire — the verb or flag either answers or it does not.
