# Build notes: "Agentic Coding for Bioinformaticians" workshop template repo

You are helping me scaffold a GitHub template repository for a 3.5-hour hands-on
workshop teaching AI coding agents (Claude Code) to professional bioinformaticians
and PhD students. Attendees are mostly **new to Claude Code**. Each attendee gets an
Ubuntu 24 VM with `gh`, standard Python, R, and internet access. Auth is via
workshop API keys pre-set as `ANTHROPIC_API_KEY` on the VMs. Attendees **fork this
repo** and work in their fork.

Read all of these notes before creating anything, then build the repo.

## The anchor project: mini-bedtools

Everyone in the audience knows bedtools. The central project is reimplementing a
small subset of it ("mytools") — a CLI with subcommands like `sort`, `merge`,
`intersect`, `subtract`, `closest`. Key properties we exploit:

- **Real bedtools is installed on the VMs and acts as an oracle.** Golden tests
  compare `mytools <cmd>` output against `bedtools <cmd>` on the same fixture
  files. This is the backbone of the tests/CI/correctness exercises.
- It decomposes into equal-sized, independent GitHub issues → good for the
  parallel-worktrees exercise.
- Known semantics → attendees can judge correctness of agent-written code even in
  a language they don't know (the "implement it in a language you've never used"
  game). Golden tests transfer across languages unchanged.

The repo should NOT contain a mini-bedtools implementation — attendees build it.
The repo contains scaffolding: specs, fixtures, prompts, CI skeleton, issues.

## Second-half extension: gene lookup via REST

A later exercise adds a subcommand (e.g. `mytools genes closest --gene BRCA1`)
that resolves a gene symbol to coordinates via a REST API, then reuses the
interval logic. The API contract lives in the repo as an OpenAPI file.

- Default base URL: **https://cdotlib.org** (our own cdot deployment — assume it
  satisfies the contract; leave a TODO comment for me to verify exact paths and
  adjust the OpenAPI file to match the real cdot endpoints).
- Stretch exercise: 1–2 volunteers implement their own server conforming to the
  same contract (FastAPI or R plumber), serve it on their VM's IP, and post the
  URL in a shared GitHub issue; others can repoint their client with a one-line
  base-URL change. The room must never be blocked on a volunteer server —
  cdotlib.org is always the fallback default.

## Repo structure to create

```
.
├── README.md                  # workshop agenda + exercise instructions (the main doc)
├── CLAUDE.md                  # opinionated example project conventions file
├── prompts.md                 # copy-pasteable starting prompts per exercise
├── specs/
│   ├── mytools-spec-template.md   # skeleton spec with decisions left blank (see below)
│   ├── fallback-spec.md           # a complete pre-written spec for people who stall
│   └── gene-api.openapi.yaml      # REST contract for the gene lookup service
├── data/
│   ├── a.bed, b.bed               # small deterministic BED files (see fixtures below)
│   └── genes.bed                  # gene subset around famous loci
├── tests/
│   └── README.md                  # explains the golden-test-against-bedtools pattern,
│                                  #   with one worked example script
├── .github/
│   └── workflows/ci.yml           # deliberately minimal skeleton (see below)
└── LICENSE                        # MIT
```

## File-by-file details

### README.md
The single source of truth attendees keep open. Include:
1. One-paragraph pitch of the day.
2. Setup checklist (verify `claude` runs, `gh auth status`, `bedtools --version`,
   fork this repo, clone your fork).
3. The timed agenda (below), with each exercise as a section: goal, steps,
   pointer to the matching prompt in `prompts.md`, and a "done when" criterion.
4. A short "Claude Code survival card": plan mode (Shift+Tab), Esc to interrupt,
   `/model` to switch models, what CLAUDE.md is, "give it a goal not a procedure".
5. A section on working at agentic speed: `git worktree` + one Claude Code
   session per worktree in tmux/screen panes, with the exact commands.

Agenda (3.5 h):
- 0:00–0:15 — Setup: verify the machine, fork, clone, CLAUDE.md in place
- 0:15–0:35 — Warm-up: re-file the issues, then "99 Bottles of Beer" in the
  attendee's own language and again in one they don't read, verified by diffing
  the two outputs against each other. Plant an off-by-one, watch the diff catch
  it. This is the golden-test move and the off-by-one teaching point in
  miniature, before anything real is at stake. Then `mytools --version`.
- 0:35–0:55 — Brainstorm → spec: agent interviews you, writes SPEC.md, quick
  literature/prior-art web search. Design decisions are yours: which flags,
  streaming vs in-memory, BED-only vs GFF3, exit codes, `-header` handling.
  Stalled? Adopt `specs/fallback-spec.md`.
- 0:55–1:45 — Spec → issues → code: agent files issues with `gh`; plan with a
  strong model, execute with a cheaper one; worktrees + tmux for parallel
  subcommands.
- 1:45–2:00 — Break. Kick off a long task, connect `/remote-control` to the
  Claude app, and go outside with it — the lesson is that supervision does not
  require a keyboard. NOTE: Remote Control requires a Pro/Max/Team/Enterprise
  login; API keys are not supported, so attendees on the workshop key must
  `unset ANTHROPIC_API_KEY` and `/login` with their own subscription, or just
  take the break and watch the demo from the front. Never block the room on it.
