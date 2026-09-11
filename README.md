# Agentic Coding for Bioinformaticians

3.5-hour hands-on workshop. You'll build a small reimplementation of bedtools —
`mytools`, with subcommands like `sort`, `merge`, `intersect`, `subtract`, `closest` —
without writing much of it yourself. Real `bedtools` is installed on your VM, so every
correctness question has an oracle: your output either matches it or it doesn't. That
frees you to work on the thing this workshop is actually about, which is not BED files.
It's how to specify, parallelise, review and guard work that an agent does faster than
you can read it.

---

## How to read this document

Nearly everything here is a **prompt** — something you say to the agent in English —
because saying what you want is the skill we're here to practise. Copy-pasting shell is
not.

Every block below says where it goes:

- **In Claude Code** — paste it at the agent's prompt. Then edit it; they're launch
  pads, not magic words.
- **In the shell** — a plain terminal, no agent. Only two kinds of thing live here:
  bootstrap steps that need a human, and the `Done when` gates at the end of each
  block. Those gates verify reality rather than the agent's account of it, which is a
  distinction worth internalising early.

On GitHub, hover over any block and a **copy icon** appears in its top-right corner.
Use it — retyping a prompt by hand is how typos become bugs you spend ten minutes on.

### Copying and pasting in a Linux terminal

`Ctrl+C` and `Ctrl+V` do not paste in a terminal. Select the text, then:

| | |
|---|---|
| **Shift+Ctrl+C** | copy |
| **Shift+Ctrl+V** | paste |

You need both within the first five minutes, for the `gh` login code. Learn them now.

### Two shell habits

**Up arrow** walks back through commands you've already run — that's how you re-run a
`Done when` check without retyping it. **Right arrow** accepts the greyed-out
suggestion the shell offers you. Both save more typing than they look like they will.

---

## Setup (15 minutes, do this first)

