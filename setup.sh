```bash
#!/usr/bin/env bash
set -euo pipefail

# OpenClaw Lab Setup bootstrap
# - Installs base packages, VS Code, Docker Engine, GH CLI
# - Installs VS Code extensions
# - Creates ~/labs/openclaw and ~/repos
# - Verifies versions
#
# Usage:
#   chmod +x setup.sh
#   ./setup.sh
#
# Optional:
#   SKIP_VSCODE_EXT=1 ./setup.sh   # skip extension installation
#   SKIP_CODE=1 ./setup.sh        # skip VS Code installation
#   SKIP_DOCKER=1 ./setup.sh      # skip Docker installation
#   SKIP_GH=1 ./setup.sh          # skip GitHub CLI installation

log()  { echo -e "\n\033[1;34m[INFO]\033[0m $*"; }
warn() { echo -e "\n\033[1;33m[WARN]\033[0m $*"; }
err()  { echo -e "\n\033[1;31m[ERR ]\033[0m $*" >&2; }
die()  { err "$*"; exit 1; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

# ---- Preflight ----
log "Preflight checks"

if [[ "${EUID}" -eq 0 ]]; then
  die "Do not run as root. Run as your normal user with sudo privileges."
fi

require_cmd sudo
require_cmd apt
require_cmd curl
require_cmd wget

if ! sudo -n true 2>/dev/null; then
  log "Sudo requires your password. You may be prompted."
fi

UBUNTU_ID="$(. /etc/os-release && echo "${ID}")"
if [[ "${UBUNTU_ID}" != "ubuntu" ]]; then
  warn "This script is designed for Ubuntu. Detected ID='${UBUNTU_ID}'. Continuing anyway."
fi

ARCH="$(dpkg --print-architecture)"
if [[ "${ARCH}" != "amd64" ]]; then
  warn "This script assumes amd64 in the VS Code repo line. Detected architecture: ${ARCH}"
fi

# ---- Step 1: Base packages ----
log "Step 1: Installing base system packages"
sudo apt update

sudo apt install -y \
  build-essential git curl wget vim htop \
  net-tools unzip zip tree jq \
  ca-certificates software-properties-common \
  python3 python3-pip python3-venv \
  gpg

# ---- Step 3: VS Code ----
if [[ "${SKIP_CODE:-0}" == "1" ]]; then
  warn "Skipping VS Code installation (SKIP_CODE=1)"
else
  log "Step 3: Installing Visual Studio Code"

  # Ensure keyrings dir exists
  sudo mkdir -p /etc/apt/keyrings

  # Add Microsoft GPG key -> /etc/apt/keyrings/packages.microsoft.gpg
  # Use a temp dir to avoid leaving artifacts behind.
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "${tmpdir}"' EXIT

  wget -qO- https://packages.microsoft.com/keys/microsoft.asc | \
    gpg --dearmor > "${tmpdir}/packages.microsoft.gpg"

  sudo install -o root -g root -m 644 \
    "${tmpdir}/packages.microsoft.gpg" /etc/apt/keyrings/packages.microsoft.gpg

  # Add VS Code repo
  sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null <<EOF
deb [arch=amd64 signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main
EOF

  sudo apt update
  sudo apt install -y code
fi

# ---- Step 4/5: Docker Engine + no-sudo ----
if [[ "${SKIP_DOCKER:-0}" == "1" ]]; then
  warn "Skipping Docker installation (SKIP_DOCKER=1)"
else
  log "Step 4: Installing Docker Engine"

  # Remove legacy docker packages if present (ignore failures)
  sudo apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

  # Add Docker repo key
  sudo mkdir -p /etc/apt/keyrings
  sudo rm -f /etc/apt/keyrings/docker.gpg

  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

  # Add Docker repo
  CODENAME="$(lsb_release -cs)"
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${CODENAME} stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

  sudo apt update

  sudo apt install -y \
    docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin docker-compose-plugin

  # Step 5: enable docker without sudo
  log "Step 5: Enabling Docker without sudo (adds current user to docker group)"
  if getent group docker >/dev/null 2>&1; then
    sudo usermod -aG docker "$USER"
  else
    warn "Docker group not found; creating it and adding user."
    sudo groupadd docker || true
    sudo usermod -aG docker "$USER"
  fi

  warn "Docker group change requires a new login session."
  warn "After this script finishes, log out/in (or reboot), then run: docker info"
fi

# ---- Step 7: GitHub CLI ----
if [[ "${SKIP_GH:-0}" == "1" ]]; then
  warn "Skipping GitHub CLI installation (SKIP_GH=1)"
else
  log "Step 7: Installing GitHub CLI (gh)"

  # Keyring
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | \
    sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg status=none

  sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg

  # Repo
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | \
    sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null

  sudo apt update
  sudo apt install -y gh
fi

# ---- Step 8: Directory structure ----
log "Step 8: Creating lab directory structure"
mkdir -p "${HOME}/labs/openclaw"
mkdir -p "${HOME}/repos"

# ---- Step 6: VS Code extensions ----
if [[ "${SKIP_VSCODE_EXT:-0}" == "1" ]]; then
  warn "Skipping VS Code extensions (SKIP_VSCODE_EXT=1)"
else
  if command -v code >/dev/null 2>&1; then
    log "Step 6: Installing VS Code development extensions"

    # If VS Code is installed but not fully usable (e.g., no DISPLAY/tty issues),
    # these may fail; we handle failures gracefully and continue.
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
        if code --install-extension "${ext}" >/dev/null 2>&1; then
          log "Installed extension: ${ext}"
        else
          warn "Failed to install extension: ${ext}"
          warn "You can retry later once VS Code is fully working: code --install-extension ${ext}"
        fi
      fi
    done
  else
    warn "VS Code not found; skipping extensions."
  fi
fi

# ---- Step 9: Verification ----
log "Step 9: Environment verification"
echo "git:     $(git --version || true)"
echo "python3: $(python3 --version || true)"
echo "code:    $(code --version 2>/dev/null | head -n 1 || echo 'not installed')"
echo "gh:      $(gh --version 2>/dev/null | head -n 1 || echo 'not installed')"

if command -v docker >/dev/null 2>&1; then
  # docker info may still require sudo until the user re-logs
  if docker info >/dev/null 2>&1; then
    echo "docker:  OK (docker info succeeded without sudo)"
  else
    warn "docker info did not succeed without sudo (expected until you log out/in)."
    warn "Try after re-login: docker info"
    echo "docker:  installed (needs new login session for non-sudo use)"
  fi
else
  echo "docker:  not installed"
fi

log "Done."
warn "Snapshot reminders (manual):"
warn " - After Step 1 base packages: snapshot name suggestion: ubuntu-base-clean"
warn " - After dev tooling (this script): snapshot name suggestion: openclaw-dev-ready"
```
