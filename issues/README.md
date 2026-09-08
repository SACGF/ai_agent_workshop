# Issue texts

Forks don't copy issues, so your fork starts with an empty issue list. Re-filing these
on your own fork is the first exercise — hand the job to your agent (see the warm-up
prompts in `prompts.md`) rather than doing it by hand.

The three commands, if you want to run them yourself:

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

**`--repo "$FORK"` is not optional.** Without it `gh` targets the upstream template
and you'll file issues on everyone else's workshop.
