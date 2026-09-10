Every fixture in `data/` is small enough to read in one screen. That was on purpose —
you can check `a.bed` by eye, which is what makes the golden tests trustworthy. But it
means nothing you have built today has met real data, and there is a decision in your
`SPEC.md` that has never been tested:

> `sort` holds the whole input in memory. Acceptable at our sizes.

Acceptable at *those* sizes. This issue is about finding out where that stops being
true, and it needs no new subcommand — just a bigger file.

## The file

`/data/HG002.neighbourhoods.bam` is real Illumina reads from GIAB's HG002, GRCh38,
sliced to the same four gene neighbourhoods as `data/genes.gtf`: TP53, BRCA1, EGFR,
CFTR. About 70x depth over ~2 Mb.

One command turns it into something `mytools` already understands:

```bash
bedtools bamtobed -i /data/HG002.neighbourhoods.bam > reads.bed
wc -l reads.bed        # ~500,000 BED6 intervals
```

That is an ordinary BED file. Every subcommand you have takes it unchanged.

## Goal

Find out how your implementation behaves at 25,000x the fixture size, and fix what
that turns up.

- [ ] `mytools sort reads.bed` still matches `bedtools sort -i reads.bed` exactly
- [ ] So do `merge`, and `intersect -a data/genes.bed -b reads.bed`
- [ ] You have timed both against real bedtools and know the ratio
- [ ] You know your peak memory (`/usr/bin/time -v`, look at maximum resident set)
- [ ] `SPEC.md`'s memory-model section says what you actually do, not what you
      assumed — update it, or change the code to match it

## What this is likely to expose

Three things, in rough order of how often they show up:

- **Reading the whole file into a list of strings.** Fine for 20 intervals. At
  500,000 it is the difference between 50 MB and 800 MB, and the fix is usually one
  line.
- **Accidentally quadratic `intersect`.** If every `-a` feature scans every `-b`
  feature, twenty by twenty is instant and half a million by twenty-five is not.
  bedtools sweeps sorted input in one pass. Do you?
- **Output buffering.** Writing 500,000 lines one `print` at a time is slower than
  you would guess.

Being slower than bedtools is fine and expected — it is C and you are not. Being
*quadratic* is not fine, and this is the file that tells you which one you are.

## The part worth arguing about

This test cannot run in CI. GitHub's runners have no `/data`, and a 25 MB fixture does
not belong in a template repo — which means the guardrail you spent the afternoon
building does not cover the failure mode most likely to bite you on real data.

That is not a reason to skip it. It is the reason to know it, and to write down in
`tests/README.md` which of your tests travel and which only run on this machine.
Generate a small deterministic slice if you want part of it in CI:

```bash
head -20000 reads.bed > tests/fixtures/reads-20k.bed    # ~1 MB, commit that
```

Ten seconds of CI beats a scale test that only ever ran once, on a VM that no longer
exists.