One fork, one checkbox, four commands. Each of them needs a human; the agent does
everything after them. If GitHub fights you at any point, jump to
[If GitHub gives you trouble](#if-github-gives-you-trouble) and come back.

### 1 · Fork the repo, in your browser

[github.com/SACGF/ai_agent_workshop](https://github.com/SACGF/ai_agent_workshop) →
**Fork** → **Create fork**. Keep the default name.

### 2 · Turn on Issues on your fork

A fork ships with the **Issues tab switched off**, and forks don't copy issues either —
which is why the issue texts live in [`issues/`](issues/) for you to re-file at 0:15.
Turn the tab on now, or that exercise has nowhere to go:

Your fork → **Settings** → scroll to **Features** → tick **Issues**.

### 3 · Log in to `gh`

**NB:** This method gives the agent full access to your GitHub and allows it do any operations that your user can, if you wish to constrain your agent to have fewer permissions jump to [using a PAT](#using-a-pat).

**In the shell:**

```bash
gh auth login
```

Answer: **GitHub.com** → **HTTPS** → **Yes** to *"Authenticate Git with your GitHub
credentials"* → **Login with a web browser**.

Take HTTPS, not SSH: there are no SSH keys on this VM, and the "yes" is what gives
`git push` a password later. Say no and nothing fails until your first push.

It then prints a **one-time code** and a URL. This is where the room loses ten minutes,
so:

- **Copy the code with Shift+Ctrl+C.** You need it in the browser in a moment.
- **If no browser opens, or it opens on the VM instead of your laptop**, select the URL
  in the terminal, copy it, and paste it into the browser on your own machine.
- **On that page, click the one button and do nothing else.** Reloading it, wandering
  off, opening a second copy — any of those invalidate the code, and you start
  `gh auth login` over.

#### Using a PAT

Agents run with autonomy can and sometimes will run commands which you may not have wanted them to. If they have broad permissions this can sometimes be risky. For GitHub you can reduce the risk of an agent running something it shouldn't by using a fine-grained PAT as its method of authentication. 

You can create a new token through the [GitHub Developer Settings](https://github.com/settings/personal-access-tokens/new). I recommend creating a fine-grained token scoped to your fork of this repository, with `Read and write` permissions for at least `contents`, `pull requests`, `issues` and `commit statuses` and scoping it to expire within 7 days.  

You can then copy the token and run `export GH_TOKEN=github_pat_...` instead of `gh auth login`. All future `gh` commands in that session will pick up this token when they need to authenticate.  

### 4 · Set your git identity, and start Claude Code

**In the shell:**

```bash
workshop-git-identity    # sets your git name and email from your GitHub account
claude --version         # must print a version — everything below depends on it
claude                   # start it, then /login with the Claude account on your card
```

An unset git identity doesn't fail until your first commit twenty minutes from now, so
get it out of the way while nothing depends on it.

Your card has a **Claude account**. On first run, pick a theme, then `/login` and sign
in with it — the VM ships signed out, because it's your machine for the afternoon and
nobody else's credentials belong on it. Keep the card: if a session is lost, `/login`
asks again. That login opens a browser page too — same rule, **click the button and
nothing else**.

### 5 · First words to your agent

You're now talking to Claude Code. Before any prompt, one thing that isn't one: **`!`
runs a shell command without leaving the session.**

**In Claude Code:**

```text
!ls
```

```text
!git status
```

That's a real shell, and its output lands in the conversation, so the agent sees it
too. Use it all afternoon instead of quitting to go and look at something.

Now the machine check.

**In Claude Code:**

```text
Check this machine is ready for a workshop that uses Claude Code, `gh` and `bedtools`.
Verify `gh auth status`, `bedtools --version`, `bcftools --version`, `samtools --version`,
`Rscript --version`, `python3 --version` and `git config --global user.email`. Report
pass/fail for each. For anything that fails, give me the exact command to type myself;
don't try to fix it.
```

(No need to check your Claude login — you're talking to it.)

### 6 · Have it clone your fork

**In Claude Code:**

```text
I've already forked `SACGF/ai_agent_workshop` in the browser. Find it under my account
and clone it to `~/ai_agent_workshop` over HTTPS, with `origin` pointing at my fork and
`upstream` at SACGF. Then show me `git remote -v`, tell me my fork's full `owner/name`,
and print the URL of my fork's issues page so I can click it.
```

Everything you do today happens on **your fork**. Getting `origin` right here is most
of what keeps you off the shared template: `gh` with a missing `--repo` doesn't fail, it
silently resolves to the git remote and exits 0. A forgotten flag looks exactly like a
success, which is why the next step pins the rule somewhere the agent re-reads on every
turn.

### 7 · Restart Claude Code inside the clone

The agent can change its own working directory but not your shell's. So **quit it** —
`/exit`, or Ctrl-D — and start it again in the repo:

**In the shell:**

```bash
cd ~/ai_agent_workshop
claude
```

From now on, every session begins already knowing the project.

### 8 · Replace `CLAUDE.md`

There is already a `CLAUDE.md` in the repo root, and it's the wrong one — it's notes
for maintaining *this template*, not conventions for *your* project. **Overwrite it:**

**In Claude Code:**

```text
Overwrite the CLAUDE.md in the repo root with a copy of specs/CLAUDE.md.example. The
one there now is notes for the upstream template, not for my project, so replace it
entirely rather than merging. Then fill in the fork placeholder at the top with my
actual fork name.
```

`CLAUDE.md` is read automatically at the start of every session — conventions, gotchas,
how to run the tests, anything you'd otherwise retype. It's the highest-leverage file in
the repo: one line there beats repeating yourself in thirty prompts, and it survives
every `/clear`.

Add to it with `#`, which appends a standing instruction without leaving the session.
Worth doing once now, in your own words, on the rule you most need to hold:

**In Claude Code:**

```text
# gh issue create and gh pr create always pass --repo <you>/ai_agent_workshop. Never write to SACGF.
```

**Done when** `origin` is your fork and `CLAUDE.md` names it.

**In the shell:**

```bash
git remote -v
grep -n 'your-github-username' CLAUDE.md    # want no output — placeholder replaced
```

Then get your bearings before the clock starts.

**In Claude Code:**

```text
Read the README and specs/, then tell me in five bullet points what I'm supposed to
build today. Don't write any code.
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

Prompts for every exercise are in [`prompts.md`](prompts.md). Copy them, then edit.

Each block ends with a **Done when** you can check yourself. Run those, because "the
agent said it did" and "it is done" are not the same claim.

---

### 0:15–0:35 · Warm-up: two languages, one diff

**Goal.** Let the agent drive something you already know the right answer to, and learn
today's one trick: verify by diffing, not by reading.

First, your issues. Forks don't copy them, so yours has none right now — the texts are
in [`issues/`](issues/):

**In Claude Code:**

```text
Read `issues/` and file the three numbered 01-03 on my fork with `gh` — leave the
stretch ones for later. Show me the commands before you run them. When they're filed,
print the link to my fork's issues page.
```

"Show me first" is the habit worth forming for anything that writes to the network.
Read the `--repo` flag in what it shows you.

Then **click that link and look at the issues in your browser.** Not a formality: the
issue list is the shared surface between you and every agent you run this afternoon,
and you want to see what's actually on it. No Issues tab? You skipped step 2 of setup —
your fork → Settings → Features → tick Issues, then re-run the prompt.

Now the warm-up proper. *99 Bottles of Beer*, in the language you reach for without
thinking:

**In Claude Code:**

```text
Write `bottles.R` that prints the full lyrics of "99 Bottles of Beer" to stdout. Get the
bottom of the song right: "1 bottle" is singular, and zero is "no more bottles". Then
show me the last eight lines of its output.
```

Look at what it actually wrote — `!cat bottles.R` — and read those eight lines
yourself, because the bottom of that song is nothing but edge cases: a plural that stops
being plural, and a count that ends in a word instead of a number. That is the same
shape as the bug you are going to spend all afternoon not writing: **BED intervals are
0-based half-open**, and most wrong answers in this workshop are an off-by-one at a
boundary.

If the code is in a language you don't read, don't skip it — reframe it:

**In Claude Code:**

```text
Walk me through bottles.R as if I'm a Python programmer.
```

"Explain this in terms of a language I do know" is the most underused prompt in the
room. It's how you review the Rust you can't read at 2:40.

Then the same program again, in a language you don't use:

**In Claude Code:**

```text
Now write `bottles.py` — same output, and don't look at the R version while you do it.
Then diff the two outputs and tell me whether they are byte-identical.
```

**In the shell:**

```bash
diff <(Rscript bottles.R) <(python3 bottles.py) && echo identical
```

**That diff is the whole workshop in one command.** You can't review the second
program — you don't know the language well enough — but you can prove it agrees with one
you can. Every correctness claim today has this shape: `mytools` against `bedtools`,
byte for byte. The only thing that changes after the warm-up is that the reference
implementation is someone else's and the edge cases are intervals.

Thirty seconds more, and worth it:

**In Claude Code:**

```text
Introduce a single off-by-one into the Python version, show me the diff, then put it
back.
```

Notice how precisely the diff says *that* something is wrong, and how little it says
about *where*. That's the 2:00 guardrails exercise in miniature, before you've written
anything real.

---

## CHOOSE YOUR LANGUAGE

**Stop here and decide.** Everything from this point is `mytools`, one codebase for the
rest of the afternoon, and five parallel agents will each pick their own language if you
don't pick one for them.

- **First time driving an agent? Use the language you know best.** You are about to
  review a lot of code very fast, and today's lesson is supervision, not syntax. Being
  able to see a wrong `<=` at a glance is the entire point.
- **Want it hard? Use one you don't know.** The golden tests diff bytes against
  bedtools, so they don't care what's underneath — which means you can prove code
  correct that you cannot read. That's the real claim of this workshop, and testing it
  at 0:35 instead of 2:40 is the honest version.

Either answer is fine. Not answering is not. Then write it down where every session
will see it:

**In Claude Code:**

```text
# mytools is written in <language>. Every subcommand and every test. Don't introduce a second language without asking me.
```

---

### Back to the warm-up · the first `mytools` issue

**In Claude Code:**

```text
Make `mytools --version` print a version and exit 0. One file, no subcommands yet. Stop
as soon as that works.
```

Then close the loop on it — the habit the rest of the day runs on:

**In Claude Code:**

```text
Look at issue #1 on my fork. Is it actually done? Check the code, not your memory of
what you wrote. Then commit straight to main referencing the issue, push, and close the
issue.
```

Claude reaches for a branch and a PR by default. That's right at 2:00 and overkill for a
one-line warm-up, so say which you want: *"just commit to main, push, and close the
issue."* Agents follow an explicit instruction far better than they guess your taste.

**Done when** three issues are listed, two languages agree, and the binary runs.

**In the shell:**

```bash
gh issue list --repo "$(gh api user --jq .login)/ai_agent_workshop"
diff <(Rscript bottles.R) <(python3 bottles.py) && echo identical
mytools --version
```

Swap in your own two languages for the warm-up — Rust is installed, and an agent will
happily install anything else. The further the second one is from your comfort zone, the
better the lesson.

---

### 0:35–0:55 · Brainstorm → spec

**Goal.** A `SPEC.md` that answers every question five parallel agents are about to ask.

Have the agent interview you — **one question at a time**:

**In Claude Code:**

```text
I want to build a small bedtools-like CLI called `mytools`. Interview me one question at
a time until you can write a complete SPEC.md. Ask about scope, flags, formats, error
handling, and performance assumptions. Don't suggest answers until I've given mine. Then
write SPEC.md and stop.
```

The decisions are yours, and they're real: which subcommands, which flag subset,
streaming or in-memory, BED-only or GFF3 too, exit code semantics, `-header` handling.
It will go and read `specs/mytools-spec-template.md` by itself — that's the skeleton and
it's meant to. Ask it to do a quick web search on how bedtools actually defines
`merge -d` before you commit to an answer.

**You are allowed not to care.** *"Do it like bedtools"*, *"the simplest thing that
works"*, *"whatever you think"* are complete answers, and for most of those twenty
questions they're the right ones. Spend your attention on the three or four decisions you
have an actual opinion about and punt the rest — an interview where you agonise over
`-header` for six minutes is an interview you don't finish.

**The other way in: ramble.** If the interview feels like it's dragging answers out of
you, invert it. Dump everything you half-know into one long unstructured message — what
you want, what annoys you about the tool you use now, the thing that bit you last month,
in no order at all — and then:

**In Claude Code:**

```text
That was a brain dump, not a spec. Play it back to me as a structured list of what I
seem to want, flag anything I contradicted myself on, then interview me one question at
a time on the gaps.
```

Rambling at an agent is cheap, and typing was never the bottleneck. Getting it out of
your head badly and having it shaped beats staring at an empty `SPEC.md`.

Your `CLAUDE.md` is already in place from setup. Read it now if you haven't — it's a
worked example of the genre, and it's shaping every answer you get today. Add to it as
your design firms up, with `#` or by editing it directly.

**Stalled at 0:50?** Tell the agent to copy `specs/fallback-spec.md` to `SPEC.md` and
move on. The spec is not the exercise.

**Done when** `SPEC.md` is in your repo root with no decisions left blank.

**In the shell:**

```bash
grep -c '_____' SPEC.md    # want 0
```

---

### 0:55–1:45 · Issues → code, in parallel

**Goal.** Several subcommands built at once, by several agents, and you supervising.

**Choose your model before you plan, not after.** Breaking a spec into issues *is* the
planning — it's the highest-leverage thinking of the afternoon, and the place a stronger
model earns its keep. Switch first, then prompt:

**In Claude Code:**

```text
/model
```

| Model | What it's for |
|---|---|
| **Opus** | Your default. Implementation, tests, refactors, all the busy work. |
| **Fable** | The hard thinking — planning, design arguments, "why is this wrong?". Burns tokens fast, so use it deliberately and switch back. |
| **Sonnet** | Skip it today. |

The rule of thumb: **discuss and plan with Fable, build with Opus.** Both halves of that
trade are real — Fable grinding through boilerplate is money on fire, and Opus settling
a subtle design question is a plan you rewrite at 2:30.

Now turn the spec into issues:

**In Claude Code:**

```text
Read SPEC.md. Break it into 5-7 GitHub issues, one per subcommand, each independently
implementable by someone who hasn't read the others. Give each one acceptance criteria
that reference the golden-test pattern in tests/README.md, then file them on my fork and
print the link to my issues page.
```

Open that link and read them before you fan out. Five agents are about to take these
literally, and a vague acceptance criterion is five vague implementations.

Then switch back to Opus and go parallel — see
[Working at agentic speed](#working-at-agentic-speed) below. One copy of the repo and
one Claude Code session per subcommand.

**Done when** two or more subcommands are implemented on separate branches and you've
run the golden test seed against at least one of them.

**In the shell:**

```bash
for d in ~/ws-*; do echo "$d  $(git -C "$d" branch --show-current)"; done
```

---

### 1:45–2:00 · Break — on the balcony, with your agent

**Goal.** Fresh air, and the point of the whole day: the work continues while you are
not at the keyboard.

Before you stand up, give it something that takes longer than the break:

**In Claude Code:**

```text
Read SPEC.md and tests/README.md, then write golden tests for every subcommand I have so
far, diffing against real bedtools on data/a.bed and data/b.bed. Cover the bookended,
nested, identical, zero-length and position-0 cases. Run them, and fix what fails.
```

Then go outside. You are not abandoning it — you are taking it with you.

**Remote Control** connects the session on your VM to the Claude app on your phone, or
to a browser at [claude.ai/code](https://claude.ai/code). The code, the filesystem and
the execution all stay on the VM; the phone is another keyboard and screen for the
session already running.

**In Claude Code:**

```text
/remote-control
```

Accept the one-time confirmation, and a status panel appears with the session URL and
a QR code. Scan it — install the app first,
[iOS](https://apps.apple.com/us/app/claude-by-anthropic/id6473753684) or
[Android](https://play.google.com/store/apps/details?id=com.anthropic.claude) — and
the conversation is in your hand, live, with your VM behind it.

This works because you signed in with `/login` at setup — Remote Control needs a real
subscription login, and neither an API key nor a `setup-token` can establish one. It is
the one thing the workshop accounts buy you that a key would not.

`tmux` is what makes any of this safe: walking out of wifi range kills your SSH
connection, not your session. If you skipped it at login, start it now and re-run your
agent inside it.

**Done when** you're back, and something finished without you.

**In the shell:**

```bash
tmux attach
```

---

### 2:00–2:40 · PRs, review, guardrails

**Goal.** A green CI that catches a bug you plant on purpose.

Open PRs on your own fork:

**In Claude Code:**

```text
Push this branch and open a PR against my fork. Write a description that says what
changed, what's tested, and what isn't.
```

**Pair up.** Swap fork names with the person next to you and review each other's:

**In Claude Code:**

```text
Review PR #N on `<partner>/ai_agent_workshop`. Fetch the diff, then focus on interval
overlap logic and BED coordinate handling — BED is 0-based half-open, so look hard at
every `<` and `<=`. Draft review comments and show them to me before posting anything.
```

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

Two things bite everyone in this block, and both are GitHub permissions rather than
code: **Actions are disabled on new forks**, and pushing to `.github/workflows/` needs a
scope `gh auth login` didn't ask for. Fixes for both are in
[If GitHub gives you trouble](#if-github-gives-you-trouble).

**Then break it on purpose:**

**In Claude Code:**

```text
Introduce a subtle off-by-one bug in the interval overlap logic on a new branch — the
kind someone would write by mistake, not an obvious one. Open a PR for it and let's see
whether CI catches it.
```

If CI goes red, the guardrail works. If it stays **green**, that's the more useful
result: your suite has a hole. Find the case that would have caught it.

**Done when** CI is green on a real PR and you've watched it react to a planted bug.

**In the shell:**

```bash
gh run list --repo "$(gh api user --jq .login)/ai_agent_workshop" --limit 5
```

---

### 2:40–3:20 · Stretch goals

Self-directed. Pick one, they're independent. Prompts for all of them are in
[`prompts.md`](prompts.md).

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

**In the shell:**

```bash
bedtools bamtobed -i /data/HG002.neighbourhoods.bam > reads.bed   # ~500,000 intervals
```

Then find out whether your `SPEC.md` was telling the truth about memory, and whether
your `intersect` is quadratic. Being slower than bedtools is fine — it's C and you're
not. Being *quadratic* is the finding. Full brief in
[`issues/05-real-data-scale.md`](issues/05-real-data-scale.md).

**Implement a subcommand in a language you don't know.** Rust, Go, Julia, whatever —
unless you already did that at CHOOSE YOUR LANGUAGE, in which case do one in the
language you *do* know and compare how differently you supervise. The golden tests diff
bytes against bedtools, so they transfer unchanged. You can't read the code, but you can
prove it's correct. That's the point.

**Claude Code from your phone.** Covered at the 1:45 break, and demoed from the front.
If you got `/remote-control` working then, the interesting version of this stretch goal
is to run the rest of the afternoon from the phone and see which parts of supervision
survive a 6-inch screen.

---

### 3:20–3:30 · Wrap-up

What your afternoon cost, in any session still open:

**In Claude Code:**

```text
/usage
```

The session block is tokens and an estimated dollar figure for *that* conversation; the
plan bars above it are how much of the account's allowance the afternoon actually ate.
Worth seeing both next to what you built — and worth noting which of the two you'd
watch if you did this every day.

---

## Claude Code survival card

| | |
|---|---|
| **Shift+Tab** | Plan mode. It thinks and proposes, changes nothing. Use it for anything non-trivial. |
| **Esc** | Interrupt. Not a crash — it stops and waits. Use it early, the moment it's off track. |
| **Esc Esc** | Edit your previous message and rerun from there. |
| **`!cmd`** | Run a shell command without leaving the session — `!ls`, `!git status`, `!cat bottles.R`. |
| **`/model`** | Switch models. Plan and argue on Fable, build on Opus, skip Sonnet. |
| **`/clear`** | Wipe the conversation. Between unrelated tasks, do this. |
| **`/usage`** | Tokens and dollars for this session, per model. Look after anything that felt expensive. |
| **`/context`** | What's eating your context window right now. |
| **`#`** | Prefix a message to save it to `CLAUDE.md` as a standing instruction. |
| **`/init`** | Generate a `CLAUDE.md` for an existing codebase. |
| **`/exit`** | Quit (Ctrl-D does it too). Needed whenever you want to `cd` somewhere else. |
| **`claude -p "..."`** | One-shot, non-interactive. Pipes and scripts. |
| **`/remote-control`** | Hand the session to your phone. See the 1:45 break. |

And in the shell around it: **Up arrow** for a command you already ran, **Right arrow**
to accept the suggestion, **Shift+Ctrl+C / Shift+Ctrl+V** to copy and paste.

**`CLAUDE.md`** — yours came from `specs/CLAUDE.md.example` at setup. Anything you'd
otherwise retype goes in it. Add with `#`, or just edit the file.

**Give it a goal, not a procedure.** "Make the golden tests pass" gets you further
than a numbered list of edits. If you find yourself writing the steps, you're doing
the work twice.

**Say which workflow you want.** Left alone, Claude branches and opens a PR. That's
right for the 2:00 block and heavy for a one-line fix — *"just commit to main, push,
and close the issue"* is a legitimate instruction, and it takes it.

**Interrupt early.** A wrong turn caught in ten seconds costs ten seconds. The same
turn caught in three minutes costs a `git checkout`.

**Ask before it writes to the network.** "Show me the commands first" on anything
touching `gh`, and read the `--repo` in what comes back.

**`/usage` resets on `/clear`.** The session figure is what that conversation cost, not
what your afternoon cost — the plan bars above it are the running total. Check it after
a long parallel run: three agents on Fable is a very different number from three on
Opus, and seeing it once is how the habit of `/model` sticks. Your account has its own
session limit, and the 0:55 block deliberately runs several agents at once, so this is
also how you see a limit coming instead of hitting it.

---

## Working at agentic speed

One agent is faster than you. Three agents are faster than you can read. The binding
constraint stops being typing and becomes *supervision*, which is a different skill —
these are the mechanics for it.

Agents collide if they share a directory, so give each one its own copy of the repo.
Not a clever mechanism — literally three copies:

**In Claude Code:**

```text
Make three copies of this repo as siblings — `~/ws-sort`, `~/ws-merge` and
`~/ws-intersect` — and in each one create the branch for its issue: `feat/2-sort`,
`feat/3-merge`, `feat/4-intersect`. Then start a detached tmux session called `ws` with
one tiled pane per copy, each running `claude` in that directory. Don't attach — I'll do
that myself.
```

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

**In the shell:**

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

## If GitHub gives you trouble

Everything GitHub-shaped that bites people during this workshop, in one place. None of
it is your code's fault.

**The login page ate my one-time code.** `gh auth login` prints a code and a URL; on the
page that opens, click the single button and *nothing else*. Any other interaction
invalidates the code. Start over with `gh auth login`, copy the new code with
**Shift+Ctrl+C**, paste it with **Shift+Ctrl+V**. Same for `/login` in Claude Code.

**No browser opened, or it opened on the VM.** Select the URL in the terminal, copy it,
and paste it into the browser on your own laptop by hand.

**`git push` asks for a password and nothing works.** You said no to *"Authenticate Git
with your GitHub credentials"*. Re-run `gh auth login`, choose **HTTPS**, say yes this
time. Use HTTPS rather than SSH throughout — this VM has no SSH keys, and `gh` installs
a git credential helper only for HTTPS.

**My fork has no Issues tab.** Forks ship with Issues switched off. Your fork →
**Settings** → **Features** → tick **Issues**, then re-run the filing prompt. (If you
also want the upstream's issues, you don't — forks never copy them, which is why
[`issues/`](issues/) exists.)

**Actions never run on my fork.** Forks ship with Actions disabled too. Your fork →
**Actions** tab → click the button that enables workflows. Nothing you push runs until
you do. Bites at 2:00.

**Push rejected: *refusing to allow an OAuth App to create or update workflow*.**
`gh auth login` didn't ask for the scope that lets you push `.github/workflows/`:

```bash
gh auth refresh -s workflow
```

Then push again.

**I can't fork at all.** A locked-down account or org policy. Use a personal account,
or grab an organiser — nothing today touches an org repo.

**`gh` 403s on my org.** Authorise the token for the org; GitHub prints the link in the
error. Or use a personal account.

**Am I even logged in?** `gh auth status` — and `!gh auth status` if you'd rather ask
from inside Claude Code.

**I filed an issue or PR on SACGF by mistake.** Close it and say so; no harm done. Then
check `git remote -v`, and check the `--repo` rule is in your `CLAUDE.md` — that's what
it's there to prevent.

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
