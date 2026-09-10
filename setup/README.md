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

# 4. strip what verifying the VM left behind, then snapshot without reconnecting
sudo workshop-presnapshot

# 5. snapshot the VM. That snapshot is what you clone thirty times.
```

`workshop-presnapshot` is not optional hygiene. Verifying a master VM means logging
in to things, and a snapshot copies every one of those logins thirty times: your `gh`
token with `repo` scope, your git identity on everybody's commits, any Claude account
you signed in to. It also clears `machine-id` and the SSH host keys, which clones
otherwise share. It deliberately keeps `~/.claude.json` — the theme and trust answers
are the whole reason for a golden image — and strips only the credentials beside them.

Better still, don't create the problem: rehearse `gh auth login` and `/remote-control`
on a throwaway clone or your own laptop, never on the master.

`provision.sh` is idempotent, so fix and re-run it as often as you like before
snapshotting. Budget 30–40 minutes for a cold run: the R packages and the 3 GB
reference genome dominate it. `SKIP_GENOME=1 sudo -E bash setup/provision.sh`
skips the download while you are iterating on everything else.

### When a run looks stuck

Two false alarms, and "no output, no CPU" is the symptom of both. A provisioning
run that is genuinely working is always burning CPU or moving bytes.

**Stopped, not hung.** A stray `Ctrl-Z` in the tmux pane — easy when you are
reaching for `Ctrl-B` — suspends `apt-get` mid-install while it still holds the
dpkg lock. The parent shell then waits forever on a child that is never
scheduled, so the run freezes on whatever line it had last printed (a
`Processing triggers for ...` is the likely candidate, which reads convincingly
like a hang in `ldconfig`). The tell is process state `T`:

```bash
ps -eo pid,stat,wchan:20,args --forest | grep -E 'apt-get|dpkg|Rscript'
#   1892 T+  do_signal_stop  apt-get install -y bedtools bcftools ...
sudo kill -CONT 1892      # resumes exactly where it stopped, lock intact
```

`bash -c` is not interactive, so there is no job to `fg` — `SIGCONT` is the
lever. Use `tmux detach` (`Ctrl-B d`) to leave a run alone, never `Ctrl-Z`.

**Buffered, not hung.** `| tee ~/provision.log` makes stdout a pipe, so apt and
`Rscript` switch from line- to block-buffering and both the log and the pane can
lag the real position by several KB. The `ps` tree above is the honest answer to
"where is it?" — the last printed line is not. The legitimately quiet stretches
are the R packages building from source (~15 min, if the p3m probe missed) and
the genome stream.

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
Ubuntu plus the toolchain (R and its packages, rustc, uv's Python) is a few
GB more. 30 GB leaves real headroom for cargo target directories, venvs and
whatever an attendee's agent decides to install.

On a small disk, `GENOME_CONTIGS="chr7 chr17 chrM"` cuts the genome to ~250 MB
and loses nothing the repo needs — those are the only contigs the fixtures want
*sequence* for, and `chrom.sizes` stays complete regardless, so `slop` and
`complement` still work on every contig. Measure before you commit to a size:

```bash
df -h /; du -sh /data /usr/lib/R /usr/lib/rustlib 2>/dev/null
```

### Aligned reads

`provision.sh` slices a public GIAB HG002 BAM (Illumina 2x250, GRCh38) down to
the same four gene neighbourhoods as `data/genes.gtf`. Measured at ~70x depth
that is **~95 MB and roughly half a million reads** — and the read count is the
point. `bedtools bamtobed` turns it into a BED of ~500,000 intervals, against
fixtures of twenty, which is the only thing on the VM that makes `SPEC.md`'s
streaming-versus-in-memory decision testable. `issues/05-real-data-scale.md` is
built on it.

The source file is 122 GB and is never downloaded: samtools pulls the index and
range-requests the four regions, a few minutes' work. `SKIP_BAM=1` leaves it out.

The script checks the remote header for `SN:chr17` before slicing — a
contig-naming mismatch would otherwise hand you a valid, empty BAM and no error
at all. Verified against the source on 2026-09-10: it is the
`GRCh38_full_plus_hs38d1_analysis_set_minus_alts` build, chr-prefixed, so the
fixtures line up.

### What it puts on the image

- **bedtools, bcftools, samtools** — the oracle, plus the VCF exercise's foil.
- **R** with `optparse`, `data.table`, `testthat`, `lintr`, `jsonlite`, `httr2`
  and `plumber`, from precompiled binaries where the release is served. That
  covers an R attendee doing the whole day in R: CLI parsing, the unit-test and
  linter halves of guardrails, the REST client, and the gene server.
- **Python** via uv, with 3.13 and pytest pre-warmed. Ubuntu is PEP 668
  externally-managed, so `pip install` fails with a wall of text — agents reach
  for pip by default, and `uv` is the answer.
- **rustc, cargo** — Rust is the language `prompts.md` names, and a rustup
  download mid-exercise wastes five minutes. Go, Julia and the rest are
  deliberately absent: that list has no end, each costs ~1 GB on every image,
  and an attendee's agent can `apt install` one in a minute on the single box
  that wants it.
- **`/data`** — GRCh38 primary assembly from GENCODE v50, the same release
  `data/genes.gtf` came from, so contig names and coordinates agree. With
  `.fai` and a `chrom.sizes` for `bedtools slop`/`complement`/`shuffle -g`, and
  a ~95 MB slice of real GIAB HG002 reads over those same four neighbourhoods.
  Read-only (0444), because nobody has time to re-download 3 GB at 2 pm.

`/data` versus the repo's `data/` is a collision waiting to happen — an agent
told "the data directory" will pick the wrong one. `/data/README.md` says which
is which, and so does the repo README.

The repo has to be public for this — attendees fork it, and forking needs read
access. That also makes the `curl | bash` above work without auth. Keep secrets
out of it: the API key and passwords are rendered per VM below, never committed.

## Per-VM

The order is **passwords first, VMs second, IPs last**. A password is baked into the
VM at boot and cannot be read back off it afterwards, so there is nothing to collect
from a running machine — you generate the password, then create the VM with it. The
IP is the only field that works the other way around.

### 1. Render one cloud-init per attendee

Before any VM exists. Write the output somewhere outside the repo — it contains a
live API key and a password.

```bash
out=~/workshop-vms; mkdir -p "$out"; chmod 700 "$out"
for i in $(seq -w 1 30); do
  pw=$(grep -xE '[a-z]{3,7}' /usr/share/dict/words | shuf -n4 | paste -sd- -)
  key=$(sed -n "${i}p" ~/workshop-keys.txt)      # one API key per line
  sed -e "s/__HOSTNAME__/ws-$i/" \
      -e "s/__VM_PASSWORD__/$pw/" \
      -e "s|__ANTHROPIC_API_KEY__|$key|" \
      setup/cloud-init.yaml > "$out/ws-$i.yaml"
  echo "ws-$i,$pw" >> "$out/cards.csv"
