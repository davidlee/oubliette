# CHR-015: Declare this project's gate command for doctrine check

`doctrine check gate` — the end-of-phase cadence every `/audit` is told to
run — exits with:

```
error: justfile does not contain recipe `gate`
```

`.doctrine/doctrine.toml` declares no `[check]` table, so the cadence falls
through to its baked default `just gate`. This project's gate is the **default**
recipe, whose own comment reads *"the gate: everything parses and is
formatted"*, and which runs the build, `hostModuleUnits`, all fourteen `*Cases`
suites and fmt. `doctrine check commit` works, because its default `just check`
exists.

**Two ways to close it**, and they are not equivalent:

- a `[check]` entry in `.doctrine/doctrine.toml` pointing `gate` at `just` —
  keeps the justfile's surface as it is, and says the mapping once where
  doctrine looks for it;
- a `gate:` alias recipe in the justfile — discoverable from `just --list`, but
  adds a second name for the default recipe.

Prefer the first: the justfile already names the gate, and a second spelling is
a second thing to keep true.

Found at `SL-002`'s closure audit, where the gate was run directly instead
(`just check` ok, `just` exit 0). Raised as `RV-006` `F-12`, disposed follow-up.
It affects every audit in this repo, not that slice.
