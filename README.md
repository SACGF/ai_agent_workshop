# Agentic Coding for Bioinformaticians

A 3.5-hour hands-on workshop. You will build a small reimplementation of bedtools —
`mytools`, with subcommands like `sort`, `merge`, `intersect`, `subtract`, `closest` —
without writing much of it yourself. Real `bedtools` is installed on your VM, so every
correctness question has an oracle: your output either matches it or it doesn't. That
frees you to work on the thing this workshop is actually about, which is not BED files.
It's how to specify, parallelise, review and guard work that an agent does faster than
you can read it.

You keep everything you build. Fork, work in your fork, and take it home.

---

## A note on the commands in this document

There are very few, and that's deliberate. Nearly everything here is a **prompt** —
something you say to the agent in English — because saying what you want is the skill
we're here to practise. Copy-pasting shell is not.

Literal commands appear in exactly two places:

- **Bootstrap**, where there is no agent yet, or the step needs a human (a browser
  login, a terminal you have to be sitting in).
- **Gates**, the `Done when` check at the end of each block. Those verify reality
  rather than the agent's account of it, which is a distinction worth internalising
  early.

Everything else, tell it.

---

## Setup (10 minutes, do this first)

Two commands. The agent does the rest.

```bash
claude --version     # must print a version — everything below depends on it
claude               # start it, from anywhere
```

Then, in Claude Code:

> Check this machine is ready for a workshop that uses Claude Code, `gh` and
> `bedtools`. Verify `gh auth status`, `bedtools --version`, and that
> `ANTHROPIC_API_KEY` is set — check it's non-empty without printing it. Report
> pass/fail for each. For anything that fails, give me the exact command to type
> myself; don't try to fix it.

`gh auth login` is the one it can't do for you — it needs a browser. Everything else
it can diagnose.

Now have it fork this repo:

> Fork `github.com/SACGF/ai_agent_workshop` to my GitHub account and clone my fork to
> `~/ai_agent_workshop`, with `origin` pointing at my fork and `upstream` at SACGF.
> Then show me `git remote -v` and tell me my fork's full `owner/name`.

The agent can change its own working directory but not your shell's, so move into the
clone and restart there — from now on it starts every session already knowing the
project:

```bash
cd ~/ai_agent_workshop && claude
```

> Read the README and specs/, then tell me in five bullet points what I'm supposed to
> build today. Don't write any code.

### Fork safety — do this before anything touches `gh`

Everything you do today happens on **your fork**. Get this wrong and you file issues
and PRs on the shared template that thirty other people are working from.

The trap is quiet. `gh` with an empty or missing `--repo` doesn't fail — it silently
falls back to whatever the git remote resolves to, exit code 0, no warning. So don't
rely on remembering the flag, and don't rely on a shell variable either: one you
export inside an agent session is gone by its next command.

Put it somewhere the agent re-reads on every single turn instead. Copy the conventions
file into place:

> Copy `specs/CLAUDE.md.example` to `CLAUDE.md` in the repo root, and fill in the fork
> placeholder at the top with my actual fork name.

`CLAUDE.md` is read automatically at the start of every session — conventions,
gotchas, how to run the tests, anything you'd otherwise retype. It's the
highest-leverage file in the repo: one line there beats repeating yourself in thirty
prompts, and it survives every `/clear`.

The fork rule is already in the copy you just made. Add to it with `#`, which appends
a standing instruction without leaving the session — worth doing once now, on the rule
you most need to hold, in your own words:

```
# gh issue create and gh pr create always pass --repo <you>/ai_agent_workshop. Never write to SACGF.
```

**Done when** `origin` is your fork and `CLAUDE.md` names it:

```bash
git remote -v
grep -n 'your-github-username' CLAUDE.md    # want no output — placeholder replaced
```

---

## The agenda

| Time | What |
|---|---|
| 0:00–0:20 | Setup + first task |
| 0:20–0:50 | Brainstorm → spec |
| 0:50–1:50 | Spec → issues → code, in parallel |
| 1:50–2:35 | PRs, review, and guardrails |
| 2:35–3:20 | Stretch goals |
| 3:20–3:30 | Wrap-up |

