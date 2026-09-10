Nothing else can be parallelised until the decisions are written down. Two intervals
"overlapping" has to mean one specific thing before five issues can implement it.

## Goal

`SPEC.md` exists in the repo root and answers every design question `mytools` needs.

## Two routes

**Write your own.** Have your agent interview you one question at a time, using
`specs/mytools-spec-template.md` as the skeleton, then write `SPEC.md`. See the
brainstorm prompts in `prompts.md`.

**Adopt the fallback.** `cp specs/fallback-spec.md SPEC.md`. It's complete and
opinionated: `sort`, `merge -d`, `intersect -u/-v/-wa`, `subtract`, BED3-BED6, exit
codes, the lot. Zero shame in this — if you're past 0:50, just take it.

## Acceptance criteria

- [ ] `SPEC.md` in the repo root, no `_______` placeholders left
- [ ] Subcommands and their v1 flags are enumerated
- [ ] States that BED is 0-based half-open, and defines the overlap predicate exactly
- [ ] Says what happens with bookended and zero-length intervals
- [ ] Exit code table
- [ ] Names real `bedtools` as the correctness oracle
- [ ] `CLAUDE.md` at the repo root (`cp specs/CLAUDE.md.example CLAUDE.md`, then edit
      it so it matches what you actually decided)

## Notes

Scope is a decision, and cutting is the skilled part. Four subcommands finished beats
seven half-built ones.
