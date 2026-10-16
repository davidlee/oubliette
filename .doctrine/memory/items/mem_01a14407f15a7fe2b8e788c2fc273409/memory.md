Two sharp edges hit locking SL-004's design (2026-10-16):

- **`codex exec` reads stdin even when the prompt is an argument.** Run in the background with no input, it prints `Reading additional input from stdin...` and waits until a `timeout` kills it (exit 124), with no review written. Pass `< /dev/null`, and `-o <file>` to capture the final message on its own.
- **The reviewing→locked gate refuses `blocker`/`major` findings that carry no `--route`**, including findings verified before routes existed. A verified finding can't be amended. The raiser `reopen`s it, the responder `dispose`s it again with `--route`, then `verify`. Reopening clears the pass's concluded marker, so `conclude` again and record `review-disposed` again before the lock.
- The run's `review_pass RV-NNN STALE` marker survived a re-conclude and a `review prime`. It did not block a `conducted` disposition.
