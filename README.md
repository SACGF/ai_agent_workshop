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

## Setup (15 minutes, do this first)

One click and four commands. They're here because each one needs a human; the agent
does everything after them.

**First, fork this repo in your browser.**
[github.com/SACGF/ai_agent_workshop](https://github.com/SACGF/ai_agent_workshop) →
**Fork** → **Create fork**. Keep the default name. Ten seconds.

Do this yourself rather than asking the agent to run `gh repo fork`. Forking is the
step a restricted GitHub account fails at — SSO-protected org, a fine-grained token
with no repo-creation rights, a policy against new public repos — and it fails before
anything else can work. In a browser you find out in one click and can switch to a
personal account; through the agent you get a 403 that it will cheerfully try three
ways around while your twenty minutes go.

**Then, on the VM:**

```bash
gh auth login            # browser on your laptop, code from this terminal.
                         #   Say yes to "Authenticate Git with your GitHub
                         #   credentials" — without it, git push has no password.
workshop-git-identity    # sets your git name and email from your GitHub account
claude --version         # must print a version — everything below depends on it
claude                   # start it, from anywhere
```

`gh auth login` needs a browser you are sitting in front of, and an unset git identity
doesn't fail until your first commit twenty minutes from now — so get both out of the
way while nothing depends on them.

**If your GitHub account is locked down**, the three places it bites, in order:

| Symptom | Fix |
|---|---|
| Can't fork at all | Use a personal account, or grab an organiser. Nothing today touches an org repo. |
| `gh` 403s on the org | Authorise the token for your org — GitHub shows the link in the error. |
| `push` refused on `.github/workflows/` | `gh auth refresh -s workflow`, then push again. Bites at 2:00, not now. |

Then, in Claude Code:

> Check this machine is ready for a workshop that uses Claude Code, `gh` and
> `bedtools`. Verify `gh auth status`, `bedtools --version`, `git config --global
> user.email`, and that `ANTHROPIC_API_KEY` is set — check it's non-empty without
> printing it. Report pass/fail for each. For anything that fails, give me the exact
> command to type myself; don't try to fix it.

Now have it clone the fork you made:

> I've already forked `SACGF/ai_agent_workshop` in the browser. Find it under my
> account and clone it to `~/ai_agent_workshop`, with `origin` pointing at my fork and
> `upstream` at SACGF. Then show me `git remote -v` and tell me my fork's full
> `owner/name`.

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
| 0:00–0:15 | Setup |
| 0:15–0:35 | Warm-up: two languages, one diff |
| 0:35–0:55 | Brainstorm → spec |
| 0:55–1:45 | Spec → issues → code, in parallel |
| 1:45–2:00 | Break — on the balcony, with your agent |
| 2:00–2:40 | PRs, review, and guardrails |
| 2:40–3:20 | Stretch goals |
| 3:20–3:30 | Wrap-up |

Prompts for every exercise are in [`prompts.md`](prompts.md). Copy them, then edit —
they're launch pads, not magic words.

Each block ends with a **Done when** you can check yourself. Those checks are the only
shell you need; run them, because "the agent said it did" and "it is done" are not the
same claim.

---

### 0:15–0:35 · Warm-up: two languages, one diff

**Goal.** Let the agent drive something you already know the right answer to, and learn
today's one trick: verify by diffing, not by reading.

First, your issues. Forks don't copy them, so yours has none right now — the texts are
in [`issues/`](issues/):

> Read `issues/` and file the three numbered 01-03 on my fork with `gh` — leave the
> stretch ones for later. Show me the commands before you run them.

"Show me first" is the habit worth forming for anything that writes to the network.
Read the `--repo` flag in what it shows you.

Now the warm-up proper. *99 Bottles of Beer*, in the language you reach for without
thinking:

> Write `bottles.R` that prints the full lyrics of "99 Bottles of Beer" to stdout.
> Get the bottom of the song right: "1 bottle" is singular, and zero is "no more
> bottles". Then show me the last eight lines of its output.

Read those eight lines yourself, because the bottom of that song is nothing but edge
cases — a plural that stops being plural, and a count that ends in a word instead of a
number. That is the same shape as the bug you are going to spend all afternoon not
writing: **BED intervals are 0-based half-open**, and most wrong answers in this
workshop are an off-by-one at a boundary.

Then the same program again, in a language you don't use:

> Now write `bottles.py` — same output, and don't look at the R version while you do
> it. Then diff the two outputs and tell me whether they are byte-identical.

```bash
diff <(Rscript bottles.R) <(python3 bottles.py) && echo identical
```

**That diff is the whole workshop in one command.** You can't review the second
program — you don't know the language well enough — but you can prove it agrees with
one you can. Every correctness claim today has this shape: `mytools` against
`bedtools`, byte for byte. The only thing that changes after the warm-up is that the
reference implementation is someone else's and the edge cases are intervals.

Thirty seconds more, and worth it:

> Introduce a single off-by-one into the Python version, show me the diff, then put it
> back.

Notice how precisely the diff says *that* something is wrong, and how little it says
about *where*. That's the 2:00 guardrails exercise in miniature, before you've written
anything real.

Finally, the warm-up issue itself:

> Make `mytools --version` print a version and exit 0. One file, any language, no
> subcommands yet. Stop as soon as that works.

**Done when** three issues are listed, two languages agree, and the binary runs:

```bash
gh issue list --repo "$(gh api user --jq .login)/ai_agent_workshop"
diff <(Rscript bottles.R) <(python3 bottles.py) && echo identical
mytools --version
```

Swap in your own two languages — Rust is installed, and an agent will happily install
anything else. The further the second one is from your comfort zone, the better the
lesson.

---

### 0:35–0:55 · Brainstorm → spec

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

**Stalled at 0:50?** Tell the agent to copy `specs/fallback-spec.md` to `SPEC.md` and
move on. The spec is not the exercise.

**Done when** `SPEC.md` is in your repo root with no decisions left blank:

```bash
grep -c '_____' SPEC.md    # want 0
```

---

### 0:55–1:45 · Issues → code, in parallel

**Goal.** Several subcommands built at once, by several agents, and you supervising.

Turn the spec into issues:

> Read SPEC.md. Break it into 5-7 GitHub issues, one per subcommand, each
> independently implementable by someone who hasn't read the others. Give each one
> acceptance criteria that reference the golden-test pattern in tests/README.md, then
> file them on my fork.

Then **plan with a strong model, execute with a cheap one.** Use `/model` to switch.
Planning is where the money earns its keep; typing out the plan is not.

Now go parallel — see [Working at agentic speed](#working-at-agentic-speed) below.
One copy of the repo and one Claude Code session per subcommand.

**Done when** two or more subcommands are implemented on separate branches and you've
run the golden test seed against at least one of them:

```bash
for d in ~/ws-*; do echo "$d  $(git -C "$d" branch --show-current)"; done
```

---

### 1:45–2:00 · Break — on the balcony, with your agent

**Goal.** Fresh air, and the point of the whole day: the work continues while you are
not at the keyboard.

Before you stand up, give it something that takes longer than the break:

> Read SPEC.md and tests/README.md, then write golden tests for every subcommand I
> have so far, diffing against real bedtools on data/a.bed and data/b.bed. Cover the
> bookended, nested, identical, zero-length and position-0 cases. Run them, and fix
> what fails.

Then go outside. You are not abandoning it — you are taking it with you.

**Remote Control** connects the session on your VM to the Claude app on your phone, or
to a browser at [claude.ai/code](https://claude.ai/code). The code, the filesystem and
the execution all stay on the VM; the phone is another keyboard and screen for the
session already running.

```
/remote-control
```

Accept the one-time confirmation, and a status panel appears with the session URL and
a QR code. Scan it — install the app first,
[iOS](https://apps.apple.com/us/app/claude-by-anthropic/id6473753684) or
[Android](https://play.google.com/store/apps/details?id=com.anthropic.claude) — and
the conversation is in your hand, live, with your VM behind it.

**One catch, and you need it before you try.** Remote Control needs a Claude Pro, Max,
Team or Enterprise login. **API keys are not supported**, and your VM runs on a
workshop API key, so out of the box `/remote-control` will refuse.

- **If you have a Pro or Max subscription**, in the shell you start `claude` from:
  `unset ANTHROPIC_API_KEY`, then `claude`, then `/login`, then `/remote-control`.
  That session now bills to your personal subscription rather than the workshop key,
  which also means it won't appear in the 3:20 cost tally. Worth it once, to see it.
- **If you don't**, it's demoed from the front, and nothing later in the day depends
  on it. Take the break.

`tmux` is what makes any of this safe: walking out of wifi range kills your SSH
connection, not your session. If you skipped it at login, start it now and re-run your
agent inside it.

**Done when** you're back, and something finished without you:

```bash
tmux attach
```

---

### 2:00–2:40 · PRs, review, guardrails

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

Two things bite everyone here, both one command each. **Forks ship with Actions
disabled** — open your fork's Actions tab in a browser and click the button, or
nothing you push will ever run. And pushing a change to `.github/workflows/` needs a
scope `gh auth login` didn't ask for; if you see *refusing to allow an OAuth App to
create or update workflow*, that's it:

```bash
gh auth refresh -s workflow
```

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

### 2:40–3:20 · Stretch goals

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

**Annotate real variants.** `data/hg002.vcf.gz` is 2,436 real calls from GIAB's HG002
benchmark over the same four neighbourhoods as `genes.bed`, and
`data/hg002.highconf.bed` is the 387 regions GIAB stands behind. Which variants hit
which gene, and which of those can you trust?

That's the interval code you wrote this morning, doing a real job — with three
coordinate systems in play at once (VCF 1-based, BED 0-based half-open, GTF 1-based
inclusive), and indel spans defined by REF length rather than ALT. bedtools reads VCF
natively, so it's still the oracle. Full brief in
[`issues/06-annotate-real-variants.md`](issues/06-annotate-real-variants.md).

It also gives the VCF validator above something it badly needs: a **valid** VCF. A
rule that fires on `broken.vcf` and also fires on the GIAB truth set is a broken rule,
and without a negative control you'd never know.

**Real reads, real scale.** Everything you've tested against so far fits on one
screen — deliberately, because that's what makes the golden tests checkable by eye.
`/data/HG002.neighbourhoods.bam` is the other end: real GIAB HG002 reads over the same
four neighbourhoods as `genes.gtf`, at ~70x. One command makes it something `mytools`
already understands:

```bash
bedtools bamtobed -i /data/HG002.neighbourhoods.bam > reads.bed   # ~500,000 intervals
```

Then find out whether your `SPEC.md` was telling the truth about memory, and whether
your `intersect` is quadratic. Being slower than bedtools is fine — it's C and you're
not. Being *quadratic* is the finding. Full brief in
[`issues/05-real-data-scale.md`](issues/05-real-data-scale.md).

**Implement a subcommand in a language you don't know.** Rust, Go, Julia, whatever.
The golden tests diff bytes against bedtools, so they transfer unchanged. You can't
read the code, but you can prove it's correct. That's the point.

**Claude Code from your phone.** Covered at the 1:45 break, and demoed from the front.
If you got `/remote-control` working then, the interesting version of this stretch goal
is to run the rest of the afternoon from the phone and see which parts of supervision
survive a 6-inch screen.

---

### 3:20–3:30 · Wrap-up

What your afternoon cost: [platform.claude.com/usage](https://platform.claude.com/usage),
and `/usage` in any session still open. Worth seeing the number next to what you built.

---

## Claude Code survival card

| | |
|---|---|
| **Shift+Tab** | Plan mode. It thinks and proposes, changes nothing. Use it for anything non-trivial. |
| **Esc** | Interrupt. Not a crash — it stops and waits. Use it early, the moment it's off track. |
| **Esc Esc** | Edit your previous message and rerun from there. |
| **`/model`** | Switch models. Plan on the strong one, execute on the cheap one. |
| **`/clear`** | Wipe the conversation. Between unrelated tasks, do this. |
| **`/usage`** | Tokens and dollars for this session, per model. Look after anything that felt expensive. |
| **`/context`** | What's eating your context window right now. |
| **`#`** | Prefix a message to save it to `CLAUDE.md` as a standing instruction. |
| **`/init`** | Generate a `CLAUDE.md` for an existing codebase. |
| **`claude -p "..."`** | One-shot, non-interactive. Pipes and scripts. |
| **`/remote-control`** | Hand the session to your phone. Needs a Pro/Max login — see the 1:45 break. |

**`CLAUDE.md`** — yours came from `specs/CLAUDE.md.example` at setup. Anything you'd
otherwise retype goes in it. Add with `#`, or just edit the file.

**Give it a goal, not a procedure.** "Make the golden tests pass" gets you further
than a numbered list of edits. If you find yourself writing the steps, you're doing
the work twice.

**Interrupt early.** A wrong turn caught in ten seconds costs ten seconds. The same
turn caught in three minutes costs a `git checkout`.

**Ask before it writes to the network.** "Show me the commands first" on anything
touching `gh`, and read the `--repo` in what comes back.

**`/usage` resets on `/clear`.** The session figure is what that conversation cost, not
what your afternoon cost — the console number at 3:20 is the total. Check `/usage`
after a long parallel run anyway: three agents on Opus is a different number from one
on Sonnet, and seeing it once is how the habit of `/model` sticks.

---

## Working at agentic speed

One agent is faster than you. Three agents are faster than you can read. The binding
constraint stops being typing and becomes *supervision*, which is a different skill —
these are the mechanics for it.

Agents collide if they share a directory, so give each one its own copy of the repo.
Not a clever mechanism — literally three copies:

> Make three copies of this repo as siblings — `~/ws-sort`, `~/ws-merge` and
> `~/ws-intersect` — and in each one create the branch for its issue: `feat/2-sort`,
> `feat/3-merge`, `feat/4-intersect`. Then start a detached tmux session called `ws`
> with one tiled pane per copy, each running `claude` in that directory. Don't attach
> — I'll do that myself.

<details>
<summary>What that runs, if you want to read it first</summary>

```bash
cp -r ~/ai_agent_workshop ~/ws-sort      && git -C ~/ws-sort      checkout -b feat/2-sort
cp -r ~/ai_agent_workshop ~/ws-merge     && git -C ~/ws-merge     checkout -b feat/3-merge
cp -r ~/ai_agent_workshop ~/ws-intersect && git -C ~/ws-intersect checkout -b feat/4-intersect

tmux new-session -d -s ws -c ~/ws-sort
tmux split-window -h -t ws -c ~/ws-merge
tmux split-window -v -t ws -c ~/ws-intersect
tmux select-layout -t ws tiled
tmux send-keys -t ws.0 claude Enter
tmux send-keys -t ws.1 claude Enter
tmux send-keys -t ws.2 claude Enter
```

</details>

The repo is 9MB, so this costs milliseconds. Each copy is an ordinary repo with `origin`
already pointing at your fork, so `gh pr create` works in every pane exactly as it did
in the first one. There is nothing new to learn here, which is
the point — `git worktree` does the same job more elegantly and is worth your time
*after* today, but not during it.

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

Two things follow from the copies being independent. Your branches live in three
separate repos, so no single `git branch` shows them all — your fork is where they meet,
once pushed. And a copied Python virtualenv doesn't work: `.venv` has absolute paths
baked in. `mytools` is standard-library-only so nothing this hour needs one, but if a
copy wants one, recreate it there rather than trusting the one that came along.

When a branch is done, tell that pane to push and open a PR against your fork. Then
`rm -rf ~/ws-sort` — the work is on GitHub, and the copy was always disposable.

**Supervising three agents.** Zoom into one pane at a time; three scrolling logs is
noise, not information. Let plan mode finish before you approve anything. Keep issues
touching separate files — the parallelism is only free while they don't collide. And
when two agents disagree about something in `SPEC.md`, that's the spec's fault, not
theirs: fix the spec, then tell them both.

---

## Taking it home

Today's VM is disposable, which is the only reason we've been this relaxed. It
holds nothing but a fork you can re-clone, and it gets deleted at 3:20. Your own
machine is not like that: the agent runs with your SSH keys, your cloud
credentials, your access to whatever is in `~/.ssh` and `~/.aws`. The code is in
git and safe. The credentials sitting next to it are the thing worth thinking
about.

The cheapest containment that actually works is a **separate user account**:

```bash
sudo adduser claude          # its own home, its own gh auth, no sudo
sudo -iu claude              # a login shell — plain `su claude` leaves you in
                             #   your own home with your own environment
```

Do the agent's work in there. It gets its own `gh auth login`, ideally a
fine-grained token limited to the repos it needs, and no path to your keys. You
pay one login hop and lose nothing else. A devcontainer or a VM draws a harder
boundary if you want one, at more friction.

Be clear about what this buys. It contains the *filesystem*, not the
*authority*: whatever you grant that account, the agent has. A token that can
push to main can push to main. Scope the token, not just the home directory.

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
  hg002.vcf.gz                  2,436 real GIAB HG002 calls, same 4 neighbourhoods
  hg002.highconf.bed            GIAB's high-confidence regions over those, 387 rows
tests/
  README.md                     the golden-test pattern + one worked example
issues/                         issue texts to re-file on your fork
setup/                          how this VM was built — cloud-init and a script
.github/workflows/ci.yml        CI skeleton — currently echoes "no tests yet"
```

There is no `mytools` here. That's yours to build.

Also on the VM, outside the repo, there's **`/data`** — GRCh38 with a `.fai` and a
`chrom.sizes`, for the bedtools subcommands that want real sequence or chromosome
lengths (`getfasta`, `nuc`, `slop -g`, `complement -g`). Same GENCODE release as
`data/genes.gtf`, so the coordinates agree:

```bash
bedtools getfasta -fi /data/GRCh38.fa -bed data/genes.bed -name | head
bedtools bamtobed -i /data/HG002.neighbourhoods.bam | wc -l    # ~500,000
```

`/data/HG002.neighbourhoods.bam` is real GIAB HG002 reads sliced to the four gene
neighbourhoods in `genes.gtf`. `/data/README.md` on the VM has the details.

Mind the two directories. `/data` is the reference genome, read-only. `data/` in this
repo is the fixtures. If you say "the data directory" to an agent it will guess, so
say which one.

## Licence

MIT — see [LICENSE](LICENSE).
