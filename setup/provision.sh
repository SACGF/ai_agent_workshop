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
  rustc cargo golang-go \
  ca-certificates gnupg wget unzip vim nano tree ripgrep htop
#  ^ bedtools is the oracle for every golden test; bcftools backs the "it parsed
#    and exited 0" contrast in issues/04; tmux is named verbatim in the
#    parallel-agents prompt; less is in the ROT13 answer-key one-liner; rustc,
#    cargo and go are so the "language you don't know" stretch goal starts in
#    seconds rather than after a rustup download.

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
check go       go version;          check python3  python3 --version
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
# GENCODE v50 primary assembly — the same release data/genes.gtf came from, so
# contig names (chr1, chr17) and coordinates line up with the fixtures exactly.
# ~3 GB on disk, baked into the snapshot once rather than pulled by thirty VMs.
# Set SKIP_GENOME=1 to leave it out.
GENOME_DIR=${GENOME_DIR:-/data}
GENOME_URL=${GENOME_URL:-https://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_human/release_50/GRCh38.primary_assembly.genome.fa.gz}
if [ -n "${SKIP_GENOME:-}" ]; then
  echo "SKIP_GENOME set — skipping the genome download"
elif [ -s "$GENOME_DIR/GRCh38.fa.fai" ]; then
  echo "already present at $GENOME_DIR/GRCh38.fa"
else
  free_gb=$(df -BG --output=avail "$(dirname "$GENOME_DIR")" | tail -1 | tr -dc 0-9)
  [ "${free_gb:-0}" -ge 10 ] || echo "WARNING: only ${free_gb}G free, the genome needs ~10G to unpack"
  mkdir -p "$GENOME_DIR"
  # Download to a temp name so an interrupted pull never looks complete.
  curl -fL --retry 3 --retry-delay 5 "$GENOME_URL" -o "$GENOME_DIR/.genome.fa.gz.part"
  mv "$GENOME_DIR/.genome.fa.gz.part" "$GENOME_DIR/GRCh38.fa.gz"
  gunzip -f "$GENOME_DIR/GRCh38.fa.gz"
  samtools faidx "$GENOME_DIR/GRCh38.fa"
  # bedtools slop/complement/shuffle want a genome file, which is the first two
  # columns of the .fai.
  cut -f1,2 "$GENOME_DIR/GRCh38.fa.fai" > "$GENOME_DIR/GRCh38.chrom.sizes"
fi

if [ -d "$GENOME_DIR" ]; then
  cat > "$GENOME_DIR/README.md" <<'EOF'
# /data — reference genome

Read-only. Not to be confused with `data/` inside the workshop repo, which holds
the small BED/GTF/VCF fixtures the exercises are built on. This directory holds
one thing: a human reference genome, for the bedtools subcommands that need
actual sequence or chromosome lengths.

    GRCh38.fa               GENCODE v50 primary assembly, same release as the
                            repo's data/genes.gtf, so contig names match
    GRCh38.fa.fai           samtools faidx index
    GRCh38.chrom.sizes      first two columns of the .fai — this is what
                            bedtools calls a "genome file" (-g)

Sequence for the gene spans in the repo:

    bedtools getfasta -fi /data/GRCh38.fa -bed ~/ai_agent_workshop/data/genes.bed -name

1 kb of flank either side, without running off the end of a chromosome:

    bedtools slop -i ~/ai_agent_workshop/data/genes.bed -g /data/GRCh38.chrom.sizes -b 1000

Note the fixtures in `a.bed` and `b.bed` use real contig names at coordinates
near zero, which in GRCh38 are telomeric N. `getfasta` on those is all Ns, and
that is correct — use `genes.bed` when you want real sequence.
EOF
  chmod 0755 "$GENOME_DIR"
  chmod 0444 "$GENOME_DIR"/* 2>/dev/null || true
  chmod 0444 "$GENOME_DIR/README.md"
fi

say "Firewall"
# The volunteer gene server serves on :8000 and others reach it by public IP.
# ufw is inactive on the stock image, so these only matter if you enable it —
# the cloud security group is the real gate.
ufw allow 22/tcp   >/dev/null 2>&1 || true
ufw allow 8000/tcp >/dev/null 2>&1 || true

say "Done. Next:"
cat <<EOF
  1. su - $WORKSHOP_USER, run 'claude' once, complete the theme and trust
     prompts. That state lives in the home directory and is the one thing
     cloud-init cannot do for you — do it before you snapshot.
  2. ANTHROPIC_API_KEY=sk-... workshop-doctor    # expect all ok
  3. Snapshot this VM.
EOF