Prompts for every exercise are in [`prompts.md`](prompts.md). Copy them, then edit —
they're launch pads, not magic words.

Each block ends with a **Done when** you can check yourself. Those checks are the only
shell you need; run them, because "the agent said it did" and "it is done" are not the
same claim.

---

### 0:00–0:20 · First task

**Goal.** Get from empty repo to a working command with an agent driving, and file
your issues.

Forks don't copy issues, so yours has none right now. The issue texts are in
[`issues/`](issues/) — have the agent re-file them:

> Read `issues/` and file each of those three issues on my fork with `gh`. Show me the
> commands before you run them.

That "show me first" habit is worth keeping for anything that writes to the network.
Read the `--repo` flag in what it shows you.

Then the warm-up issue itself:

> Make `mytools --version` print a version and exit 0. One file, any language, no
> subcommands yet. Stop as soon as that works.

**Done when** three issues are listed and the binary runs:

```bash
gh issue list --repo "$(gh api user --jq .login)/ai_agent_workshop"
mytools --version
```

---

### 0:20–0:50 · Brainstorm → spec

**Goal.** A `SPEC.md` that answers every question five parallel agents are about to ask.

Have the agent interview you — **one question at a time**:

> I want to build a small bedtools-like CLI called `mytools`. Interview me one
> question at a time until you can write a complete SPEC.md. Ask about scope, flags,
> formats, error handling, and performance assumptions. Don't suggest answers until
> I've given mine. Then write SPEC.md and stop.

The decisions are yours, and they're real: which subcommands, which flag subset,
streaming or in-memory, BED-only or GFF3 too, exit code semantics, `-header` handling.
`specs/mytools-spec-template.md` is the skeleton. Ask it to do a quick web search on
how bedtools actually defines `merge -d` before you commit to an answer.

Your `CLAUDE.md` is already in place from setup. Read it now if you haven't — it's a
worked example of the genre, and it's shaping every answer you get today. Add to it as
your design firms up, with `#` or by editing it directly.

**Stalled at 0:45?** Tell the agent to copy `specs/fallback-spec.md` to `SPEC.md` and
move on. The spec is not the exercise.

**Done when** `SPEC.md` is in your repo root with no decisions left blank:

```bash
grep -c '_____' SPEC.md    # want 0
```

---

### 0:50–1:50 · Issues → code, in parallel

**Goal.** Several subcommands built at once, by several agents, and you supervising.

Turn the spec into issues:

> Read SPEC.md. Break it into 5-7 GitHub issues, one per subcommand, each
> independently implementable by someone who hasn't read the others. Give each one
> acceptance criteria that reference the golden-test pattern in tests/README.md, then
> file them on my fork.

Then **plan with a strong model, execute with a cheap one.** Use `/model` to switch.
Planning is where the money earns its keep; typing out the plan is not.

