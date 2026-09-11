Real `bedtools` is installed on this VM and is the reference implementation. Diffing
against it is worth more than any test you'd write by hand — you never have to know
the right answer, and the tests survive a rewrite in another language.

Read `tests/README.md` first. It explains the pattern and has a worked example for
exactly one case; your job is to grow it into a suite and wire it to Continuous
Integration (CI) so it runs on every push.

## Goal

Three guardrails, all running automatically on every push and PR: **golden tests**,
**unit tests**, and a **linter**.

## Acceptance criteria

**Golden tests**
- [ ] `tests/run_golden.sh` exists, is executable, exits non-zero if any case fails
- [ ] One case per subcommand and flag combination in `SPEC.md`
- [ ] Covers reading from stdin as well as from a file
- [ ] Compares exit codes, not just stdout

**Unit tests**
- [ ] A unit test per edge case in the fixtures: bookended, zero-length, nested,
      identical, position 0, and the overlap predicate itself
- [ ] They run without `bedtools` installed, in seconds
- [ ] Each one fails for exactly one reason — a broken test should name the bug

**Linter**
- [ ] A linter appropriate to your language, with its config committed
- [ ] It passes cleanly, or the exceptions are configured deliberately, not ignored

**CI**
- [ ] `.github/workflows/ci.yml` installs bedtools and runs all three
- [ ] The `echo "no tests yet"` placeholder step is gone
- [ ] CI is green on a PR, and red when any one of the three fails

## Then break it

Once CI is green, introduce a subtle off-by-one in the overlap logic on a branch and
open a PR. Watch CI catch it.

If CI stays **green**, that's the more interesting outcome: your suite has a hole.
Work out which case would have caught it, add that case as a **unit test**, and watch
it go red. That is the loop you're trying to build a habit around.

## Notes

- `merge` and `closest` need sorted input — sort into a temp file first. `a.bed` and
  `b.bed` are deliberately unsorted.
- The fixtures contain zero-length and bookended intervals, and bedtools handles them
  in ways nobody guesses right. Whatever bedtools prints is correct. Encode it, add a
  comment explaining that it's oracle behaviour, and move on.