- 2:00–2:40 — PR + human review (pair up, review each other's PRs with
  `gh pr review`) + guardrails: agent adds golden tests vs bedtools, a linter,
  GitHub Actions; then deliberately introduce a bug and watch CI catch it.
- 2:40–3:20 — Stretch goals (self-directed): gene-lookup REST client;
  reimplement a subcommand in a language you don't know; volunteers build the
  gene API server; running the afternoon from your phone.
- 3:20–3:30 — Wrap-up, show token usage (`/usage` per session, the console for
  the day) — "what your afternoon cost".

Note on forks/PRs: attendees review each other on their own forks. Include the
`gh pr create --repo <their-fork>` incantation so PRs don't accidentally target
this upstream template.

### CLAUDE.md
Write a realistic, opinionated one (~30 lines) as if for the mytools project:
language-agnostic conventions (run the golden tests before committing; small
commits referencing issue numbers; prefer streaming I/O; BED is 0-based
half-open — state this explicitly since it's the classic bug), plus where
fixtures live and how to run the test script. This doubles as the teaching
example of what a good CLAUDE.md looks like.

### prompts.md
For each exercise, 1–3 copy-pasteable starting prompts. Novices freeze at a
blank prompt; these are launch pads they can edit. Examples of the style:
- Brainstorm: "I want to build a small bedtools-like CLI. Interview me one
  question at a time until you can write a complete SPEC.md. Ask about scope,
  flags, formats, error handling, and performance assumptions. Then write
  SPEC.md and stop."
- Issues: "Read SPEC.md. Break it into 5–7 GitHub issues, one per subcommand,
  each independently implementable, with acceptance criteria that reference the
  golden-test pattern in tests/README.md. File them with gh."
- Guardrails: "Set up a test suite that compares mytools output to real bedtools
  on the files in data/, add a linter, and a GitHub Actions workflow that runs
  both on every PR."
- Bug hunt: "Introduce a subtle off-by-one bug in interval overlap logic on a
  branch, open a PR, and let's see whether CI catches it."

### specs/mytools-spec-template.md
Skeleton with headings and blank decision points (subcommand list, flag subset,
memory model, formats, exit codes) — the artifact the brainstorm exercise fills.

### specs/fallback-spec.md
A complete, opinionated spec for a minimal mytools: `sort`, `merge` (-d),
`intersect` (-u, -v, -wa), `subtract`; BED3–BED6 only; read from file or stdin;
0-based half-open; exit 0/1/2 semantics; must pass golden tests vs bedtools.

### specs/gene-api.openapi.yaml
OpenAPI 3 contract, small:
- `GET /gene/{symbol}` → `{symbol, chrom, start, end, strand}` (404 if unknown)
- `GET /genes?region=chr17:43000000-43200000` → array of the same object
Include `servers:` with https://cdotlib.org as default and a commented-out
`http://<volunteer-vm-ip>:8000` example. TODO comment for me: align paths with
the real cdot API before the workshop.

### data/ fixtures
Generate deterministic, small files (hand-written or scripted, but committed as
plain files — no generation step at workshop time):
- `a.bed`, `b.bed`: a few hundred BED6 intervals across 2–3 chromosomes,
  engineered to include the edge cases that matter: bookended intervals
  (end == start), fully nested intervals, identical intervals, zero-length,
  intervals at position 0, unsorted order, both strands.
- `genes.bed`: ~20 real gene coordinates (GRCh38) around famous loci — BRCA1,
  TP53, CFTR, EGFR neighbourhoods — so gene-lookup results feel recognisable.
Keep everything small enough that the full golden test suite runs in seconds.

### tests/README.md
Explain the golden-test pattern in a few paragraphs and include ONE worked
example (a bash or pytest snippet diffing `mytools sort data/a.bed` against
`bedtools sort -i data/a.bed`). The agent and attendees grow the suite from
this seed — don't pre-build the whole suite.

### .github/workflows/ci.yml
Minimal on purpose: checkout, install bedtools (apt), placeholder test step
that currently just echoes "no tests yet" and exits 0. The exercise is having
the agent grow it. Add a comment in the file saying exactly that.

### Pre-filed GitHub issues
After creating the repo, file 3 issues on it with `gh` so `gh issue list`
works immediately post-fork (note: forks don't copy issues — so ALSO put the
issue texts in README or a `issues/` folder so attendees can have their agent
re-file them on their own fork as a first task; that's actually a better
exercise). Issues:
1. "Warm-up: make `mytools --version` work" (tiny, for the hello-world slot)
2. "Adopt or write a spec" (points at specs/)
3. "Set up golden tests + CI" (points at tests/README.md)

## Style notes
- Everything language-agnostic where possible; where an example must pick a
  language, use Python but say "or your language of choice".
- Tone: terse, practical, no fluff. Attendees read this under time pressure.
- Do not implement any mytools functionality anywhere in this repo.

When done, print a summary tree and a checklist of the manual TODOs left for me
(verify cdotlib.org endpoints, set per-key spend caps, install bedtools in the
VM image, dry-run the whole agenda once).
