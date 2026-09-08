# Golden tests: bedtools is the oracle

Real `bedtools` is installed on your VM. It is the reference implementation. A golden
test runs your `mytools` and real `bedtools` on the same fixture and diffs the output.
If they differ, you are wrong — not bedtools.

This is worth more than hand-written unit tests here, for three reasons:

1. **You don't have to know the right answer.** bedtools knows. You never write an
   expected-output file by hand, so you never enshrine your own misunderstanding.
2. **It survives a rewrite.** The tests shell out to a `mytools` binary and diff
   bytes. Reimplement a subcommand in Rust, R, or a language you have never used and
   the tests transfer unchanged. This is what makes the "implement it in a language
   you don't know" exercise safe.
3. **It catches the bug you're about to write.** BED is 0-based half-open, and the
   off-by-one in overlap logic is the classic error. A golden test finds it in
   seconds; reading your own code does not.

## Two kinds of test, and you want both

**Golden tests** diff you against real bedtools. They prove agreement with reality and
catch things you never thought to check. But they need `bedtools` on the box, and when
one fails it tells you *that* you disagree, not *where*.

**Unit tests** pin one behaviour each. They run in milliseconds, need nothing installed,
and when one fails it names the function. They are how you nail down the edge cases you
had to reason about — bookended, zero-length, position 0 — so that a refactor six months
from now can't quietly undo them.

The rule of thumb:

- One golden test per subcommand and flag combination.
- One unit test per edge case you had to stop and think about.
- **When a golden test fails and you fix it, add the unit test that would have caught
  it.** That single habit is what makes a suite grow in the right direction instead of
  just growing.

Both belong in CI, along with a linter. That is the destination for today: a project
where `git push` runs your tests and your linter, and tells you if you broke something.

## The pattern

    run mytools  <cmd> <args>   > got
    run bedtools <cmd> <args>   > want
    diff want got   -> pass if identical

That's the whole idea. Everything else is bookkeeping: naming cases, looping over
them, and printing something readable when one fails.

## Worked example

One case, in bash. Copy this to `tests/run_golden.sh`, `chmod +x` it, and grow it —
this seed is deliberately not a test suite.

```bash
#!/usr/bin/env bash
# Golden tests: diff mytools against real bedtools.
# Usage: ./tests/run_golden.sh
set -uo pipefail

MYTOOLS=${MYTOOLS:-mytools}     # override to test a different build
DATA=$(dirname "$0")/../data
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
pass=0; fail=0

# check <name> -- <args...>
#   runs "$MYTOOLS <args>" and "bedtools <args>", diffs them
check() {
  local name=$1; shift; shift        # drop the literal --
  "$MYTOOLS" "$@" > "$tmp/got"  2>"$tmp/got.err"
  local got_rc=$?
  bedtools   "$@" > "$tmp/want" 2>/dev/null
  local want_rc=$?

  if [[ $got_rc -ne $want_rc ]]; then
    echo "FAIL $name (exit $got_rc, bedtools gave $want_rc)"
    sed 's/^/      /' "$tmp/got.err" | head -3
    (( fail++ )); return
  fi
  if diff -q "$tmp/want" "$tmp/got" >/dev/null; then
    echo "ok   $name"; (( pass++ ))
  else
    echo "FAIL $name"
    diff -u "$tmp/want" "$tmp/got" | sed 's/^/      /' | head -20
    (( fail++ ))
  fi
}

check "sort a.bed" -- sort -i "$DATA/a.bed"

# Add the rest here. merge and closest need sorted input -- sort into $tmp first.
# Suggested next cases:
#   merge (default), merge -d 10, intersect, intersect -u/-v/-wa,
#   subtract, closest, closest -d, and each command reading from stdin.

echo "---"
echo "$pass passed, $fail failed"
[[ $fail -eq 0 ]]
```

In Python, or your language of choice, the same thing is a parametrised test:

