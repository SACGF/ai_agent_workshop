# Building the workshop VMs

One VM per attendee, Ubuntu 26.04, deleted at the end of the session. Attendees
log in as `ubuntu` over SSH with a password and do everything in that account.

Two files:

- **`provision.sh`** — everything identical on every VM. Run it as root.
- **`cloud-init.yaml`** — the per-VM layer, which on reflection is one shared
  password and nothing else. Hostnames come from Nectar's instance names, and
  attendees sign in to Claude themselves with one of the workshop subscription
  accounts.

## The build

Golden image, not per-VM provisioning. The reason is time: a cold build is 30–40
minutes of apt, R packages and a 3 GB genome, and thirty VMs doing that
simultaneously at 0:00 is thirty people watching a progress bar. Build once,
clone the result.

The image ships **signed out of everything** — no Claude login, no `gh` token, no
git identity. Attendees do their own `/login` and their own theme prompt; it is
their machine for the afternoon, and the alternative is baking one person's
credentials into every VM.

```bash
# 1. one master VM from the stock Ubuntu 26.04 image, then:
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/SACGF/ai_agent_workshop/main/setup/provision.sh)"

# 2. verify
workshop-doctor                                 # every line must say ok

# 3. strip what verifying the VM left behind
sudo workshop-presnapshot

# 4. snapshot the VM, without reconnecting first. That snapshot is what you clone.
```

`workshop-presnapshot` is not optional hygiene. Verifying a master VM means logging in
to things, and a snapshot copies every one of those logins to every clone: your `gh`
token with `repo` scope, your git identity on everybody's commits, any Claude account
you signed in to. It removes `~/.claude`, `~/.claude.json`, `~/.config/gh` and
`~/.gitconfig` outright, clears `machine-id`, and deletes the SSH host keys that clones
would otherwise share. Then it audits itself and greps for leftover credential
material, because "I think I logged out" is not a check.

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
access. That also makes the `curl | bash` above work without auth. Keep secrets out of
it: passwords and account credentials are rendered per VM below, never committed.

## Deploying on Nectar

**One cloud-init, one password, every VM.** Twenty-four rendered files and twenty-four
passwords buy you isolation you don't want to pay for here: these VMs live for one
afternoon and are deleted at the end of it. The single mitigation worth having is the
security group below, and it is worth more than per-VM passwords were.

The password still can't be read back off a running VM — it is baked in at boot — so
generate it before you launch anything.

### 1. Render the one file

```bash
out=~/workshop-vms; mkdir -p "$out"; chmod 700 "$out"
pw=$(grep -xE '[a-z]{3,7}' /usr/share/dict/words | shuf -n4 | paste -sd- -)
sed "s/__VM_PASSWORD__/$pw/" setup/cloud-init.yaml > "$out/workshop.yaml"
echo "$pw"        # goes on the projector, not on a card
```

Four words beats `openssl rand -base64 18` for the only property that matters now:
everyone in the room has to type it, from the projector, with no echo, on whatever
keyboard layout their laptop has. Skim it before you show it — a system wordlist will
occasionally offer a word you'd rather not put on a screen. (`/usr/share/dict/words`
comes from `wamerican`; any wordlist does.)

Keep `$out` out of the repo. It holds a live password.

### 2. Security group

Nectar's default group denies inbound, so SSH needs a rule. Restrict 22 to the venue's
public IP if you can get it — that one rule does more than anything else here, because
it means nothing else has to be airtight.

```bash
openstack security group create workshop
openstack security group rule create --proto tcp --dst-port 22 \
    --remote-ip <venue-ip>/32 workshop          # drop --remote-ip to allow the world
openstack security group rule create --proto tcp --dst-port 8000 workshop
```

Port 8000 is for the gene-server stretch goal: a volunteer serves on `0.0.0.0:8000` and
the room reaches it by public IP. Without the rule that exercise produces a URL nobody
can open.

### 3. Launch all of them at once

From the snapshot, same user-data for every instance. In the **dashboard**: Launch
Instance → Source → Instance Snapshot → your snapshot; Flavour; **Count: 24**; Security
Groups → `workshop`; Configuration → paste `workshop.yaml` as the Customisation Script.
Nectar names them `ws-1 … ws-24`, and cloud-init takes each hostname from the instance
name — which is why the file no longer sets one.

Or the CLI:

```bash
openstack server create \
  --image <your-snapshot> --flavor <your-flavour> \
  --security-group workshop --key-name <your-keypair> \
  --user-data "$out/workshop.yaml" \
  --min 24 --max 24 ws
```

`--key-name` is your own recovery route, not the attendees' — Nectar expects a key pair
at launch and they are logging in with the password. Check your flavour's **root disk**
against *Sizing the VM* above before you commit to 24 of them: the genome wants ~3.5 GB
and the toolchain several more. If the flavour is too small, either attach a volume or
rebuild the image with `GENOME_CONTIGS="chr7 chr17 chrM"`.

On a bare Ubuntu image with no snapshot the same file still works — it detects the
missing build and runs `provision.sh` at first boot, costing several minutes per VM and
making all of them pull from apt and GitHub simultaneously.

