# Supply-chain audit

The images install packages from sources outside Fedora: COPR projects,
vendor repos (Tailscale, Gemfury) and upstream release RPMs. This directory
tracks what those sources currently publish so that any change is reviewed
before it is accepted.

## Guardrails in the build

- Every third-party repo is a `.repo` file in `files/dnf/` with an
  `includepkgs=` allowlist, so a repo can only provide the packages listed
  there. Without it, a COPR could ship a newer build of a Fedora package such
  as `openssh` or `glibc` and dnf would install it. COPRs are not enabled
  with the `copr:` key of the dnf module, because `dnf copr enable` also adds
  the project's external runtime-dependency repos with `gpgcheck=0`.
- Dependencies that come from other COPRs (quickshell, gpu-screen-recorder)
  get their own signed `.repo` file instead.
- Upstream RPMs are listed in `files/scripts/external-rpms.txt` with their
  SHA-256, and `install_external_rpms.sh` refuses any file that does not match.
- Each image ships `/usr/share/celestial-linux/package-manifest.tsv`, listing
  every installed package and the repo it came from.

## The lock

`lock.json` is the last reviewed state. `audit.py check` compares the current
state against it and reports, for each repo: setting or signing-key changes,
COPR project changes (external repos, runtime dependencies, the git URL or
ref each package is built from), new, removed, upgraded or rebuilt packages,
and for each new or changed RPM its scriptlets, setuid/setgid files, file
capabilities and files outside `/usr`. It also confirms that upstream release
assets still match their pinned hashes and reports newer releases.

`audit.py` needs dnf5, so run it in a Fedora container:

```bash
podman run --rm --security-opt label=disable -v "$PWD":/repo -w /repo \
  registry.fedoraproject.org/fedora:latest \
  bash -c 'dnf -yq install python3 && python3 .github/supply-chain/audit.py check'
```

## Weekly review

1. `.github/workflows/supply-chain-audit.yml` runs every Monday. If anything
   changed, it pushes the new lock to the `supply-chain/lock-update` branch
   and opens (or updates) an issue labelled `supply-chain` with the report.
2. A scheduled Claude Code routine reviews that issue: it reads the upstream
   changes behind each update and comments with a verdict. It never merges or
   edits the lock.
3. A maintainer approves by opening and merging a PR from
   `supply-chain/lock-update`, then closes the issue.

When adding a package from a new source, add the repo file with an
`includepkgs=` allowlist, reference it from a recipe, and run
`audit.py update` so the new source starts from a reviewed state.
