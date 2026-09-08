# Issue texts

Forks don't copy issues, so your fork starts with an empty issue list. Re-filing these
on your own fork is the first exercise — hand the job to your agent (see the warm-up
prompts in `prompts.md`) rather than doing it by hand.

The three commands are below as a fallback — worth reading so you can check what the
agent proposes, but the exercise is telling it to do this, not typing it.

```bash
FORK=<your-github-username>/ai_agent_workshop

gh issue create --repo "$FORK" \
  --title "Warm-up: make \`mytools --version\` work" \
  --body-file issues/01-warmup-version.md

gh issue create --repo "$FORK" \
  --title "Adopt or write a spec" \
  --body-file issues/02-adopt-or-write-a-spec.md

gh issue create --repo "$FORK" \
  --title "Set up tests (unit + golden), a linter, and CI" \
  --body-file issues/03-golden-tests-and-ci.md
```

The fourth is a stretch goal — file it too if you want it on the board:

```bash
gh issue create --repo "$FORK" \
  --title "Stretch: find why this VCF is out of spec" \
  --body-file issues/04-vcf-forensics.md
```

Check with `gh issue list --repo "$FORK"`.

**`--repo` is not optional, and forgetting it is silent.** `gh` with a missing or
empty `--repo` does not error — it resolves to the git remote and exits 0, so filing
on the upstream template looks exactly like success. Note also that `FORK` above is a
variable in *your* shell: one an agent exports in a command is gone by its next one,
which is why the fork name belongs in `CLAUDE.md` instead.
