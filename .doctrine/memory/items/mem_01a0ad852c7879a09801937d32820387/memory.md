CLAUDE.md's rule is to check a suite can fail by mutating the behaviour it
pins, and the obvious way back is `git checkout -q <file>`. That restores the
file from HEAD — **including the fix you have not committed yet**, which for a
`*-cases.nix` mutation is usually in the very same file as its subject, or in
the one file you just edited to make the suite green.

Two ways out, and either is fine:

- commit the fix *before* mutating it, so `git checkout` means what you want; or
- copy the green file aside first (`cp host/cli.nix "$SCRATCH"/cli.nix.green`)
  and restore from that copy.

Cost when it bites: silent. The build goes green again — against the old
behaviour — and nothing says the fix is gone until the cases you just wrote
start failing for a reason you have already explained to yourself.

Related: [[mem.pattern.oubliette.a-mutation-must-reach-the-case]].
