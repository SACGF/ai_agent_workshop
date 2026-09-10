# Building the workshop VMs

One VM per attendee, Ubuntu 26.04, deleted at the end of the session. Attendees
log in as `ubuntu` over SSH with a password and do everything in that account.

Two files:

- **`provision.sh`** — everything identical on every VM. Run it as root.
- **`cloud-init.yaml`** — only what differs per attendee: hostname, password,
  API key.

## The build

Golden image, not per-VM provisioning. The deciding reason is step 3: Claude
Code's first run asks about theme and trusting the directory, that state lives
in the home directory, and no amount of cloud-init can answer an interactive
prompt. Thirty people meeting it at 0:02 is thirty people who are not doing the
exercise.

```bash
# 1. one master VM from the stock Ubuntu 26.04 image, then:
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/SACGF/ai_agent_workshop/main/setup/provision.sh)"

# 2. verify, with a real key in the environment
ANTHROPIC_API_KEY=sk-... workshop-doctor        # every line must say ok

# 3. the interactive bit — accept the theme and trust prompts, then quit
claude

# 4. snapshot the VM. That snapshot is what you clone thirty times.
```

`provision.sh` is idempotent, so fix and re-run it as often as you like before
snapshotting. Budget 30–40 minutes for a cold run: the R packages and the 3 GB
reference genome dominate it. `SKIP_GENOME=1 sudo -E bash setup/provision.sh`
skips the download while you are iterating on everything else.

### Sizing the VM

Given a choice between **4 cores / 10 GB** and **2 cores / 30 GB** at the same
price, take the disk. Almost everything here waits on the network rather than
the CPU: Claude Code sessions are API-bound even three at a time, and the
fixtures are small enough that bedtools finishes before you look up. The only
real CPU consumer is one `cargo build` in a stretch goal, where two cores costs
you seconds. A full disk, by contrast, produces errors an agent will
confidently misdiagnose while its attendee loses twenty minutes.

