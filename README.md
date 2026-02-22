# OpenClaw Lab Setup

Reproducible development environment setup for the **OpenClaw AI Security Lab**.

This repository provides an automated bootstrap process for building a **clean, snapshot-driven AI security research environment** on a fresh Ubuntu virtual machine.

The goal is to create a consistent, rebuildable lab platform suitable for experimentation, testing, and security research involving OpenClaw and related tooling.

---

## Quick Bootstrap Installation

The entire development environment can be installed automatically using the provided bootstrap script.

---

## Requirements

- Ubuntu LTS virtual machine
- Fresh operating system installation
- Non-root user with sudo privileges
- Internet connectivity
- Virtual machine snapshot capability (recommended)

---

## ⚠️ Fresh System Requirement

This installer **must be executed on a clean Ubuntu installation**.

The setup script assumes:

- No existing Visual Studio Code APT repositories
- No preconfigured Microsoft package sources
- No prior Docker installations
- Default Ubuntu package configuration

Running the installer on an already-modified system may result in APT repository conflicts.

### Recommended Workflow

1. Install Ubuntu LTS
2. Log in using a normal sudo-enabled user
3. Run the bootstrap installer immediately
4. Create snapshots after installation

---

## 🚀 One-Command Setup

Run the following command on a fresh Ubuntu VM:

```bash
curl -fsSL https://raw.githubusercontent.com/<your-username>/openclaw-lab-setup/main/setup.sh | bash
```

The bootstrap script automatically installs and configures:
- Base development packages
- Python development environment
- Visual Studio Code
- Docker Engine + Docker Compose
- GitHub CLI
- VS Code development extensions
- OpenClaw lab directory structure

## Post-Installation Step (Required)

Docker permissions are applied during installation.
After setup completes:
```bash
reboot
```

After logging back in, verify Docker access:
```bash
docker info
```
Docker should function without sudo.

## Recommended Snapshot Workflow
| Stage	| Snapshot Name |
|-------|---------------|
| Fresh Ubuntu Install | ubuntu-base-clean |
|After Bootstrap |	openclaw-dev-ready |

Snapshots allow rapid rollback and reproducible lab rebuilding.

## Environment Overview

**Target Platform**
- Ubuntu LTS (Virtual Machine)
- Snapshot-enabled workflow
- Containerized tooling environment

**Lab Philosophy**
- Reproducible builds
- Infrastructure-as-code mindset
- Snapshot-based recovery
- Isolation from host system
- Disposable research environments

##  Directory Structure

The installer prepares the following workspace layout:

```code
~/labs/
└── openclaw/
~/repos/
```

## Purpose

- labs/ → active experimentation environments
- repos/ → cloned development repositories

## Environment Verification

Confirm successful installation:
```bash
docker info
code --version
git --version
python3 --version
gh --version
```

## Next Phase

After bootstrap completion:
- Deploy OpenClaw containers
- Configure AI agent environment
- Implement lab workflows
- Perform AI security experimentation
- Capture reproducible research states

## Project Purpose

This repository exists to:
- Document OpenClaw lab construction methodology
- Enable rapid rebuilding of research environments
- Support experimentation in AI security workflows
- Provide reproducible infrastructure for AI security labs
- Demonstrate automated environment provisioning

## Repository Structure
```code
openclaw-lab-setup/
│
├── README.md
├── setup.sh
└── docs/
```

## Review Installer (Optional)

You may inspect the bootstrap script before execution:
```bash
curl -fsSL https://raw.githubusercontent.com/<your-username>/openclaw-lab-setup/main/setup.sh
```
Transparency and reproducibility are core design goals of this project.
