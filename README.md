# OpenClaw Lab Setup

Reproducible development environment setup for the **OpenClaw AI Security Lab**.

This repository documents the baseline system configuration used to build and test the OpenClaw lab environment on a fresh Ubuntu virtual machine.

The goal is to create a **clean, snapshot-driven security research environment** that can later be automated via provisioning scripts.

---

## Environment Overview

**Target Platform**
- Ubuntu LTS (Virtual Machine)
- Fresh installation
- Non-root user with sudo privileges

**Lab Philosophy**
- Reproducible builds
- Snapshot-based rollback
- Containerized tooling
- Isolation from host system

---

## Step 1 — Base System Packages

Install core development and system utilities.

```bash
sudo apt update

sudo apt install -y \
build-essential git curl wget vim htop \
net-tools unzip zip tree jq \
ca-certificates software-properties-common

sudo apt install -y \
python3 python3-pip python3-venv
```

---

## Step 2 — Snapshot Base Ubuntu Image

After completing base package installation:

1. Shut down VM  
2. Create snapshot  

Example snapshot name:

```
ubuntu-base-clean
```

This provides a rollback point before development tooling installation.

---

## Step 3 — Install Visual Studio Code

Add Microsoft repository:

```bash
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | \
gpg --dearmor > packages.microsoft.gpg

sudo install -o root -g root -m 644 \
packages.microsoft.gpg /etc/apt/keyrings/

sudo sh -c 'echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/packages.microsoft.gpg] \
https://packages.microsoft.com/repos/code stable main" \
> /etc/apt/sources.list.d/vscode.list'
```

Install VS Code:

```bash
sudo apt update
sudo apt install code -y
```

---

## Step 4 — Install Docker Engine

Remove legacy Docker versions:

```bash
sudo apt remove docker docker-engine docker.io containerd runc
```

Add Docker repository:

```bash
sudo mkdir -p /etc/apt/keyrings

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
```

```bash
echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu \
$(lsb_release -cs) stable" | \
sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

Install Docker:

```bash
sudo apt update

sudo apt install -y \
docker-ce docker-ce-cli containerd.io \
docker-buildx-plugin docker-compose-plugin
```

---

## Step 5 — Enable Docker Without sudo

```bash
sudo usermod -aG docker $USER
```

⚠️ Log out and back in (or reboot) for group changes to apply.

---

## Step 6 — VS Code Development Extensions

Install required extensions:

```bash
code --install-extension ms-azuretools.vscode-docker
code --install-extension ms-vscode-remote.remote-containers
code --install-extension ms-vscode-remote.vscode-remote-extensionpack
code --install-extension ms-python.python
code --install-extension ms-python.vscode-pylance
code --install-extension eamodio.gitlens
code --install-extension redhat.vscode-yaml
code --install-extension ms-kubernetes-tools.vscode-kubernetes-tools
```

---

## Step 7 — Install GitHub CLI

```bash
type -p curl >/dev/null || sudo apt install curl -y

curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | \
sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg

sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
```

```bash
echo \
"deb [arch=$(dpkg --print-architecture) \
signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] \
https://cli.github.com/packages stable main" | \
sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
```

```bash
sudo apt update
sudo apt install gh -y
```

---

## Step 8 — Prepare Lab Directory Structure

```bash
mkdir -p ~/labs/openclaw
mkdir -p ~/repos
```

Recommended layout:

```
~/labs/
└── openclaw/

~/repos/
```

---

## Step 9 — Environment Verification

Validate installation:

```bash
docker info
code --version
git --version
python3 --version
```

---

## Step 10 — Snapshot Development Environment

Create snapshot **before OpenClaw installation**.

Example:

```
openclaw-dev-ready
```

This snapshot represents a fully prepared development baseline.

---

## Next Phase (Planned)

Future automation will include:

- setup.sh bootstrap script
- Container provisioning
- Dependency automation
- Lab deployment workflows
- Reproducible OpenClaw installation

---

## Purpose

This repository exists to:

- Document lab construction methodology
- Enable rapid rebuild of research environments
- Support experimentation in AI security workflows
- Provide reproducible infrastructure for OpenClaw labs

---

## Future Repository Structure

```
openclaw-lab-setup/
│
├── README.md
├── setup.sh
└── docs/
```
