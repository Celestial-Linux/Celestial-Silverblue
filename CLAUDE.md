# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Celestial Linux is a set of custom immutable desktop Linux images built on Fedora Silverblue/Sericea using the **BlueBuild** framework. Images are based on SecureBlue hardened variants and published to `ghcr.io/celestial-linux`. There are multiple variants covering different desktop environments (GNOME/Silverblue, KDE/Kinoite, Hyprland, Cosmic) and GPU support (standard, NVIDIA), with optional CachyOS kernel variants.

## Build & Validation Commands

```bash
# Validate a recipe (run after every edit)
podman run --rm --security-opt label=disable -v "$(pwd)":/workspace -w /workspace \
  ghcr.io/blue-build/cli:latest bluebuild validate recipes/recipe-silverblue.yml

# Build an image locally
podman run --rm --security-opt label=disable -v "$(pwd)":/workspace -w /workspace \
  ghcr.io/blue-build/cli:latest bluebuild build recipes/recipe-silverblue.yml

# Shellcheck a script
shellcheck files/scripts/<script>.sh

# Verify a published image
cosign verify --key cosign.pub ghcr.io/celestial-linux/celestial-silverblue
```

Swap `recipe-silverblue.yml` for any other recipe file (e.g. `recipe-hyprland.yml`) to target a different variant.

## Architecture

**BlueBuild** uses declarative YAML recipes to compose OS images. Each recipe defines a base image, then layers modules (package installs, filesystem overlays, systemd units, scripts, etc.).

- `recipes/recipe-*.yml` — Root recipe files, one per image variant. These compose shared and variant-specific modules via `from-file` references.
- `recipes/common/` — Shared modules included by multiple recipes (packages, fonts, systemd config, chezmoi, os-release branding, final cleanup).
- `recipes/<variant>/` — Variant-specific modules (e.g. `hyprland/`, `silverblue/`, `kinoite/`, `cosmic/`).
- `files/system/` — Static filesystem overlay mirroring the target root (`etc/`, `usr/`). Files here are copied directly into the image.
- `files/scripts/` — Build-time shell scripts (NVIDIA driver install, kernel module signing, repo cleanup, etc.).
- `files/dnf/` — DNF repository definition files (.repo) added to the image.
- `modules/` — Reserved for custom reusable BlueBuild modules (currently empty).

## Conventions

- All YAML files must have the BlueBuild schema comment at the top: `# yaml-language-server: $schema=https://schema.blue-build.org/<type>.json`
- YAML uses two-space indentation; package lists are grouped by purpose with external RPM URLs last.
- Shell scripts use `#!/usr/bin/env bash` and `set -oue pipefail`.
- New recipes follow the naming pattern `recipe-<variant>.yml` with a matching `recipes/<variant>/` directory.
- Commits use Conventional Commits: `feat(hyprland): ...`, `fix(nvidia): ...`, `chore(systemd): ...` — scope is the affected variant or subsystem.

## CI/CD

GitHub Actions workflow (`.github/workflows/build.yml`) builds images daily at 06:00 UTC, on push, and on manual dispatch. It runs a matrix of recipe builds using `blue-build/github-action@v1.11`, signs images with Cosign, and injects the kernel signing key from the `KERNEL_PRIVKEY` secret. Only some variants are active in CI at any given time (others are commented out in the matrix).