Now go parallel — see [Working at agentic speed](#working-at-agentic-speed) below.
One worktree and one Claude Code session per subcommand.

**Done when** two or more subcommands are implemented on separate branches and you've
run the golden test seed against at least one of them:

```bash
git branch --list 'feat/*'
```

---

### 1:50–2:35 · PRs, review, guardrails

**Goal.** A green CI that catches a bug you plant on purpose.

Open PRs on your own fork:

> Push this branch and open a PR against my fork. Write a description that says what
> changed, what's tested, and what isn't.

**Pair up.** Swap fork names with the person next to you and review each other's:

> Review PR #N on `<partner>/ai_agent_workshop`. Fetch the diff, then focus on interval
> overlap logic and BED coordinate handling — BED is 0-based half-open, so look hard at
> every `<` and `<=`. Draft review comments and show them to me before posting
> anything.

Read the diff yourself before posting what your agent drafted. Rubber-stamping an
agent's review of an agent's code is how the whole thing falls over.

**Guardrails.** This is where the day is heading, so give it the time. Three things
running automatically on every push:

1. **Golden tests** — the worked example in `tests/README.md` grown into a real suite.
2. **Unit tests** — one per edge case you had to think about, running without bedtools.
3. **A linter** — with its config committed.

`.github/workflows/ci.yml` currently just echoes "no tests yet". Replacing that with
all three is the exercise. `tests/README.md` explains why you want both kinds of test
and not just the golden ones.

**Then break it on purpose:**

> Introduce a subtle off-by-one bug in the interval overlap logic on a new branch —
> the kind someone would write by mistake, not an obvious one. Open a PR for it and
> let's see whether CI catches it.

If CI goes red, the guardrail works. If it stays **green**, that's the more useful
result: your suite has a hole. Find the case that would have caught it.

**Done when** CI is green on a real PR and you've watched it react to a planted bug:

```bash
gh run list --repo "$(gh api user --jq .login)/ai_agent_workshop" --limit 5
```

---

### 2:35–3:20 · Stretch goals

Self-directed. Pick one, they're independent.

**Gene lookup over REST.** Add `mytools genes closest --gene BRCA1`, resolving a
symbol to coordinates over HTTP and then reusing your interval code. The contract is
[`specs/gene-api.openapi.yaml`](specs/gene-api.openapi.yaml):
`/gene/BRCA1` → `{symbol, chrom, start, end, strand}`, 0-based half-open like BED.

Two implementations sit behind that one shape, and swapping between them is a
base-URL change:

- **cdotlib.org** — real, public, always up, no auth. It serves *cdot's* API rather
  than ours, so it needs a small translating client. The spec tells you the single
  request to make and the two gotchas that will bite you.
- **Your own server** — see below.

**Build the gene server.** Implement that contract yourself, backed by
[`data/genes.gtf`](data/genes.gtf) — a real slice of GENCODE v50, 9,354 records across
the TP53, BRCA1, EGFR and CFTR neighbourhoods, with all the attribute mess that
implies. Load it into Parquet, DuckDB, Redis, SQLite, a plain dict — whatever you feel
like trying — and serve `/gene/{symbol}`. FastAPI or R plumber both work.

[`data/genes.bed`](data/genes.bed) is the golden answer for the 25 genes with a MANE
Select transcript. Two things will bite you, both real: a gene's `gene` row is a wider
span than its MANE transcript, and **GTF is 1-based inclusive while BED and this
contract are 0-based half-open**. That second one is the same off-by-one as the
morning's exercise.

Serve on `0.0.0.0:8000`, post your VM's URL in the shared issue, and others can
repoint at you with one line. Nobody is ever blocked on this — cdotlib.org is always
there.

**VCF forensics.** [`data/broken.vcf`](data/broken.vcf) is 20,002 variants.
`bcftools view` reads it and exits 0. `pysam` parses every record without complaint.
It is still out of spec in **13 places**, and seven of those are invisible to every
tool on this VM.

Write a validator that finds them, with unit tests. This is the one exercise with no
oracle — `bcftools` is a parser, not a validator, so the only way to know your checks
are right is to test them directly. Score yourself against the ROT13'd answer key when
you're done. Full brief in [`issues/04-vcf-forensics.md`](issues/04-vcf-forensics.md).

**Implement a subcommand in a language you don't know.** Rust, Go, Julia, whatever.
The golden tests diff bytes against bedtools, so they transfer unchanged. You can't
read the code, but you can prove it's correct. That's the point.

**Claude Code from your phone.** Demo from the front.

---

### 3:20–3:30 · Wrap-up

What your afternoon cost: [console.anthropic.com](https://console.anthropic.com) →
Usage. Worth seeing the number next to what you built.

---

## Claude Code survival card

| | |
|---|---|
| **Shift+Tab** | Plan mode. It thinks and proposes, changes nothing. Use it for anything non-trivial. |
| **Esc** | Interrupt. Not a crash — it stops and waits. Use it early, the moment it's off track. |
| **Esc Esc** | Edit your previous message and rerun from there. |
| **`/model`** | Switch models. Plan on the strong one, execute on the cheap one. |
| **`/clear`** | Wipe the conversation. Between unrelated tasks, do this. |
| **`#`** | Prefix a message to save it to `CLAUDE.md` as a standing instruction. |
| **`/init`** | Generate a `CLAUDE.md` for an existing codebase. |
| **`claude -p "..."`** | One-shot, non-interactive. Pipes and scripts. |

**`CLAUDE.md`** — yours came from `specs/CLAUDE.md.example` at setup. Anything you'd
otherwise retype goes in it. Add with `#`, or just edit the file.

**Give it a goal, not a procedure.** "Make the golden tests pass" gets you further
than a numbered list of edits. If you find yourself writing the steps, you're doing
the work twice.

**Interrupt early.** A wrong turn caught in ten seconds costs ten seconds. The same
turn caught in three minutes costs a `git checkout`.

**Ask before it writes to the network.** "Show me the commands first" on anything
touching `gh`, and read the `--repo` in what comes back.

---

## Working at agentic speed

One agent is faster than you. Three agents are faster than you can read. The binding
constraint stops being typing and becomes *supervision*, which is a different skill —
these are the mechanics for it.

Independent issues get one `git worktree` each, so three agents edit three checkouts
of your repo without colliding. Each is a full working tree sharing one `.git`;
branches stay independent, no stashing. Have the agent set that up:

> Create three git worktrees as siblings of this repo — `../ws-sort` on branch
> `feat/2-sort`, `../ws-merge` on `feat/3-merge`, `../ws-intersect` on
> `feat/4-intersect`. Then start a detached tmux session called `ws` with one tiled
> pane per worktree, each running `claude` in that directory. Don't attach — I'll do
> that myself.

<details>
<summary>What that runs, if you want to read it first</summary>

```bash
git worktree add ../ws-sort      -b feat/2-sort
git worktree add ../ws-merge     -b feat/3-merge
git worktree add ../ws-intersect -b feat/4-intersect

tmux new-session -d -s ws -c "$PWD/../ws-sort"
tmux split-window -h -t ws -c "$PWD/../ws-merge"
tmux split-window -v -t ws -c "$PWD/../ws-intersect"
tmux select-layout -t ws tiled
tmux send-keys -t ws.0 claude Enter
tmux send-keys -t ws.1 claude Enter
tmux send-keys -t ws.2 claude Enter
```

</details>

Then attach, because this part is yours — the panes are your supervision surface and
nothing can sit in them for you:

```bash
tmux attach -t ws
```

tmux, briefly: **Ctrl-b o** next pane, **Ctrl-b z** zoom one pane full-screen (again to
unzoom), **Ctrl-b d** detach and leave everything running, `tmux attach -t ws` to come
back.

Give each pane one issue: *"Implement issue #3. Read SPEC.md, CLAUDE.md and
tests/README.md first. Run the golden tests before you say you're done."*

When a branch is done, tell that pane to push and open a PR, then clean up the tree —
`git worktree remove ../ws-sort` from the main clone.

**Supervising three agents.** Zoom into one pane at a time; three scrolling logs is
noise, not information. Let plan mode finish before you approve anything. Keep issues
touching separate files — the parallelism is only free while they don't collide. And
when two agents disagree about something in `SPEC.md`, that's the spec's fault, not
theirs: fix the spec, then tell them both.

---

## What's in this repo

```
README.md                       this file — the agenda and the exercises
prompts.md                      copy-pasteable starting prompts per exercise
CLAUDE.md                       notes for this template; you overwrite it at setup
specs/
  CLAUDE.md.example             your project conventions — copied to root at setup
  mytools-spec-template.md      skeleton spec, decisions left blank
  fallback-spec.md              complete spec, if you stall
  gene-api.openapi.yaml         REST contract for the gene lookup
data/
  a.bed, b.bed                  BED6 fixtures, edge cases, deliberately unsorted
  genes.bed                     25 MANE Select gene spans, derived from genes.gtf
  genes.gtf                     real GENCODE v50 slice, 4 neighbourhoods, 1-based
  broken.vcf                    20k variants, 13 planted spec violations
  broken.vcf.answers.rot13      the answer key, ROT13'd
tests/
  README.md                     the golden-test pattern + one worked example
issues/                         issue texts to re-file on your fork
.github/workflows/ci.yml        CI skeleton — currently echoes "no tests yet"
```

There is no `mytools` here. That's yours to build.

## Licence

MIT — see [LICENSE](LICENSE).
