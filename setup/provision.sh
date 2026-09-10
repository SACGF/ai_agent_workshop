#!/usr/bin/env bash
# Provision a workshop VM: "Agentic Coding for Bioinformaticians".
#
# Run as root on Ubuntu 26.04, on the master VM you are about to snapshot:
#
#   sudo bash setup/provision.sh
#   sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/SACGF/ai_agent_workshop/main/setup/provision.sh)"
#
# Idempotent — re-run it after editing. Installs no secrets: the per-VM API key
# and password are cloud-init's job (setup/cloud-init.yaml).
set -euo pipefail

WORKSHOP_USER=${WORKSHOP_USER:-ubuntu}
REPO_URL=${REPO_URL:-https://github.com/SACGF/ai_agent_workshop}
[ "$(id -u)" -eq 0 ] || { echo "run me as root: sudo bash $0" >&2; exit 1; }
id "$WORKSHOP_USER" >/dev/null || { echo "no such user: $WORKSHOP_USER" >&2; exit 1; }

as_user() { su - "$WORKSHOP_USER" -c "$1"; }
say() { printf '\n== %s\n' "$1"; }

export DEBIAN_FRONTEND=noninteractive

say "Stopping background apt work"
# Unattended upgrades steal the dpkg lock. An attendee's agent then hits
# "Could not get lock" mid-exercise and misdiagnoses it for ten minutes.
systemctl disable --now unattended-upgrades.service apt-daily.timer \
                        apt-daily-upgrade.timer 2>/dev/null || true

# needrestart's TUI blocks any apt install an agent runs non-interactively.
mkdir -p /etc/needrestart/conf.d
cat > /etc/needrestart/conf.d/99-workshop.conf <<'EOF'
$nrconf{restart} = 'a';
$nrconf{kernelhints} = 0;
EOF

say "Installing packages"
apt-get update
apt-get install -y \
  bedtools bcftools samtools tabix \
  tmux git curl jq less \
  build-essential python3-venv python3-dev \
  rustc cargo \
  ca-certificates gnupg wget unzip vim nano tree ripgrep htop
#  ^ bedtools is the oracle for every golden test; bcftools backs the "it parsed
#    and exited 0" contrast in issues/04; tmux is named verbatim in the
#    parallel-agents prompt; less is in the ROT13 answer-key one-liner; rustc and
#    cargo because Rust is the language prompts.md actually names, and a rustup
#    download mid-exercise is a bad way to spend five minutes.
#
#    Deliberately NOT here: Go, Julia, and everything else the "language you
#    don't know" goal might reach for. That list has no end, each one costs
#    ~1 GB of every image, and attendees have passwordless sudo — an agent asked
#    for Go installs it in a minute, on the one box that wants it.

say "Installing R"
# A lot of this room is R-first. testthat and lintr cover the unit-test and
# linter halves of the guardrails exercise; plumber is the R flavour of the
# gene-server stretch goal; httr2 and jsonlite are the gene-lookup client.
apt-get install -y r-base r-base-dev \
  libcurl4-openssl-dev libssl-dev libxml2-dev libgit2-dev libfontconfig1-dev \
  libharfbuzz-dev libfribidi-dev

# Precompiled Linux binaries where this release is served — building data.table
# and httr2 from source costs about fifteen minutes. Paid once, on the image,
# but there is no reason to pay it at all.
. /etc/os-release
P3M="https://p3m.dev/cran/__linux__/${VERSION_CODENAME}/latest"
if curl -fsL --max-time 15 -o /dev/null "$P3M/src/contrib/PACKAGES"; then
  CRAN="$P3M"; echo "using binary CRAN: $CRAN"
else
  CRAN="https://cloud.r-project.org"; echo "no binaries for $VERSION_CODENAME, building from source"
fi
Rscript -e "options(warn=2); install.packages(
    c('optparse','data.table','testthat','lintr','jsonlite','httr2','plumber'),
    repos='$CRAN', Ncpus=max(1, parallel::detectCores()))" \
  || echo "WARNING: some R packages failed — check before snapshotting"

say "Installing GitHub CLI"
# From the official repo, so the version is known rather than whatever universe
# happens to carry this cycle.
install -m 0755 -d /usr/share/keyrings
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
  -o /usr/share/keyrings/githubcli-archive-keyring.gpg
chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
  > /etc/apt/sources.list.d/github-cli.list
apt-get update
apt-get install -y gh

