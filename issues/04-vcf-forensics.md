`data/broken.vcf` is 20,002 variants. `bcftools view` reads it and exits 0. `pysam`
parses every record without raising. It is still out of spec in **13 places**.

That gap is the whole exercise. "It parsed" is not "it is valid", and a tool warning on
stderr with a zero exit code is invisible to CI unless somebody chose to look.

## Goal

A `mytools vcf-validate` (or a standalone script — your call) that reads a VCF and
reports every spec violation it finds, with line numbers. Plus **unit tests for it**,
running in CI.

## Why this one needs unit tests

The bedtools work has an oracle: when you're unsure, you run real `bedtools` and diff.
There is no oracle here. `bcftools` is a parser, not a validator — it will happily read
things the spec forbids, and it cannot tell you the right answer.

So the only way to know your validator works is to test it directly: a tiny fixture per
rule, asserting it fires on the bad case **and stays silent on a good one**. A validator
that flags everything finds all 13 violations and is worthless. Both halves of each test
matter.

This is the exercise where unit tests stop being homework and start being the only
instrument you have.

## Acceptance criteria

- [ ] Reports violations as `line number, rule, one-line explanation`
- [ ] Exits non-zero when any violation is found — this is the part CI depends on
- [ ] Unit tests: for each rule, one minimal VCF that violates it and one that doesn't
- [ ] Unit tests run without `bcftools` installed and finish in seconds
- [ ] Wired into `.github/workflows/ci.yml` alongside the golden tests and the linter
- [ ] Run against `data/broken.vcf`, it finds violations you can point at in the file

## Where to start

The spec is [VCF v4.3](https://samtools.github.io/hts-specs/VCFv4.3.pdf). Don't read all
44 pages — have your agent read it and enumerate checkable rules, then you pick which to
implement. Some categories to prime the pump:

- **Header/data agreement.** Is every INFO key, FORMAT key, FILTER value and contig used
  in a record actually declared in the header?
- **Cardinality.** `Number=A` means one value per ALT. `Number=R` means REF plus each
  ALT. `Number=G` means one per genotype — for diploid with n alleles that is n(n+1)/2.
  Three fields, one rule, three chances to get it wrong.
- **Types.** A `Number=0, Type=Flag` field never carries a value. QUAL is a phred score.
- **Referential integrity.** Does every allele index in a `GT` refer to an allele that
  exists at that site?
- **Coordinates.** VCF is **1-based**. (BED is 0-based half-open, GTF is 1-based
  inclusive. All three are in this repo. Yes, on purpose.)
- **Ordering and consistency.** Sorted by POS within a contig? Any site claiming two
  different REF alleles?

## The negative control you now have

`data/hg002.vcf.gz` is a real, valid VCF — GIAB's HG002 benchmark, unmodified, over
the same four gene neighbourhoods as the rest of `data/`. 2,436 records with genuinely
messy INFO and FORMAT fields: `Number=A` and `Number=R` arrays, multi-platform
provenance keys, `GT:PS:DP:ADALL:AD:GQ`.

**Your validator must report zero violations on it.** That is not a suggestion — it is
the other half of every test you write. A rule that fires on `broken.vcf` and also
fires on the GIAB truth set has not found a bug in GIAB; it has found a bug in your
rule, and it would have gone unnoticed while you congratulated yourself on a high
count.

```bash
mytools vcf-validate data/hg002.vcf.gz     # want: no output, exit 0
mytools vcf-validate data/broken.vcf       # want: violations, exit non-zero
```

Run both every time. The second number is meaningless without the first.

## Scoring yourself

`data/broken.vcf.answers.rot13` has the full list, ROT13'd so you don't spoil it by
accident. Decode it **after** you've found what you can:

```bash
tr 'A-Za-z' 'N-ZA-Mn-za-m' < data/broken.vcf.answers.rot13 | less
```

Finding 6 puts you level with every tool on the VM combined. Seven of the thirteen are
invisible to all of them.

## Notes

- Don't compare against `bcftools` output — it is not a validator and will mislead you.
  It's useful as a *contrast*: show what it misses.
- One rule per test, one rule per commit. This suite is the thing you're keeping.