```python
import subprocess, pytest

CASES = [
    ("sort a.bed", ["sort", "-i", "data/a.bed"]),
    # add cases here
]

@pytest.mark.parametrize("name,args", CASES, ids=[c[0] for c in CASES])
def test_matches_bedtools(name, args):
    got  = subprocess.run(["mytools",  *args], capture_output=True, text=True)
    want = subprocess.run(["bedtools", *args], capture_output=True, text=True)
    assert got.returncode == want.returncode
    assert got.stdout == want.stdout
```

## Gotchas

- **`merge` and `closest` need sorted input.** Sort into a temp file first; don't
  assume the fixtures are sorted (`a.bed` and `b.bed` deliberately are not).
- **Compare exit codes too**, not just stdout. A command that crashes and prints
  nothing otherwise "passes" against a case whose correct answer is empty.
- **stderr is not part of the contract.** bedtools' wording is its own; don't diff it.
- **Don't sort the output before diffing.** Row order is part of the answer.

## What's in the fixtures, and why

`data/a.bed` and `data/b.bed` are BED6, small enough to read in one screen, and every
line is there for a reason. `a.bed` and `b.bed` are both **deliberately unsorted**.

| Edge case | Where |
|---|---|
| Interval at position 0 | `a01` (chr1 0-100), `b01`, `b16` |
| Zero-length interval | `a07` (chr1 500 500), `a12` (chr2 0 0), `a16`, `b02`, `b07` |
| Bookended (`end == start`) | `a01`/`a02` at 100; `a15`/`a17` at 300; `b04` at 250/300 |
| Fully nested | `a06` in `a05`; `a14` in `a13`; `a19` in `a18`; `b08` in `a09` |
| Identical coordinates | `a03`/`a04` (differ only by strand); `a09`/`a10` (fully identical) |
| Both strands | throughout; `a03`/`a04` and `a15`/`b12` exist to make `-s` matter |
| Chromosome in `-b` but not `-a` | `chr3` (`b19`) |
| Lexicographic chrom order | `chr1`, `chr2`, `chrX` — and `chr17` sorts before `chr7` |

The zero-length intervals are the interesting ones. Real bedtools does things there
that nobody predicts correctly — for example `bedtools merge` on sorted `a.bed`
reports `chr1 499 600`, expanding the zero-length feature at 500 leftwards, and
`bedtools subtract` turns `a01` into `chr1 50 99` rather than `chr1 50 100`. Whatever
bedtools prints is the answer. Encode it, add a comment, move on.

`data/genes.bed` and `data/genes.gtf` are for the gene-lookup stretch goal, not for
the bedtools comparisons — though they are ordinary BED and make perfectly good extra
fixtures if you want more than `a.bed`/`b.bed`.

`genes.gtf` is a real slice of **GENCODE v50** (GRCh38), subset to four neighbourhoods
— TP53, BRCA1, EGFR, CFTR — and otherwise unmodified. 9,354 records, 67 genes: 24
protein-coding, 23 lncRNA, 16 pseudogenes, 4 snRNA. Real attribute strings, real
multi-transcript genes, real mess.

`genes.bed` is the 25 genes in there that have a **MANE Select** transcript, as BED6.

Two things to know before you build anything on these:

- **A gene's `gene` row and its MANE transcript are not the same span.** BRCA1's
  `gene` row runs to 43,170,245; its MANE transcript stops at 43,125,364. The gene
  lookup contract defines gene coordinates as *the MANE Select span*, so a server
  backed by this GTF must filter on `tag "MANE_Select"` — reading `gene` rows is the
  easy wrong answer, and `genes.bed` will catch you.
- **MANE Select is not exclusively protein-coding.** In v50, `RNU2-1` is an snRNA
  carrying `tag "MANE_Select"`. If you filter on MANE and assume protein-coding, you
  get 25 genes where you expected 24. This is real annotation, not a trap I planted.

Sanity check, and a decent one-liner to hand your agent:

```bash
awk -F'\t' 'BEGIN{OFS="\t"} $3=="transcript" && /tag "MANE_Select"/ {
  match($9,/gene_name "[^"]+"/); n=substr($9,RSTART+11,RLENGTH-12); print $1,$4-1,$5,n,0,$7 }' data/genes.gtf \
  | bedtools sort -i - | diff - data/genes.bed && echo "GTF reproduces genes.bed"
```
