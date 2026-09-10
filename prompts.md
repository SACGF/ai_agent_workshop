# Starting prompts

Copy-paste these, then edit. They are launch pads, not incantations — the second
prompt you write yourself is always better than the one you copied.

Three habits worth forming today:

- **Give it a goal, not a procedure.** "Make the golden tests pass" beats a numbered
  list of edits. You are hiring a colleague, not writing a shell script.
- **Plan first on anything non-trivial.** Shift+Tab into plan mode, read the plan,
  push back on it, *then* let it run.
- **Put the standing rules in `CLAUDE.md`, not in every prompt.** Your fork name lives
  there, which is why none of the prompts below repeat it.

---

## Setup

Do these two first, in a plain shell — both need a browser or a human, so no prompt
gets you out of them:

```bash
gh auth login            # say yes to "Authenticate Git with your GitHub credentials"
workshop-git-identity    # your git name and email, read back off GitHub
```

> Check this machine is ready for a workshop that uses Claude Code, `gh` and
> `bedtools`. Verify `gh auth status`, `bedtools --version`, `git config --global
> user.email`, and that `ANTHROPIC_API_KEY` is set — check it's non-empty without
> printing it. Report pass/fail for each. For anything that fails, give me the exact
> command to type myself; don't try to fix it.

> Fork `github.com/SACGF/ai_agent_workshop` to my GitHub account and clone my fork to
> `~/ai_agent_workshop`, with `origin` pointing at my fork and `upstream` at SACGF.
> Then show me `git remote -v` and tell me my fork's full `owner/name`.

> Copy `specs/CLAUDE.md.example` to `CLAUDE.md` in the repo root, and fill in the fork
> placeholder at the top with my actual fork name.

Then pin it so it survives every `/clear`, using `#` from inside a session:

```
# gh issue create and gh pr create always pass --repo <you>/ai_agent_workshop. Never write to SACGF.
```

---

## 0:00 — Warm-up

> What is in this repository? Read the README and specs/, then tell me in five bullet
> points what I am supposed to build today. Don't write any code.

> Read `issues/` and file each of those three issues on my fork with `gh`. Show me the
> commands before you run them.

Read the `--repo` in what it shows you. "Show me first" is the habit worth forming for
anything that writes to the network.

> Make `mytools --version` work. Pick the language, keep it to one file, and stop as
> soon as `mytools --version` prints something and exits 0. Don't implement any
> subcommands yet.

---

## 0:20 — Brainstorm to spec

> I want to build a small bedtools-like CLI called `mytools`. Interview me one
> question at a time until you can write a complete SPEC.md. Ask about scope, flags,
> formats, error handling, and performance assumptions. Don't suggest answers until
> I've given mine. Then write SPEC.md and stop.

One question at a time matters. Ask for "a spec" and you get a plausible-looking
document full of decisions you never made and won't remember agreeing to.

> Before we settle the spec: search the web for how bedtools actually defines
> `merge -d` and whether bookended features merge at `-d 0`. Cite what you find,
> then tell me if my draft SPEC.md contradicts it.

> Use `specs/mytools-spec-template.md` as the skeleton. Fill in only the decisions
> I've actually made and leave the rest as `_______`, then show me what's still blank.

**Stalled at 0:45?** Stop, tell it to copy `specs/fallback-spec.md` to `SPEC.md`, and
move on — the spec is not the exercise, shipping is.

---

## 0:50 — Issues, then code

> Read SPEC.md. Break it into 5-7 GitHub issues, one per subcommand, each
> independently implementable by someone who hasn't read the others. Give each one
> acceptance criteria that reference the golden-test pattern in tests/README.md, then
> file them on my fork.

Independence is the point — you're about to run these in parallel and they must not
collide in the same file.

Then set the parallel session up (you attach yourself — the panes are your job):

> Make three copies of this repo as siblings — `~/ws-sort`, `~/ws-merge` and
> `~/ws-intersect` — and in each one create the branch for its issue: `feat/2-sort`,
> `feat/3-merge`, `feat/4-intersect`. Then start a detached tmux session called `ws`
> with one tiled pane per copy, each running `claude` in that directory. Don't attach
> — I'll do that myself.

> Read SPEC.md, tests/README.md and CLAUDE.md. Plan the implementation of issue #N.
> Show me the plan — files you'll create, the overlap predicate you'll use, and how
> you'll test it. Don't write code yet.

Then switch models — plan with the strong one, execute with the cheap one:

> /model
>
> Now implement the plan for issue #N. Run the golden tests before you tell me you're
> done. Commit with a message referencing #N.