Boot check: `cloud-init status --wait` on one VM, or the marker file
`/var/lib/cloud/workshop-ready`.

#### Or bake the password in and skip user-data entirely

Measured, not assumed: setting the password with `chpasswd` on the master and
snapshotting **does not work**. Password login works on the master and fails on every
clone. A clone boots with a new instance-id, so cloud-init re-runs its per-instance
modules, and the `users` module applies the distro default `lock_passwd: true` to
`ubuntu` — your password arrives in `/etc/shadow` and is locked at first boot.
`passwd -S ubuntu` on a clone says `L`.

The fix is to put the password where cloud-init will apply it *on every clone*, in a
config file on the image. `set_passwords` runs after the users module, every time, so
it wins:

```bash
sudo workshop-set-password '<the shared password>'
```

That writes `/etc/cloud/cloud.cfg.d/99-workshop-password.cfg` (0600, plain text — the
snapshot carries it, which is the point and also the reason not to keep or share that
image), sets the password on the master too, and drops a `00-workshop.conf` that beats
the cloud image's `60-cloudimg-settings.conf`. `workshop-doctor` reports whether it is
in place.

Then launch with no Customisation Script at all. **Boot one clone and log in before
building the other 23** — that is a two-minute check against a mistake that otherwise
shows up as twenty-four unreachable VMs.

### 4. Collect the IPs and print the cards

```bash
openstack server list --name 'ws-' -f value -c Name -c Networks \
  | awk '{sub(/.*=/,"",$2); print $1","$2}' | sort -V > "$out/ips.csv"
```

Eyeball it — a VM with more than one address prints more than one, and you want the
public one. That file plus your list of Claude accounts is the mail merge; a
spreadsheet is a perfectly good way to drive it. Each card then needs only two things,
because the VM password is on the projector:

```
  ws-07     ssh ubuntu@203.0.113.17

  Claude    workshop-07@example.org
            <that account's password>

  First thing you type after logging in:  tmux
```

The `tmux` line is not decoration. Venue wifi drops, and without it a dropped
connection kills a Claude Code session mid-exercise; with it, reconnecting and
`tmux attach` costs fifteen seconds. It also makes the balcony break in the agenda
work.

### The Claude accounts

One workshop subscription account per attendee, `/login` on their own VM. Worth the
handling rather than a baked-in credential: a `CLAUDE_CODE_OAUTH_TOKEN` from
`claude setup-token` authenticates model requests but **cannot establish a Remote
Control session**, and API keys can't either. Only a real `/login` does both, and
Remote Control is the 1:45 exercise.

So `/login` happens once per VM. The only question is who does it:

- **Attendees log in at 0:05.** One more browser step in a block that already has two.
  Test the flow end to end on one account first: if signing in needs an emailed
  verification code, the attendee has to be able to read that mailbox, and two dozen
  people waiting on you to relay codes is the worst five minutes of the day.
- **You log in on each clone beforehand** — recommended if those accounts use emailed
  codes. Fold it into the clone-and-verify pass: boot, `claude`, `/login`, quit. Two
  dozen browser flows is dull, but it is dull *the day before*, and attendees start at
  a working prompt. The credential lands in `~/.claude/.credentials.json` on a VM the
  attendee has root on, which is fine for a disposable account you delete afterwards —
  and it is exactly why `workshop-presnapshot` runs *before* the snapshot, never after
  these logins.

Either way the account and its password go on the card, because `/login` asks again if
a session is lost.

## Passwords, and why they are fine here

- **One four-word password, shared across all the VMs.** Deliberate: it goes on the
  projector, twenty-four people type it once, and there is no per-VM rendering, no
  card to mistype and no join to get wrong. Four words from a 25k wordlist is ~55
  bits, so the shared part is the exposure, not the strength.
- **Restrict SSH to the venue's public IP** in the security group. This is the control
  that actually matters — public-IP SSH is brute-forced continuously, and one shared
  password means one guess compromises the set rather than one VM. With the rule, that
  whole sentence stops applying.
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
- [ ] **`/remote-control` end to end on a workshop account**, for the 1:45 balcony
      break — `claude`, `/login`, `/remote-control`, scan the QR with your phone.
      Everyone is on a subscription login now, so this works for the whole room and is
      a real exercise rather than a demo. Check there is usable signal wherever you
      send people for air.
- [ ] **One workshop Claude account, signed in from a clean clone.** Whether that
      login wants a password or an emailed code decides who does the two dozen
      `/login`s — see *The Claude accounts* above. Find out before the day, not at
      0:05.
- [ ] **Plan limits.** Each account has its own session limit, and the 0:55 block runs
      three agents at once on purpose. Know what plan these accounts are on, tell the
      room to plan on the strong model and execute on the cheap one, and point at
      `/usage` so people can see a limit coming rather than hitting it.
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
- [ ] **Nectar allocation headroom.** 24 instances plus spares needs the instance and
      VCPU quota to match, and a quota refusal at launch time is a slow thing to fix.
      Check it the week before, not the morning of.
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
machine being deleted at the end of the workshop.

**`workshop-doctor` is not in the MOTD.** Checking the machine is the attendees'
first exercise (README, *Setup*) — the point is having the agent do it. The
script is for you, before you snapshot.
