# IMP-010: A password-less grant for the volume root helper

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

Deferred from `SL-002` by `DEC-005`. `capsule <slot> volume reset` and
`clone-from` run one root helper (`capsule-volume-root`) through a `sudo` that
prompts for a password, like `capsule <slot> start` does. A `NOPASSWD` rule would
remove the prompt on the module path.

## Shape, if it is done

- `host/proxy-restart.nix`'s pattern: one spelling of the command as `sudo` will
  see it, and the rule beside the others in `host/services.nix`. A rule naming
  one path while the program invokes another string is `NOTES item 44`.
- The helper's state root is a **build-time** argument (`DEC-005`), so the grant
  cannot be pointed at another directory by its caller. Keep it that way.
- Module path only. The devshell copy keeps prompting.

## Two things this must not forget

1. **It removes the implicit confirmation that `DEC-010` relies on.** Reopen
   `DEC-010` (no `--yes` and no typed name) in the same change.
2. **A grant is not an access** (`mem.fact.oubliette.policy-verb-is-owner-only`).
   `sudo -n -l` will list the rule as authorised whether or not a call gets
   through. Only a call by someone who is not the owner proves it, and delegation
   itself is still open as `ISS-005`.

## Not exercised

Nothing is built. The helper this would grant does not exist yet.