say "Installing uv and Claude Code as $WORKSHOP_USER"
# Both land in ~/.local/bin. Never install these as root — Claude Code declines
# to run as root anyway, and it is not how anyone should be working.
as_user 'command -v uv     >/dev/null || curl -LsSf https://astral.sh/uv/install.sh | sh'
as_user 'command -v claude >/dev/null || curl -fsSL https://claude.ai/install.sh | bash'

say "Pre-warming caches"
# So thirty agents are not all downloading a Python interpreter at 0:05.
as_user 'uv python install 3.13' || true
as_user 'uv tool install pytest' || true
as_user 'claude --version'       || true

say "Shell environment"
cat > /etc/profile.d/99-workshop.sh <<'EOF'
# uv and claude install here; ~/.local/bin is only auto-added by .profile if it
# existed at login, which it did not on first boot.
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) PATH="$HOME/.local/bin:$PATH" ;; esac
export PATH
# ANTHROPIC_API_KEY is written per-VM by cloud-init, not baked into the image.
[ -r /etc/workshop-api-key ] && . /etc/workshop-api-key
EOF

git config --system init.defaultBranch main
git config --system --add safe.directory '*'

say "Helper scripts"
# git commits fail on an unconfigured identity and `gh auth login` does not set
# one. Nothing in the README covers this, so make it one command.
cat > /usr/local/bin/workshop-git-identity <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
gh auth status >/dev/null 2>&1 || { echo "Run 'gh auth login' first."; exit 1; }
login=$(gh api user --jq .login)
name=$(gh api user --jq '.name // .login')
id=$(gh api user --jq .id)
git config --global user.name  "$name"
# GitHub's noreply address: commits link to the account, no real address in the log.
git config --global user.email "${id}+${login}@users.noreply.github.com"
echo "git identity: $(git config --global user.name) <$(git config --global user.email)>"
EOF
chmod 0755 /usr/local/bin/workshop-git-identity

# Organiser's pre-flight. Deliberately NOT mentioned in the MOTD: checking the
# machine is the attendees' first exercise, and a doctor script does it for them.
cat > /usr/local/bin/workshop-doctor <<'EOF'
#!/usr/bin/env bash
# Verify the image. Run before you snapshot, and on one clone afterwards.
fail=0
check() {
  local label=$1; shift
  if out=$("$@" 2>&1); then printf 'ok   %-20s %s\n' "$label" "$(head -1 <<<"$out")"
  else printf 'FAIL %-20s %s\n' "$label" "$(head -1 <<<"$out")"; fail=1; fi
}
check bedtools bedtools --version;  check bcftools bcftools --version
check samtools samtools --version;  check gh       gh --version
check git      git --version;       check tmux     tmux -V
check jq       jq --version;        check uv       uv --version
check claude   claude --version;    check rustc    rustc --version
check python3  python3 --version
check Rscript  Rscript --version
check "R pkgs" Rscript -e 'invisible(lapply(c("optparse","data.table","testthat","lintr","jsonlite","httr2","plumber"), library, character.only=TRUE)); cat("all seven load\n")'
if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
  echo "ok   ANTHROPIC_API_KEY    set (${#ANTHROPIC_API_KEY} chars)"
else
  echo "FAIL ANTHROPIC_API_KEY    empty"; fail=1
fi
# Egress: an agent hitting a blocked endpoint looks exactly like a bug.
for url in https://api.anthropic.com https://github.com https://cdotlib.org; do
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$url" || echo 000)
  if [ "$code" != 000 ]; then printf 'ok   %-20s HTTP %s\n' "${url#https://}" "$code"
  else printf 'FAIL %-20s unreachable\n' "${url#https://}"; fail=1; fi
done
# The fixture round-trip from tests/README.md, against the real toolchain.
repo=${1:-/opt/ai_agent_workshop}
if [ -f "$repo/data/genes.gtf" ]; then
  awk -F'\t' 'BEGIN{OFS="\t"} $3=="transcript" && /tag "MANE_Select"/ {
    match($9,/gene_name "[^"]+"/); n=substr($9,RSTART+11,RLENGTH-12); print $1,$4-1,$5,n,0,$7 }' \
    "$repo/data/genes.gtf" | bedtools sort -i - | diff -q - "$repo/data/genes.bed" >/dev/null \
    && echo "ok   fixture round-trip   genes.gtf reproduces genes.bed" \
    || { echo "FAIL fixture round-trip"; fail=1; }
  # bcftools reads broken.vcf and exits 0 — the premise of issues/04. If a newer
  # bcftools starts rejecting it, that exercise needs rewording.
  if bcftools view "$repo/data/broken.vcf" >/dev/null 2>&1; then
    echo "ok   broken.vcf           bcftools view exits 0, as issues/04 claims"
  else
    echo "FAIL broken.vcf           bcftools now rejects it — issues/04 needs rewording"; fail=1
  fi
