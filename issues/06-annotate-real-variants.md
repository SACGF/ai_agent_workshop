`data/hg002.vcf.gz` is 2,436 real variant calls: GIAB's HG002 benchmark (NISTv4.2.1,
GRCh38), subset to the same four gene neighbourhoods as everything else in `data/`.
2,019 SNVs and 418 indels, with real INFO and FORMAT fields — `platforms`, `callsets`,
`difficultregion`, `GT:PS:DP:ADALL:AD:GQ`. Nothing has been modified.

`data/hg002.highconf.bed` is the 387 regions GIAB is confident about across those same
neighbourhoods. They cover 94% of the span. **119 of the 2,436 variants fall outside
them**, and that gap is not noise — it is where the benchmark itself declines to make
a claim.

This is the issue where the interval code you built this morning does a real job.

## Goal

Answer, from the command line: **which variants hit which gene, and which of those can
I trust?**

```
mytools annotate --vcf data/hg002.vcf.gz --genes data/genes.bed
mytools annotate --vcf data/hg002.vcf.gz --genes data/genes.bed \
                 --confident data/hg002.highconf.bed
```

Shape of the output is yours — per-variant with a gene column, or per-gene counts, or
both behind a flag. Decide it, then write it in `SPEC.md` before you write code.

## Acceptance criteria

- [ ] Per-gene counts match the oracle exactly:
      `bedtools intersect -a data/genes.bed -b data/hg002.vcf.gz -c`
- [ ] Per-variant gene assignment matches
      `bedtools intersect -a data/hg002.vcf.gz -b data/genes.bed -wa -wb`
- [ ] `--confident` drops the 119 variants outside the high-confidence regions
- [ ] Genes with zero variants still appear in per-gene output. Two of the 25 have
      none — that is an answer, not an absence
- [ ] Indel spans are right (see below), verified against bedtools rather than argued
- [ ] Golden tests for all of the above, wired into CI. These fixtures are committed,
      so unlike `issues/05`, this one *does* travel

## The trap: three coordinate systems, all of them in this repo

- **VCF POS is 1-based inclusive.**
- **BED is 0-based half-open.**
- **GTF is 1-based inclusive.**

`genes.bed` was derived from `genes.gtf`. The variants come from a VCF. You are
joining them. This is the same off-by-one as the morning's exercise, except now it is
load-bearing and there are three conventions instead of one.

A SNV at POS *p* occupies one base, which in BED is `[p-1, p)`. An indel is where it
gets interesting, because the interval a variant occupies is defined by the length of
**REF**, not ALT:

```
chr7   54722325   T    TTC     insertion — REF is 1 bp
chr7   54725713   TA   T       deletion  — REF is 2 bp
```

The longest REF in this file is 40 bp. Do not reason about it from first principles —
you already know how that goes. Run bedtools on the fixture, look at what it prints,
and match it. That is the whole method.

## Going further

Three directions, roughly in order of ambition:

1. **Annotate with the transcript, not just the gene.** `genes.gtf` has exons.
   Is the variant exonic, intronic or intergenic? That is `intersect` against a
   different set of intervals — no new algorithm, just a different BED.
2. **Cross-check the depth.** Each record carries `DP` in FORMAT. The reads that
   produced it are in `/data/HG002.neighbourhoods.bam` (see `issues/05`). Does
   `bedtools coverage` at that position agree with what the VCF claims? Two
   independent files that should tell the same story, which is the shape of most
   real validation work.
3. **Report on the difficult regions.** Many records carry a `difficultregion` INFO
   field naming why. Which genes are worst affected, and does that correlate with the
   high-confidence gaps?

## Why this is the right last exercise

Everything before it had one moving part. This has four files, three coordinate
systems and a real question, and it is exactly the kind of task that used to be an
afternoon of careful work. Notice how long it takes you now. That is the thing the
workshop is actually measuring.