> That's implemented but the golden test for `merge -d 10` fails. Don't guess: run
> real bedtools on the fixture, look at what it actually prints, and make ours match.

---

## 1:50 — PR and review

> Push this branch and open a PR against my fork. Write a description that says what
> changed, what's tested, and what isn't.

Reviewing your partner's PR:

> Review PR #N on `<partner>/ai_agent_workshop` — that's a different fork to mine, so
> read it there. Focus on interval overlap logic and BED coordinate handling — BED is
> 0-based half-open, so look hard at every `<` and `<=`. Draft review comments and show
> them to me before posting anything.

Read the diff yourself before you post what the agent drafted. Rubber-stamping an
agent's review of an agent's code is how the whole thing falls over.

---

## 1:50 — Guardrails

> Set up a test suite that compares `mytools` output to real bedtools on the files in
> `data/`, following the pattern in tests/README.md. Cover every subcommand and flag
> in SPEC.md, including reading from stdin. Add a linter. Then update
> `.github/workflows/ci.yml` to run both on every push and PR.

Golden tests alone aren't the goal — ask for the other half:

> Now add unit tests. One per edge case in data/a.bed that I'd have to think about:
> bookended intervals, zero-length, nested, position 0, and the overlap predicate
> itself. They must run without bedtools installed, and each one should fail for
> exactly one reason. Wire them into CI alongside the golden tests and the linter.

> Push that and watch the Actions run with `gh run watch`. If it fails, fix it and
> push again until it's green.

Two blockers here that no prompt fixes, because they're permissions rather than code.
Actions are **disabled by default on a fork** — click the button on your fork's
Actions tab. And if pushing `.github/workflows/ci.yml` is rejected with *refusing to
allow an OAuth App to create or update workflow*, run `gh auth refresh -s workflow`
and push again.

Then break it on purpose:

> Introduce a subtle off-by-one bug in the interval overlap logic on a new branch —
> the kind someone would write by mistake, not an obvious one. Open a PR for it and
> let's see whether CI catches it.

If CI stays green, your tests are the problem, not the bug. Ask:

> CI passed. That's the real finding. What case would have caught this, and why isn't
> it in the suite?

---

## 2:35 — Stretch goals

Pick one. They're independent.

**Gene lookup client**

> Read `specs/gene-api.openapi.yaml`. Write a client for the cdotlib.org backend
> described in the "cdotlib.org client" section, exposing it as
> `mytools genes get --gene BRCA1` which prints one BED line. Verify BRCA1 against
> `data/genes.bed`. Handle the HTML-not-JSON error case.

> Now add `mytools genes closest --gene BRCA1 -b data/a.bed`, reusing the interval
> code we already have rather than writing new overlap logic.

**Your own gene server**

> Read `specs/gene-api.openapi.yaml`. Build a server that implements that contract,
> backed by `data/genes.gtf` (a real GENCODE v50 slice). Load the GTF into <Parquet /
> DuckDB / Redis / SQLite> at startup, serve `/gene/{symbol}` and `/genes?region=`.
> Gene coordinates are the MANE Select transcript span, NOT the `gene` row — check
> tests/README.md. GTF is 1-based inclusive, the contract is 0-based half-open.
> `data/genes.bed` is the golden answer: write a test that checks all 25 against it.

> Serve it on 0.0.0.0:8000 and tell me the exact URL others should use, given this
> VM's public IP. Then post it as a comment on the shared GitHub issue.

**VCF forensics**

> Read the VCF 4.3 spec at https://samtools.github.io/hts-specs/VCFv4.3.pdf and
> enumerate the rules a validator could actually check — header/data agreement,
> Number=A/R/G cardinality, types, allele indices, coordinates, ordering. Give me the
> list and don't write code yet. I'll pick which ones we implement.

> Implement those checks as `mytools vcf-validate`. For each rule, write a unit test
> with a minimal VCF that violates it AND one that doesn't — a validator that flags
> everything is worthless. Then run it on data/broken.vcf.

> We found N. The answer key says there are 13. Don't read the key — instead, tell me
> which categories of rule we haven't implemented at all yet.

**A language you don't know**

> Reimplement `mytools sort` in Rust. I don't know Rust, so explain the parts I'd get
> wrong. The golden tests must pass unchanged — don't touch them.

The golden tests are what make this safe: you can't read the code, but you can prove
it agrees with bedtools.

---

## When it goes wrong

> That's not what I asked for. Stop, re-read SPEC.md, and tell me what you think the
> requirement is before you change any more code.

> You've been going in circles on this for a while. Summarise what you've tried, what
> the actual error is, and what you'd need from me to get unstuck.

> Revert that. `git checkout -- .` and start again from the plan.