fi
# Reference genome, and a real getfasta rather than an ls.
if [ -s /data/GRCh38.fa.fai ]; then
  echo "ok   /data/GRCh38.fa      $(cut -f1 /data/GRCh38.fa.fai | wc -l) contigs, $(du -h /data/GRCh38.fa | cut -f1)"
  if [ -f "$repo/data/genes.bed" ]; then
    seq=$(head -1 "$repo/data/genes.bed" | bedtools getfasta -fi /data/GRCh38.fa -bed - 2>/dev/null | tail -1)
    case "$seq" in
      ""|*[!ACGTNacgtn]*) echo "FAIL getfasta            no sequence back"; fail=1 ;;
      *[ACGTacgt]*)       echo "ok   getfasta            real sequence for $(head -1 "$repo/data/genes.bed" | cut -f4)" ;;
      *)                  echo "FAIL getfasta            all N — wrong assembly or contig names"; fail=1 ;;
    esac
  fi
else
  echo "FAIL /data/GRCh38.fa      missing (SKIP_GENOME set?)"; fail=1
fi
if [ -s /data/HG002.neighbourhoods.bam.bai ]; then
  n=$(samtools view -c /data/HG002.neighbourhoods.bam 2>/dev/null || echo 0)
  if [ "$n" -gt 0 ]; then echo "ok   HG002 bam            $n reads, $(du -h /data/HG002.neighbourhoods.bam | cut -f1)"
  else echo "FAIL HG002 bam            empty — contig naming mismatch?"; fail=1; fi
fi
exit $fail
EOF
chmod 0755 /usr/local/bin/workshop-doctor

say "Message of the day"
cat > /etc/motd <<'EOF'

  Agentic Coding for Bioinformaticians
  ------------------------------------
  This VM is disposable and gets deleted at the end of the session.
  Anything you want to keep, push to your fork.

    1.  gh auth login          browser on your laptop, code from here
    2.  workshop-git-identity  sets your git name/email from GitHub
    3.  claude                 start here, it does the rest

  https://github.com/SACGF/ai_agent_workshop

EOF

say "Local copy of the template"
# For the doctor's fixture check, and as a fallback if GitHub is unreachable
# from the venue. Attendees still fork and clone their own.
if [ -d /opt/ai_agent_workshop/.git ]; then
  git -C /opt/ai_agent_workshop pull --ff-only || true
else
  git clone --depth 1 "$REPO_URL" /opt/ai_agent_workshop || true
fi