done
```

Four words is ~55 bits — not falling to online guessing in an afternoon, and
typeable from a printed card with no echo by someone on an unfamiliar keyboard
layout. `openssl rand -base64 18` is stronger on paper and worse in a room: it gets
mistyped, and then mistyped again every time the venue wifi drops. Skim the column
once before printing — a system wordlist will occasionally offer a word you would
rather not hand to a room. (`/usr/share/dict/words` comes from `wamerican`; any
wordlist does.)

### 2. Create the VMs

Launch each one from the snapshot with its own file as user-data, and name the
instance after its hostname so step 3 is a join rather than a puzzle. On a bare
Ubuntu image with no snapshot the same file still works — it detects the missing
build and runs `provision.sh` at first boot, costing several minutes and making
every VM pull from apt and GitHub simultaneously.

Boot check: `cloud-init status --wait` on the VM, or the marker file
`/var/lib/cloud/workshop-ready`.

### 3. Join the IPs, then print

Export `host,ip` from whatever console or CLI your cloud gives you — `openstack
server list -f csv -c Name -c Networks`, `aws ec2 describe-instances`, the web
console's CSV download, all fine — then join on the hostname:

```bash
join -t, <(sort ips.csv) <(sort "$out/cards.csv") > "$out/cards-final.csv"
# ws-01,203.0.113.17,cobra-mantle-drift-pony
```

That file is the mail merge, and a spreadsheet is a perfectly good way to drive it.
Each card carries four lines and nothing else:

```
  ws-07
  ssh ubuntu@203.0.113.17
  cobra-mantle-drift-pony

  First thing you type after logging in:  tmux
```

The `tmux` line is not decoration. Venue wifi drops, and without it a dropped
connection kills a Claude Code session mid-exercise; with it, reconnecting and
`tmux attach` costs fifteen seconds. It also makes the balcony break in the agenda
work.

If your cloud hands out predictable DNS names, use those on the card instead and
skip the join entirely.

## Passwords, and why they are fine here

- **Four random words (~55 bits), different on every VM.** Public-IP SSH is
  brute-forced continuously; a weak or shared password is a miner on your cloud
  bill inside the hour. Four words from a 25k wordlist is not falling in 3.5
  hours, or in 3.5 years.
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
- [ ] `bedtools bamtobed -i /data/HG002.neighbourhoods.bam | wc -l` — expect
      roughly half a million. A few thousand means the slice missed.
- [ ] **R binaries or source?** `provision.sh` probes p3m.dev for this release's
      codename and falls back to building from source. Watch that line go past —
      the fallback works but turns a two-minute step into fifteen.
- [ ] **`/remote-control` from your own account**, for the 1:45 balcony break. It
      needs a Pro/Max/Team/Enterprise login and **does not work with API keys**, so
      the workshop key on each VM cannot drive it. Test the demo you will give from
      the front (`unset ANTHROPIC_API_KEY`, `claude`, `/login`, `/remote-control`,
      scan the QR with your phone), and check there is usable signal wherever you
      send the room for air. Nothing later in the agenda depends on it.
- [ ] **The warm-up runs on the image.** Both halves of the 0:15 exercise, since it
      is the first thing thirty people do at once:
      ```bash
      Rscript -e 'cat("ok\n")' && python3 -c 'print("ok")'
      diff <(printf 'a\n') <(printf 'a\n') && echo "process substitution ok"
      ```
- [ ] `gh auth login` device flow end to end from a real VM, then
      `workshop-git-identity`, then a test commit and push to a scratch fork.
- [ ] Push a change to `.github/workflows/` on that fork. If it fails with
      *refusing to allow an OAuth App to create or update workflow*, the fix is
      `gh auth refresh -s workflow` — and it needs to be written down somewhere
      attendees will find it at 2:00.
- [ ] Enable Actions on the scratch fork (forks ship with them disabled, one
      click on the Actions tab) and confirm `gh run watch` works.
- [ ] **Send the fork link in the joining email.** Attendees fork in the browser
      themselves (`gh repo fork` is the step a locked-down GitHub account fails at),
      so having them click it a day early surfaces SSO and repo-creation problems
      before 0:05 rather than during it. Forking early costs them nothing — forks
      don't copy issues either way.
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