Where the disk goes: the reference genome is **~3.1 GB unpacked**, not the ~1 GB
you see published — that figure is the gzip, and bedtools needs it uncompressed.
Ubuntu plus the toolchain (R and its packages, rustc, go, uv's Python) is a few
GB more. 30 GB leaves real headroom for cargo target directories, venvs and
whatever an attendee's agent decides to install.

On a small disk, `GENOME_CONTIGS="chr7 chr17 chrM"` cuts the genome to ~250 MB
and loses nothing the repo needs — those are the only contigs the fixtures want
*sequence* for, and `chrom.sizes` stays complete regardless, so `slop` and
`complement` still work on every contig. Measure before you commit to a size:

```bash
df -h /; du -sh /data /usr/lib/R /usr/lib/go-* 2>/dev/null
```

### Aligned reads, optionally

`WITH_BAM=1` slices a public GIAB HG002 BAM (Illumina 2x250, GRCh38) down to the
same four gene neighbourhoods as `data/genes.gtf`, giving ~2 Mb of real aligned
reads that line up with the fixtures — enough for `bedtools coverage -a
data/genes.bed -b` and `genomecov` to mean something. The source file is 122 GB
and is never downloaded: samtools pulls the index and range-requests only those
regions, so it costs a few hundred MB and several minutes.

Off by default, because nothing in the agenda needs it. If you turn it on, the
script checks the remote header for `SN:chr17` first — a contig-naming mismatch
would otherwise hand you an empty BAM with no error at all.

### What it puts on the image

- **bedtools, bcftools, samtools** — the oracle, plus the VCF exercise's foil.
- **R** with `optparse`, `data.table`, `testthat`, `lintr`, `jsonlite`, `httr2`
  and `plumber`, from precompiled binaries where the release is served. That
  covers an R attendee doing the whole day in R: CLI parsing, the unit-test and
  linter halves of guardrails, the REST client, and the gene server.
- **Python** via uv, with 3.13 and pytest pre-warmed. Ubuntu is PEP 668
  externally-managed, so `pip install` fails with a wall of text — agents reach
  for pip by default, and `uv` is the answer.
- **rustc, cargo, go** so "implement it in a language you don't know" starts in
  seconds instead of after a toolchain download.
- **`/data`** — GRCh38 primary assembly from GENCODE v50, the same release
  `data/genes.gtf` came from, so contig names and coordinates agree. With
  `.fai` and a `chrom.sizes` for `bedtools slop`/`complement`/`shuffle -g`.
  Read-only (0444), because nobody has time to re-download 3 GB at 2 pm.

`/data` versus the repo's `data/` is a collision waiting to happen — an agent
told "the data directory" will pick the wrong one. `/data/README.md` says which
is which, and so does the repo README.

The repo has to be public for this — attendees fork it, and forking needs read
access. That also makes the `curl | bash` above work without auth. Keep secrets
out of it: the API key and passwords are rendered per VM below, never committed.

## Per-VM

Render one cloud-init per attendee. Write the output somewhere outside the
repo — it contains a live API key and a password.

```bash
out=~/workshop-vms; mkdir -p "$out"; chmod 700 "$out"
for i in $(seq -w 1 30); do
  pw=$(openssl rand -base64 18 | tr -dc 'A-Za-z0-9' | head -c 20)
  key=$(sed -n "${i}p" ~/workshop-keys.txt)      # one API key per line
  sed -e "s/__HOSTNAME__/ws-$i/" \
      -e "s/__VM_PASSWORD__/$pw/" \
      -e "s|__ANTHROPIC_API_KEY__|$key|" \
      setup/cloud-init.yaml > "$out/ws-$i.yaml"
  echo "ws-$i,$pw" >> "$out/cards.csv"
done
```

Then launch each VM from the snapshot with its own file as user-data. On a bare
Ubuntu image with no snapshot, the same file still works — it detects the
missing build and runs `provision.sh` at first boot, costing several minutes and
making every VM pull from apt and GitHub simultaneously.

Boot check: `cloud-init status --wait` on the VM, or the marker file
`/var/lib/cloud/workshop-ready`.

## Passwords, and why they are fine here

- **20+ random characters, different on every VM.** Public-IP SSH is
  brute-forced continuously; a weak or shared password is a miner on your cloud
  bill inside the hour. A random 20-char is not falling in 3.5 hours.
- **Restrict SSH to the venue's public IP** in the security group if you can get
  it. Then none of the above matters.
- **Open 8000 inbound** as well, or the volunteer gene-server stretch goal
  produces a URL nobody in the room can reach.
- Delete the VMs at the end. That is the actual security control.

Print each attendee a card: hostname or IP, user `ubuntu`, their password.
`cards.csv` above is the mail merge.

## Before the day

- [ ] **`bedtools --version` on the real image.** The fixtures were measured
      against 2.31.1, and `tests/README.md` documents exact zero-length
      behaviour that a newer bedtools could change. Both of these must still
      hold, because attendees will diff against them:
      ```bash
      bedtools sort -i data/a.bed | bedtools merge -i - | grep -q '^chr1.499.600'
      bedtools subtract -a data/a.bed -b data/b.bed | grep -q '^chr1.50.99'
      ```
- [ ] **Which coreutils.** 25.10 shipped the Rust uutils implementation as
      default; if 26.04 kept it, re-run `tests/README.md`'s worked example and
      the ROT13 one-liner (`tr`, `diff`, `mktemp`, `head`) on the image rather
      than assuming.
- [ ] `workshop-doctor` all green, including the fixture round-trip, the
      `bcftools view data/broken.vcf` exit-0 premise that `issues/04` is built
      on, all seven R packages loading, and `getfasta` returning real sequence
      rather than a run of Ns (which would mean the wrong assembly).
- [ ] **R binaries or source?** `provision.sh` probes p3m.dev for this release's
      codename and falls back to building from source. Watch that line go past —
      the fallback works but turns a two-minute step into fifteen.
- [ ] `gh auth login` device flow end to end from a real VM, then
      `workshop-git-identity`, then a test commit and push to a scratch fork.
- [ ] Push a change to `.github/workflows/` on that fork. If it fails with
      *refusing to allow an OAuth App to create or update workflow*, the fix is
      `gh auth refresh -s workflow` — and it needs to be written down somewhere
      attendees will find it at 2:00.
- [ ] Enable Actions on the scratch fork (forks ship with them disabled, one
      click on the Actions tab) and confirm `gh run watch` works.
- [ ] Per-key spend caps set, one key per VM.
- [ ] 2–3 spare VMs powered on. There is no rebuild time in a 3.5-hour session,
      so recovery has to be "here is a new IP".
- [ ] Dry-run the full agenda on a clone of the snapshot.

## Notes on choices

**One user, no `su`.** Everything pre-seeded lives in a home directory — Claude
Code's onboarding state, the `gh` token, git identity, the clone. A second
account means a forgotten `su` puts someone in the wrong home with no error
message, and you debug it individually during the exercise you can least afford
to lose. The containment argument for a separate account is real but is bought
more cheaply here by spare VMs and a snapshot.

**Passwordless sudo stays.** An attendee's agent will want to install something
you did not predict, and blocking that mid-exercise is worse than the risk on a
machine being deleted at 3:20.

**`workshop-doctor` is not in the MOTD.** Checking the machine is the attendees'
first exercise (README, *Setup*) — the point is having the agent do it. The
script is for you, before you snapshot.
