# SPEC.md — mytools

Fill this in during the brainstorm exercise. Every `_______` is a decision you own.
Leave a one-line rationale next to each — future-you and your agent both need it.

Stuck or short on time? Copy `specs/fallback-spec.md` over this and move on.

---

## 1. Scope

Subcommands in v1: `_______`

Explicitly NOT in v1 (write these down — scope creep is the main failure mode here):
`_______`

## 2. Input formats

- Formats accepted: `_______`  (BED3? BED4? BED6? BED12? GFF3?)
- Read from file argument, stdin, or both? `_______`
- How is `-` interpreted? `_______`
- Compressed input (`.gz`)? `_______`
- `track` / `browser` / `#` comment lines: skip, pass through, or error? `_______`

## 3. Interval semantics

- Coordinate system: **0-based half-open** (this is not a decision; BED says so).
- Do bookended intervals (`a.end == b.start`) overlap? `_______`
- Are zero-length intervals (`start == end`) legal? What do they overlap? `_______`
- Minimum overlap to count as an overlap: `_______`

## 4. Flags per subcommand

For each subcommand, the flag subset you will support. Match bedtools' names and
meanings exactly — you are being graded against it.

| Subcommand  | Flags in v1 | Notes |
|-------------|-------------|-------|
| `sort`      | `_______`   |       |
| `merge`     | `_______`   |       |
| `intersect` | `_______`   |       |
| `subtract`  | `_______`   |       |
| `closest`   | `_______`   |       |

- Strand-aware flags (`-s`, `-S`)? `_______`
- Does `merge` need pre-sorted input, or does it sort for you? `_______`
- Does `closest` require sorted input? `_______`

## 5. Output

- Output format per subcommand: `_______`
- Field separator, trailing newline, how empty results are printed: `_______`
- `-header` handling: `_______`

## 6. Memory model

- Streaming, fully in-memory, or per-chromosome? `_______`
- Largest input you promise to handle: `_______`
- Which subcommands can stream and which fundamentally cannot? `_______`

## 7. Errors and exit codes

| Situation             | stderr message | exit code |
|-----------------------|----------------|-----------|
| Success               | —              | `_______` |
| Malformed BED line    | `_______`      | `_______` |
| `start > end`         | `_______`      | `_______` |
| Unknown flag          | `_______`      | `_______` |
| Missing input file    | `_______`      | `_______` |
| Unsorted input to `closest` | `_______` | `_______` |

## 8. Correctness

- Oracle: real `bedtools` on the files in `data/`. Non-negotiable.
- Which subcommand/flag combinations get a golden test in v1? `_______`
- Known deviations from bedtools you are accepting, and why: `_______`

## 9. Language and layout

- Implementation language: `_______`  (anything; golden tests do not care)
- Entry point / how it is invoked: `_______`
- Where tests live: `_______`
