# Starting prompts

Copy-paste these, then edit. They are launch pads, not incantations — the second
prompt you write yourself is always better than the one you copied.

Every block below is a **prompt** (paste it into Claude Code) unless it's labelled
**In the shell**. On GitHub, hover a block and a copy icon appears top-right; in a Linux
terminal, paste with **Shift+Ctrl+V**.

Four habits worth forming today:

- **Give it a goal, not a procedure.** "Make the golden tests pass" beats a numbered
  list of edits. You are hiring a colleague, not writing a shell script.
- **Plan first on anything non-trivial.** Shift+Tab into plan mode, read the plan,
  push back on it, *then* let it run.
- **Say which workflow you want.** Left alone it branches and opens a PR. "Just commit
  to main, push, and close the issue" is a perfectly good instruction.
- **Put the standing rules in `CLAUDE.md`, not in every prompt.** Your fork name and
  your language live there, which is why none of the prompts below repeat them.

---

## Setup

Fork the repo yourself first, in a browser:
[github.com/SACGF/ai_agent_workshop](https://github.com/SACGF/ai_agent_workshop) →
**Fork** → **Create fork**. A restricted GitHub account fails at exactly this step,
and one click tells you so immediately — a 403 relayed through an agent doesn't.

Then turn on the Issues tab, which forks ship without: your fork → **Settings** →
**Features** → tick **Issues**.

Then these two, **in the shell**. Both need a browser or a human, so no prompt gets
you out of them:

```bash
gh auth login            # GitHub.com → HTTPS → yes to "Authenticate Git with your
                         #   GitHub credentials" → login with a web browser.
                         #   On the browser page, click the button and nothing else.
workshop-git-identity    # your git name and email, read back off GitHub
```

Then start `claude`, pick a theme, and `/login` with the Claude account on your card.

`!` runs a shell command from inside the session — try `!ls` and `!git status` before
anything else.

```text
Check this machine is ready for a workshop that uses Claude Code, `gh` and `bedtools`.
Verify `gh auth status`, `bedtools --version`, `git config --global user.email`, plus
`bcftools`, `samtools`, `Rscript` and `python3`. Report pass/fail for each. For anything
that fails, give me the exact command to type myself; don't try to fix it.
```

```text
I've already forked `SACGF/ai_agent_workshop` in the browser. Find it under my account
and clone it to `~/ai_agent_workshop` over HTTPS, with `origin` pointing at my fork and
`upstream` at SACGF. Then show me `git remote -v`, tell me my fork's full `owner/name`,
and print the URL of my fork's issues page so I can click it.
```

Then **quit** (`/exit` or Ctrl-D) and restart inside the clone — the agent can change
its own directory, not your shell's:

```bash
cd ~/ai_agent_workshop
claude
```

The repo root already has a `CLAUDE.md`; it's notes for the upstream template, not for
your project. Replace it:

```text
Overwrite the CLAUDE.md in the repo root with a copy of specs/CLAUDE.md.example. The one
there now is notes for the upstream template, not for my project, so replace it entirely
rather than merging. Then fill in the fork placeholder at the top with my actual fork
name.
```

Then pin the fork rule so it survives every `/clear`, using `#` from inside a session:

```text
# gh issue create and gh pr create always pass --repo <you>/ai_agent_workshop. Never write to SACGF.
```

---

## 0:15 — Warm-up

```text
What is in this repository? Read the README and specs/, then tell me in five bullet
points what I am supposed to build today. Don't write any code.
```

```text
Read `issues/` and file the three numbered 01-03 on my fork with `gh` — leave the
stretch ones for later. Show me the commands before you run them. When they're filed,
print the link to my fork's issues page.
```

Read the `--repo` in what it shows you. "Show me first" is the habit worth forming for
anything that writes to the network. Then open that link and look at the issues in the
browser — that list is the surface you and every agent share this afternoon.

Two languages, one diff. Use your language first, then one you don't read:

```text
Write `bottles.R` that prints the full lyrics of "99 Bottles of Beer" to stdout. Get the
bottom of the song right: "1 bottle" is singular, and zero is "no more bottles". Then
show me the last eight lines of its output.
```

Look at the code (`!cat bottles.R`), and if it's unfamiliar, ask for it in a language
you do know:

```text
Walk me through bottles.R as if I'm a Python programmer.
```

```text
Now write `bottles.py` — same output, and don't look at the R version while you do it.
Then diff the two outputs and tell me whether they are byte-identical.
```

```text
Introduce a single off-by-one into the Python version, show me the diff, then put it
back.
```

The diff is the point, and it is the same move as `mytools` against `bedtools` later.
You cannot read the second program; you can still prove it agrees with the first.

**Then choose the language for `mytools`** — see CHOOSE YOUR LANGUAGE in the README —
and write the decision down before you build anything:

```text
# mytools is written in <language>. Every subcommand and every test. Don't introduce a second language without asking me.
```

```text
Make `mytools --version` work. Keep it to one file, and stop as soon as
`mytools --version` prints something and exits 0. Don't implement any subcommands yet.
```

```text
Look at issue #1 on my fork. Is it actually done? Check the code, not your memory of
what you wrote. Then commit straight to main referencing the issue, push, and close the
issue.
```

That last one is the loop worth closing every time: issue → code → check → commit
referencing it → close. Say "commit to main" explicitly if you don't want the branch and
PR it would otherwise reach for.

---

## 0:35 — Brainstorm to spec

```text
I want to build a small bedtools-like CLI called `mytools`. Interview me one question at
a time until you can write a complete SPEC.md. Ask about scope, flags, formats, error
handling, and performance assumptions. Don't suggest answers until I've given mine. Then
write SPEC.md and stop.
```

One question at a time matters. Ask for "a spec" and you get a plausible-looking
document full of decisions you never made and won't remember agreeing to.

It will read `specs/mytools-spec-template.md` on its own — that's the skeleton, and
it's meant to.

**Punt freely.** "Do it like bedtools", "the simplest thing that works" and "whatever
you think" are complete answers. Spend your attention on the three or four decisions you
actually have an opinion about.

**Or ramble instead.** Dump everything you half-know into one long unstructured message,
then:

```text
That was a brain dump, not a spec. Play it back to me as a structured list of what I
seem to want, flag anything I contradicted myself on, then interview me one question at
a time on the gaps.
```

```text
Before we settle the spec: search the web for how bedtools actually defines `merge -d`
and whether bookended features merge at `-d 0`. Cite what you find, then tell me if my
draft SPEC.md contradicts it.
```

```text
Use `specs/mytools-spec-template.md` as the skeleton. Fill in only the decisions I've
actually made and leave the rest as `_______`, then show me what's still blank.
```

**Stalled at 0:50?** Stop, tell it to copy `specs/fallback-spec.md` to `SPEC.md`, and
move on — the spec is not the exercise, shipping is.

---

## 0:55 — Issues, then code

**Switch model first.** Breaking the spec into issues is planning, and planning is where
the stronger model pays for itself:

```text
/model
```

Discuss and plan with **Fable**; build with **Opus**; skip Sonnet today. Fable burns
tokens fast, so switch back once the thinking is done.

```text
Read SPEC.md. Break it into 5-7 GitHub issues, one per subcommand, each independently
implementable by someone who hasn't read the others. Give each one acceptance criteria
that reference the golden-test pattern in tests/README.md, then file them on my fork and
print the link to my issues page.
```

Independence is the point — you're about to run these in parallel and they must not
collide in the same file. Read them in the browser before you fan out.

Then set the parallel session up (you attach yourself — the panes are your job):

```text
Make three copies of this repo as siblings — `~/ws-sort`, `~/ws-merge` and
`~/ws-intersect` — and in each one create the branch for its issue: `feat/2-sort`,
`feat/3-merge`, `feat/4-intersect`. Then start a detached tmux session called `ws` with
one tiled pane per copy, each running `claude` in that directory. Don't attach — I'll do
that myself.
```

```text
Read SPEC.md, tests/README.md and CLAUDE.md. Plan the implementation of issue #N. Show
me the plan — files you'll create, the overlap predicate you'll use, and how you'll test
it. Don't write code yet.
```

Plan on Fable, then `/model` back to Opus to execute:

```text
Now implement the plan for issue #N. Run the golden tests before you tell me you're
done. Commit with a message referencing #N.
```

```text
That's implemented but the golden test for `merge -d 10` fails. Don't guess: run real
bedtools on the fixture, look at what it actually prints, and make ours match.
```

---

## 1:45 — Before you go outside

Something longer than the break, then `/remote-control` and out the door. It works
because you signed in with `/login` at setup — see the README's 1:45 block.

```text
Read SPEC.md and tests/README.md, then write golden tests for every subcommand I have so
far, diffing against real bedtools on data/a.bed and data/b.bed. Cover the bookended,
nested, identical, zero-length and position-0 cases. Run them, and fix what fails.
```

---

## 2:00 — PR and review

```text
Push this branch and open a PR against my fork. Write a description that says what
changed, what's tested, and what isn't.
```

Reviewing your partner's PR:

```text
Review PR #N on `<partner>/ai_agent_workshop` — that's a different fork to mine, so read
it there. Focus on interval overlap logic and BED coordinate handling — BED is 0-based
half-open, so look hard at every `<` and `<=`. Draft review comments and show them to me
before posting anything.
```

Read the diff yourself before you post what the agent drafted. Rubber-stamping an
agent's review of an agent's code is how the whole thing falls over.

---

## 2:00 — Guardrails

```text
Set up a test suite that compares `mytools` output to real bedtools on the files in
`data/`, following the pattern in tests/README.md. Cover every subcommand and flag in
SPEC.md, including reading from stdin. Add a linter. Then update
`.github/workflows/ci.yml` to run both on every push and PR.
```

Golden tests alone aren't the goal — ask for the other half:

```text
Now add unit tests. One per edge case in data/a.bed that I'd have to think about:
bookended intervals, zero-length, nested, position 0, and the overlap predicate itself.
They must run without bedtools installed, and each one should fail for exactly one
reason. Wire them into CI alongside the golden tests and the linter.
```

```text
Push that and watch the Actions run with `gh run watch`. If it fails, fix it and push
again until it's green.
```

Two blockers here that no prompt fixes, because they're GitHub permissions rather than
code: **Actions are disabled by default on a fork**, and pushing
`.github/workflows/ci.yml` needs a scope `gh auth login` didn't request. Both fixes are
in the README's [If GitHub gives you
trouble](README.md#if-github-gives-you-trouble).

Then break it on purpose:

```text
Introduce a subtle off-by-one bug in the interval overlap logic on a new branch — the
kind someone would write by mistake, not an obvious one. Open a PR for it and let's see
whether CI catches it.
```

If CI stays green, your tests are the problem, not the bug. Ask:

```text
CI passed. That's the real finding. What case would have caught this, and why isn't it
in the suite?
```

---

## 2:40 — Stretch goals

Pick one. They're independent.

**Gene lookup client**

```text
Read `specs/gene-api.openapi.yaml`. Write a client for the cdotlib.org backend described
in the "cdotlib.org client" section, exposing it as `mytools genes get --gene BRCA1`
which prints one BED line. Verify BRCA1 against `data/genes.bed`. Handle the
HTML-not-JSON error case.
```

```text
Now add `mytools genes closest --gene BRCA1 -b data/a.bed`, reusing the interval code we
already have rather than writing new overlap logic.
```

**Your own gene server**

```text
Read `specs/gene-api.openapi.yaml`. Build a server that implements that contract, backed
by `data/genes.gtf` (a real GENCODE v50 slice). Load the GTF into <Parquet / DuckDB /
Redis / SQLite> at startup, serve `/gene/{symbol}` and `/genes?region=`. Gene
coordinates are the MANE Select transcript span, NOT the `gene` row — check
tests/README.md. GTF is 1-based inclusive, the contract is 0-based half-open.
`data/genes.bed` is the golden answer: write a test that checks all 25 against it.
```

```text
Serve it on 0.0.0.0:8000 and tell me the exact URL others should use, given this VM's
public IP. Then post it as a comment on the shared GitHub issue.
```

**VCF forensics**

```text
Read the VCF 4.3 spec at https://samtools.github.io/hts-specs/VCFv4.3.pdf and enumerate
the rules a validator could actually check — header/data agreement, Number=A/R/G
cardinality, types, allele indices, coordinates, ordering. Give me the list and don't
write code yet. I'll pick which ones we implement.
```

```text
Implement those checks as `mytools vcf-validate`. For each rule, write a unit test with
a minimal VCF that violates it AND one that doesn't — a validator that flags everything
is worthless. Then run it on data/broken.vcf.
```

```text
We found N. The answer key says there are 13. Don't read the key — instead, tell me
which categories of rule we haven't implemented at all yet.
```

**Annotate real variants**

```text
Read `issues/06-annotate-real-variants.md`, then plan `mytools annotate`. Before you
write code: run `bedtools intersect -a data/genes.bed -b data/hg002.vcf.gz -c` and
`-wa -wb`, show me what they print, and tell me how bedtools decides the interval a
variant occupies — especially for the indels. Don't reason about it, measure it.
```

The measuring is the exercise. There are three coordinate systems in this repo and you
are about to join two of them.

```text
Now implement it, with golden tests against those two bedtools commands. Genes with zero
variants must still appear in the output — two of the 25 have none.
```

```text
Add `--confident data/hg002.highconf.bed`. 119 of the 2,436 variants fall outside those
regions; the flag should drop exactly those. Write the golden test first.
```

And the negative control the validator was missing:

```text
Run our `vcf-validate` on `data/hg002.vcf.gz`. It's a real, valid VCF, so anything it
reports is a bug in our rules, not in GIAB. Fix whatever fires, and add it to CI as a
must-be-silent case alongside `broken.vcf`.
```

**Real reads, real scale**

```text
`bedtools bamtobed -i /data/HG002.neighbourhoods.bam > reads.bed` gives me about half a
million intervals of real sequencing data. Run every golden test against it instead of
`data/a.bed`, time mine against real bedtools, and measure peak memory with
`/usr/bin/time -v`. Report the numbers before changing any code.
```

Numbers first. The temptation is to start optimising on a hunch, and the hunch is
usually wrong.

```text
`intersect` is the one that got slower faster than the others. Is my implementation
quadratic? Show me the loop structure and what bedtools does instead, then fix it
without breaking a single golden test.
```

```text
Update `SPEC.md`'s memory-model section to say what we actually do now. It currently
claims something we decided at 0:30 and never tested.
```

**A language you don't know**

```text
Reimplement `mytools sort` in Rust. I don't know Rust, so explain the parts I'd get
wrong. The golden tests must pass unchanged — don't touch them.
```

The golden tests are what make this safe: you can't read the code, but you can prove it
agrees with bedtools.

---

## When it goes wrong

```text
That's not what I asked for. Stop, re-read SPEC.md, and tell me what you think the
requirement is before you change any more code.
```

```text
You've been going in circles on this for a while. Summarise what you've tried, what the
actual error is, and what you'd need from me to get unstuck.
```

```text
Revert that. `git checkout -- .` and start again from the plan.
```

For GitHub itself misbehaving — login codes, missing Issues tab, disabled Actions,
workflow scope — see [If GitHub gives you
trouble](README.md#if-github-gives-you-trouble) in the README.
