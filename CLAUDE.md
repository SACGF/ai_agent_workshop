# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

`SACGF/ai_agent_workshop` is the **GitHub template repository** for a 3.5-hour hands-on
workshop, "Agentic Coding for Bioinformaticians" (Claude Code, taught to professional
bioinformaticians and PhD students who are mostly new to it). Attendees fork this repo
and work in their fork on Ubuntu 24 VMs that already have `gh`, Python, R, `bedtools`
and `ANTHROPIC_API_KEY` set.

The repo is **scaffolding, not software**. As of the initial commit it contains only
`README.md` (a stub), `LICENSE`, `.gitignore` and `workshop-repo-notes.md`.

## Read this first

`workshop-repo-notes.md` is the design brief for the whole repo: target structure,
file-by-file requirements, the timed agenda, fixture edge cases, and the pre-filed
issues. **Read it before creating or changing any workshop content** — most requests in
this repo are "build the next piece of that brief", and it is the source of truth for
what each file must contain.

## Hard constraints

- **Never implement mytools.** The anchor exercise is attendees reimplementing a subset
  of bedtools (`sort`, `merge`, `intersect`, `subtract`, `closest`) as a CLI called
  `mytools`. This repo must contain specs, fixtures, prompts, a CI skeleton and issue
  text — no implementation, and no complete test suite. Under-building is deliberate:
  the attendees' agents grow the tests and CI, so the seeds stay minimal (e.g.
  `ci.yml` echoes "no tests yet" and exits 0, with a comment saying so).
- **BED is 0-based half-open.** State it explicitly wherever intervals are discussed;
  the classic off-by-one is a teaching point (and the deliberate-bug exercise).
- **Real `bedtools` is the oracle.** Every correctness story in the workshop is a golden
  test diffing `mytools <cmd>` against `bedtools <cmd>` on files in `data/`. Fixtures
  must be small, deterministic, committed as plain files (no generation step at workshop
  time), and cover bookended, nested, identical, zero-length, position-0, unsorted and
  both-strand intervals.
- **Language-agnostic.** Where an example must pick a language use Python, but say "or
  your language of choice" — golden tests are meant to transfer unchanged when attendees
  reimplement a subcommand in a language they don't know.
- **cdotlib.org is never optional.** The gene-lookup exercise defaults to
  `https://cdotlib.org`; a volunteer-run server is a stretch goal only, and the room must
  never be blocked on it.
- **Tone:** terse and practical. Attendees read everything under time pressure.

## Fork-safety

Attendees work on forks and review each other's PRs there. Any `gh pr create` or
`gh issue` incantation written into the workshop docs must target the attendee's own
fork (`gh pr create --repo <their-fork>`), never this upstream template. Forks don't
copy issues, so issue text lives in the repo (README or `issues/`) for attendees to
have their agent re-file — that re-filing is itself the first exercise.

## Note on this file

`workshop-repo-notes.md` also asks for a `CLAUDE.md` at the repo root as a *teaching
example* — an opinionated ~30-line conventions file written as if for the mytools
project. That is a different document from this one, which guides work on the template
itself. Put the teaching example somewhere it can't shadow this file (e.g.
`specs/CLAUDE.md.example`, copied into place by attendees) or fold the mytools
conventions in as a clearly-labelled section, rather than overwriting this file.

## Commands

There is no build, test or lint step yet — nothing executable is committed. Verification
is by inspection against `workshop-repo-notes.md`, plus `gh` for issues/PRs.

## Open TODOs from the brief

- ~~Verify the real cdot API paths at cdotlib.org~~ — done 2026-09-08. cdotlib.org does
  **not** serve `/gene/{symbol} -> {chrom,start,end,strand}`; that endpoint returns
  metadata only (no coordinates) and 404s as HTML. `specs/gene-api.openapi.yaml` is
  therefore *our own* simple protocol, with cdot as one swappable client behind it:
  `GET /transcripts/gene/{sym}/mane/GRCh38?annotation_consortium=RefSeq` -> take the
  first value -> `genome_builds.GRCh38` -> exon min/max for the span, plus an
  `NC_000017.11 -> chr17` contig map. Verified against known GRCh38 coordinates.
- Set per-key spend caps on the workshop API keys.
- ~~Confirm `bedtools` is in the VM image.~~ — v2.31.1 present on the build box; still
  worth confirming on the actual attendee image.
- Dry-run the full agenda once.
- `data/genes.gtf` is a real, unmodified region-subset of GENCODE v50 (provenance in its
  header). `data/genes.bed` is derived from it: the MANE Select transcript span of each
  gene that has one. Regenerate rather than hand-editing, and keep the round-trip in
  `tests/README.md` passing. Cross-checked 2026-09-08: for the 19 genes in common, these
  spans match cdotlib's RefSeq MANE spans exactly, so the GTF-backed server and the cdot
  client agree.
- `data/broken.vcf` was produced by a seeded generator (kept OUT of the repo on purpose
  — it names every planted bug). `data/broken.vcf.answers.rot13` is the authoritative
  record: 13 violations, with line numbers and what each tool does or doesn't catch.
  Measured, not assumed: `bcftools view` and `bcftools stats` both exit 0. If you
  regenerate the file, re-measure and update the key, since line numbers will move.
- Gene coordinates are defined as the **MANE Select span**, not the GTF `gene` row span
  (they differ — BRCA1 by ~45 kb). This is stated in `specs/gene-api.openapi.yaml`; keep
  it stated, or the two backends silently disagree.
