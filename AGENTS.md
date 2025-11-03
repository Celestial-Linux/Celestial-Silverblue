# Repository Guidelines

## Project Structure & Module Organization
- `recipes/` holds BlueBuild entrypoints for each image. `recipe-*.yml` files compose shared pieces from `recipes/common/` and variant directories such as `recipes/silverblue/` or `recipes/hyprland/`.
- `files/` mirrors the target filesystem. Place build-time helpers in `files/scripts/` and drop static configuration in `files/system/`.
- `modules/` is reserved for reusable BlueBuild modules; keep `.gitkeep` and add authored modules only when multiple recipes need them.
- `cosign.pub` is the public key that signs delivered images; update it whenever the signing pipeline rotates keys.

## Build, Test, and Development Commands
- `podman run --rm --security-opt label=disable -v "$(pwd)":/workspace ghcr.io/blue-build/build:latest build --recipe recipes/recipe-silverblue.yml` builds the Silverblue image inside the official BlueBuild container.
- `podman run --rm --security-opt label=disable -v "$(pwd)":/workspace ghcr.io/blue-build/build:latest lint --recipe recipes/recipe-silverblue.yml` validates schema usage, module ordering, and filesystem layout.
- Swap in other recipe files (e.g. `recipes/recipe-hyprland.yml`) to exercise additional variants or reproduce CI issues.

## Coding Style & Naming Conventions
- Preserve the schema comment (`# yaml-language-server: ...`) atop YAML modules, indent nested mappings with two spaces, and group package lists by purpose with external RPM URLs last.
- Shell scripts in `files/scripts/` start with `#!/usr/bin/env bash`, call `set -oue pipefail`, and use descriptive lowercase filenames with hyphens.
- Name new recipes `recipe-<variant>.yml` and mirror that variant under `recipes/<variant>/` so automation picks them up.

## Testing Guidelines
- Always run the lint command after edits; CI expects a clean result before review.
- After each build, boot the image in a VM or test device and capture `rpm-ostree status` plus relevant journal excerpts, especially when touching NVIDIA, Stream Deck, or kernel modules.
- When editing shell scripts, run `shellcheck files/scripts/<script>.sh` to catch syntax and portability issues early.

## Commit & Pull Request Guidelines
- Follow the Conventional Commits pattern already in history (`feat(scope): summary`, `fix(scope): summary`, etc.), using the affected variant or subsystem as the scope.
- Pull requests should summarise touched recipes/modules, link tracking issues, and attach recent lint or build output. Note any manual steps reviewers must repeat.

## Security & Release Checks
- Before publishing, verify images with `cosign verify --key cosign.pub ghcr.io/celestial-linux/celestial-silverblue` and confirm the embedded key matches the repository copy.
- Highlight any secret-handling changes and never commit private signing material.