say "Reference genome"
# GRCh38 primary assembly from GENCODE v50 — the same release data/genes.gtf
# came from, so contig names and coordinates agree.
#
# Full assembly by default: ~3.1 GB unpacked (the ~1 GB you see published is
# the gzip, and bedtools needs it uncompressed). That is the right call on a
# 30 GB disk, and it means getfasta works on whatever an attendee brings rather
# than only on our fixtures.
#
# On a small disk, subset instead. The only fixtures needing real *sequence*
# are genes.bed and genes.gtf, both chr7 and chr17 — about 250 MB. a.bed and
# b.bed sit at coordinates 0-600, which in a real genome is telomeric N, so
# there is nothing there to read anyway.
#
# Chromosome *lengths* are separate: bedtools slop/complement/shuffle want -g
# for every contig, and that file is a few KB. So we stream the download,
# write sequence only for the contigs we keep, and measure lengths for all of
# them on the way past. chrom.sizes is complete either way, and peak disk is
# whatever we kept — never the whole assembly plus its gzip.
#
#   GENOME_CONTIGS="chr7 chr17 chrM"   ~250 MB, everything the repo needs
#   GENOME_CONTIGS=all                 the default
#   SKIP_GENOME=1                      skip it entirely
GENOME_DIR=${GENOME_DIR:-/data}
GENOME_CONTIGS=${GENOME_CONTIGS:-all}
GENOME_URL=${GENOME_URL:-https://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_human/release_50/GRCh38.primary_assembly.genome.fa.gz}
if [ -n "${SKIP_GENOME:-}" ]; then
  echo "SKIP_GENOME set — skipping"
elif [ -s "$GENOME_DIR/GRCh38.fa.fai" ]; then
  echo "already present at $GENOME_DIR/GRCh38.fa"
else
  mkdir -p "$GENOME_DIR"
  # Check before spending six minutes on a download that cannot land. The
  # toolchain above (R, rust, go, uv's Python) eats several GB, so free space
  # here is not what it was when the VM booted.
  need=1; [ "$GENOME_CONTIGS" = all ] && need=4
  free_gb=$(df -BG --output=avail "$GENOME_DIR" | tail -1 | tr -dc 0-9)
  if [ "${free_gb:-0}" -lt "$need" ]; then
    echo "ERROR: ${free_gb}G free in $GENOME_DIR, need ~${need}G for GENOME_CONTIGS=$GENOME_CONTIGS"
    echo "       Either give the VM a bigger disk, or re-run with the subset:"
    echo "         GENOME_CONTIGS=\"chr7 chr17 chrM\" sudo -E bash \$0    # ~250 MB"
    echo "       That covers every contig the fixtures need sequence for, and"
    echo "       chrom.sizes stays complete either way."
    exit 1
  fi
  # A part-file from an interrupted run is dead weight — several GB of it.
  # Clear it however we leave this block.
  trap 'rm -f "$GENOME_DIR/.genome.fa.part" "$GENOME_DIR/.chrom.sizes.part"' EXIT
  echo "streaming $GENOME_URL, keeping: $GENOME_CONTIGS (${free_gb}G free)"
  # Write to temp names, so an interrupted download never looks complete.
  curl -fL --retry 3 --retry-delay 5 "$GENOME_URL" | gzip -dc | awk \
    -v want="$GENOME_CONTIGS" -v sizes="$GENOME_DIR/.chrom.sizes.part" '
    BEGIN { if (want == "all") all=1; else { n=split(want,a," "); for(i=1;i<=n;i++) w[a[i]]=1 } }
    /^>/ { name=substr($0,2); sub(/[ \t].*/,"",name); ord[++k]=name
           keep = (all || (name in w)); if (keep) print; next }
         { len[name] += length($0); if (keep) print }
    END  { for(i=1;i<=k;i++) printf "%s\t%d\n", ord[i], len[ord[i]] > sizes }
  ' > "$GENOME_DIR/.genome.fa.part"
  mv "$GENOME_DIR/.genome.fa.part"  "$GENOME_DIR/GRCh38.fa"
  mv "$GENOME_DIR/.chrom.sizes.part" "$GENOME_DIR/GRCh38.chrom.sizes"
  trap - EXIT
  samtools faidx "$GENOME_DIR/GRCh38.fa"
  echo "kept $(cut -f1 "$GENOME_DIR/GRCh38.fa.fai" | tr '\n' ' ')-- $(du -h "$GENOME_DIR/GRCh38.fa" | cut -f1)"
  echo "chrom.sizes covers $(wc -l < "$GENOME_DIR/GRCh38.chrom.sizes") contigs"
fi

if [ -s "$GENOME_DIR/GRCh38.fa.fai" ]; then
  n_contigs=$(wc -l < "$GENOME_DIR/GRCh38.fa.fai")
  cat > "$GENOME_DIR/README.md" <<EOF
# /data — reference genome

Read-only. Not the same thing as \`data/\` inside the workshop repo, which holds
the small BED/GTF/VCF fixtures the exercises are built on. This directory is for
the bedtools subcommands that need real sequence or chromosome lengths.

    GRCh38.fa               GENCODE v50 primary assembly, $n_contigs contigs,
                            $(du -h "$GENOME_DIR/GRCh38.fa" | cut -f1). Same release as the
                            repo's data/genes.gtf, so contig names agree.
    GRCh38.fa.fai           samtools faidx index
    GRCh38.chrom.sizes      every contig in the assembly and its length. This is
                            what bedtools calls a genome file (-g).

Sequence for the gene spans in the repo:

    bedtools getfasta -fi /data/GRCh38.fa -bed ~/ai_agent_workshop/data/genes.bed -name

1 kb of flank either side, without running off the end of a chromosome:

    bedtools slop -i ~/ai_agent_workshop/data/genes.bed -g /data/GRCh38.chrom.sizes -b 1000

One thing that surprises people: \`getfasta\` on \`a.bed\` or \`b.bed\` returns runs
of N. Those fixtures are synthetic intervals at coordinates 0-600, and in a real
genome that is telomere. Nothing is wrong — use \`genes.bed\` when you want real
sequence.
EOF
  if [ -s "$GENOME_DIR/HG002.neighbourhoods.bam.bai" ]; then
    cat >> "$GENOME_DIR/README.md" <<'EOF'

## HG002.neighbourhoods.bam

Real aligned reads (GIAB HG002, Illumina 2x250, GRCh38), sliced to the same four
gene neighbourhoods as `data/genes.gtf` — TP53, BRCA1, EGFR, CFTR — and nothing
else. About 2 Mb of genome, so intervals outside those regions have no coverage,
which is a property and not a bug.

    bedtools coverage -a ~/ai_agent_workshop/data/genes.bed \
                      -b /data/HG002.neighbourhoods.bam
    bedtools genomecov -ibam /data/HG002.neighbourhoods.bam -bg | head
EOF
  fi
  chmod 0755 "$GENOME_DIR"
  chmod 0444 "$GENOME_DIR"/* 2>/dev/null || true
fi

say "Aligned reads"
# Slices a public GIAB HG002 BAM down to exactly the four gene neighbourhoods in
# data/genes.gtf — TP53, BRCA1, EGFR, CFTR. Measured at ~70x depth, that is
# about 95 MB and half a million reads, which is the point: `bedtools bamtobed`
# turns it into a BED of ~500,000 intervals, next to fixtures of twenty. That is
# the fixture that makes the spec's memory-model decision real.
#
# The source is 122 GB and is never downloaded — samtools fetches the .bai and
# range-requests only the regions we ask for. Set SKIP_BAM=1 to leave it out.
BAM_URL=${BAM_URL:-https://ftp-trace.ncbi.nlm.nih.gov/ReferenceSamples/giab/data/AshkenazimTrio/HG002_NA24385_son/NIST_Illumina_2x250bps/novoalign_bams/HG002.GRCh38.2x250.bam}
# Neighbourhood spans, from: bedtools merge -d 1000000 on the gene rows of
# data/genes.gtf. TP53, BRCA1, EGFR, CFTR.
BAM_REGIONS=${BAM_REGIONS:-"chr7:54721724-55595006 chr7:117262918-117883675 chr17:7591230-7833742 chr17:42998265-43305397"}
if [ -n "${SKIP_BAM:-}" ]; then
  echo "SKIP_BAM set — skipping"
elif [ -s "$GENOME_DIR/HG002.neighbourhoods.bam.bai" ]; then
  echo "already present"
else
  # Two things to establish before spending ten minutes: that samtools can talk
  # HTTPS at all, and that the remote header uses chr-prefixed contigs. A naming
  # mismatch would otherwise produce an empty BAM and no error.
  if ! samtools --version | grep -qi 'libcurl\|htslib.*curl' && ! samtools view -H "$BAM_URL" >/dev/null 2>&1; then
    echo "WARNING: samtools cannot read remote URLs here — skipping the BAM"
  elif ! samtools view -H "$BAM_URL" 2>/dev/null | grep -q 'SN:chr17'; then
    echo "WARNING: $BAM_URL header has no SN:chr17 — contig naming differs from"
    echo "         the fixtures, so the slice would be empty. Skipping."
  else
    # shellcheck disable=SC2086
    samtools view -b -o "$GENOME_DIR/.reads.part.bam" "$BAM_URL" $BAM_REGIONS
    # Regions come back in request order, which is not necessarily sorted.
    samtools sort -o "$GENOME_DIR/HG002.neighbourhoods.bam" "$GENOME_DIR/.reads.part.bam"
    rm -f "$GENOME_DIR/.reads.part.bam"
    samtools index "$GENOME_DIR/HG002.neighbourhoods.bam"
    chmod 0444 "$GENOME_DIR"/HG002.neighbourhoods.bam*
    echo "sliced $(du -h "$GENOME_DIR/HG002.neighbourhoods.bam" | cut -f1), $(samtools view -c "$GENOME_DIR/HG002.neighbourhoods.bam") reads"
  fi
fi

say "Firewall"
# The volunteer gene server serves on :8000 and others reach it by public IP.
# ufw is inactive on the stock image, so these only matter if you enable it —
# the cloud security group is the real gate.
ufw allow 22/tcp   >/dev/null 2>&1 || true
ufw allow 8000/tcp >/dev/null 2>&1 || true

say "Reclaiming space"
apt-get clean          # the .debs; NOT /var/lib/apt/lists, or `apt install` breaks
rm -rf /root/.cargo/registry /tmp/* 2>/dev/null || true
df -h / | tail -1

say "Done. Next:"
cat <<EOF
  1. su - $WORKSHOP_USER, run 'claude' once, complete the theme and trust
     prompts. That state lives in the home directory and is the one thing
     cloud-init cannot do for you — do it before you snapshot.
  2. ANTHROPIC_API_KEY=sk-... workshop-doctor    # expect all ok
  3. df -h /   and   du -sh /data /usr/lib/R /usr/lib/rustlib 2>/dev/null
     Know the real numbers before you size the attendee VMs.
  4. Snapshot this VM.
EOF
