#!/usr/bin/env bash
set -Eeuo pipefail

# OpenClaw Lab Setup bootstrap (Ubuntu)
# Safe for: curl -fsSL <raw-url> | bash

# ---- UX helpers ----
log()  { echo -e "\n\033[1;34m[INFO]\033[0m $*"; }
warn() { echo -e "\n\033[1;33m[WARN]\033[0m $*"; }
err()  { echo -e "\n\033[1;31m[ERR ]\033[0m $*" >&2; }
die()  { err "$*"; exit 1; }

on_err() {
  err "Setup failed on line ${BASH_LINENO[0]} (exit code: $?)."
  err "Tip: if apt/dpkg was interrupted, run: sudo dpkg --configure -a && sudo apt-get -f install"
}
on_int() {
  warn "Interrupted (Ctrl+C). Exiting."
  exit 130
}
trap on_err ERR
trap on_int INT

require_cmd() { command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"; }

# ---- Script defaults ----
export DEBIAN_FRONTEND=noninteractive

APT_GET="sudo -E apt-get"
APT_OPTS="-yq"
APT_INSTALL="${APT_GET} install ${APT_OPTS}"
APT_UPDATE="${APT_GET} update -q"
APT_REMOVE="${APT_GET} remove ${APT_OPTS}"

# Optional toggles
: "${SKIP_VSCODE_EXT:=0}"
: "${SKIP_CODE:=0}"
: "${SKIP_DOCKER:=0}"
: "${SKIP_GH:=0}"

# ---- Preflight ----
log "Preflight checks"

if [[ "${EUID}" -eq 0 ]]; then
  die "Do not run as root. Run as a normal user with sudo privileges."
fi

require_cmd sudo
require_cmd curl
require_cmd wget
require_cmd dpkg

# Check sudo works (may prompt)
if ! sudo -n true 2>/dev/null; then
  log "Sudo may prompt for your password."
fi

# Best-effort Ubuntu check (no hard stop)
UBUNTU_ID="$(. /etc/os-release && echo "${ID}")"
if [[ "${UBUNTU_ID}" != "ubuntu" ]]; then
  warn "Designed for Ubuntu. Detected ID='${UBUNTU_ID}'. Continuing anyway."
fi

# ---- Step 1: Base packages ----
log "Step 1: Installing base system packages"
${APT_UPDATE}

# gpg + keyring support + lsb-release needed for repo codename
${APT_INSTALL} \
  build-essential git curl wget vim htop \
  net-tools unzip zip tree jq \
  ca-certificates software-properties-common \
  python3 python3-pip python3-venv \
  gpg lsb-release

# Ensure keyrings directory exists (used by multiple steps)
sudo mkdir -p /etc/apt/keyrings

# ---- Step 3: VS Code ----
if [[ "${SKIP_CODE}" == "1" ]]; then
  warn "Skipping VS Code installation (SKIP_CODE=1)"
else
  log "Step 3: Installing Visual Studio Code"

  tmpdir="$(mktemp -d)"
  cleanup() { rm -rf "${tmpdir}" >/dev/null 2>&1 || true; }
  trap cleanup EXIT

  # Microsoft signing key -> /etc/apt/keyrings/packages.microsoft.gpg
  wget -qO- https://packages.microsoft.com/keys/microsoft.asc \
    | gpg --dearmor > "${tmpdir}/packages.microsoft.gpg"

  sudo install -o root -g root -m 644 \
    "${tmpdir}/packages.microsoft.gpg" /etc/apt/keyrings/packages.microsoft.gpg

  # Repo
  sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null <<'EOF'
deb [arch=amd64 signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main
EOF

  ${APT_UPDATE}
  ${APT_INSTALL} code
fi

# ---- Step 4/5: Docker Engine + no-sudo ----
if [[ "${SKIP_DOCKER}" == "1" ]]; then
  warn "Skipping Docker installation (SKIP_DOCKER=1)"
else
  log "Step 4: Installing Docker Engine"

  # Remove legacy packages if present (silence "not installed" noise)
  ${APT_REMOVE} docker docker-engine docker.io containerd runc >/dev/null 2>&1 || true

  # Docker GPG key
  sudo rm -f /etc/apt/keyrings/docker.gpg >/dev/null 2>&1 || true
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

  # Repo
  CODENAME="$(lsb_release -cs)"
  ARCH="$(dpkg --print-architecture)"
  echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${CODENAME} stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

  ${APT_UPDATE}

  ${APT_INSTALL} \
    docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin docker-compose-plugin

  log "Step 5: Enabling Docker without sudo (adds current user to docker group)"
  if ! getent group docker >/dev/null 2>&1; then
    sudo groupadd docker >/dev/null 2>&1 || true
  fi
  sudo usermod -aG docker "${USER}"

  warn "Docker group change requires a new login session."
  warn "After this finishes: log out/in (or reboot), then run: docker info"
fi

# ---- Step 7: GitHub CLI ----
if [[ "${SKIP_GH}" == "1" ]]; then
  warn "Skipping GitHub CLI installation (SKIP_GH=1)"
else
  log "Step 7: Installing GitHub CLI (gh)"

  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg status=none

  sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg

  ARCH="$(dpkg --print-architecture)"
  echo "deb [arch=${ARCH} signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null

  ${APT_UPDATE}
  ${APT_INSTALL} gh
fi

# ---- Step 8: Directory structure ----
log "Step 8: Creating lab directory structure"
mkdir -p "${HOME}/labs/openclaw" "${HOME}/repos"

# ---- Step 6: VS Code extensions ----
if [[ "${SKIP_VSCODE_EXT}" == "1" ]]; then
  warn "Skipping VS Code extensions (SKIP_VSCODE_EXT=1)"
else
  if command -v code >/dev/null 2>&1; then
    log "Step 6: Installing VS Code development extensions"

    exts=(
      "ms-azuretools.vscode-docker"
      "ms-vscode-remote.remote-containers"
      "ms-vscode-remote.vscode-remote-extensionpack"
      "ms-python.python"
      "ms-python.vscode-pylance"
      "eamodio.gitlens"
      "redhat.vscode-yaml"
      "ms-kubernetes-tools.vscode-kubernetes-tools"
    )

    for ext in "${exts[@]}"; do
      if code --list-extensions 2>/dev/null | grep -qx "${ext}"; then
        log "Extension already installed: ${ext}"
      else
        # Make extension install non-fatal (VS Code can fail in headless/first-run cases)
        if code --install-extension "${ext}" >/dev/null 2>&1; then
          log "Installed extension: ${ext}"
        else
          warn "VS Code extension install failed: ${ext}"
          warn "You can retry later: code --install-extension ${ext}"
        fi
      fi
    done
  else
    warn "VS Code not found; skipping extensions."
  fi
fi

# ---- Step 9: Verification ----
log "Step 9: Environment verification"
echo "git:     $(git --version 2>/dev/null || true)"
echo "python3: $(python3 --version 2>/dev/null || true)"
echo "code:    $(code --version 2>/dev/null | head -n 1 || echo 'not installed')"
echo "gh:      $(gh --version 2>/dev/null | head -n 1 || echo 'not installed')"

if command -v docker >/dev/null 2>&1; then
  if docker info >/dev/null 2>&1; then
    echo "docker:  OK (docker info succeeded without sudo)"
  else
    echo "docker:  installed (re-login required for non-sudo use)"
  fi
else
  echo "docker:  not installed"
fi

log "Done."
warn "Snapshot reminders (manual):"
warn " - After base packages: ubuntu-base-clean"
warn " - After this script: openclaw-dev-ready"
