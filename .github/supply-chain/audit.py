#!/usr/bin/env python3
"""Audit the third-party sources the image recipes pull packages from.

The script snapshots every non-Fedora input of the build and compares it
with the reviewed snapshot in lock.json:

* each .repo file referenced by a recipe: its settings, the SHA-256 of its
  signing key and the latest build of every package its includepkgs allows
  (version, build time and size, so a same-version rebuild also shows up);
* for COPR repos: the project settings that can widen trust (external repos,
  runtime dependencies) and where each package's sources are built from;
* the upstream RPMs pinned in files/scripts/external-rpms.txt: whether the
  published file still matches the pinned hash and whether a newer release
  exists.

For every new or changed package it downloads the RPM and lists what it
would run or grant at install time (scriptlets, setuid/setgid files, file
capabilities, files outside /usr).

It needs dnf5 and rpm, so run it in a Fedora container:

    audit.py check  [--report report.md] [--new-lock lock.new.json]
                                           exit 0 if unchanged, 2 if changed
    audit.py update                        rewrite lock.json from the sources
"""

import argparse
import configparser
import fnmatch
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LOCK = Path(__file__).resolve().parent / "lock.json"
RECIPES = ROOT / "recipes"
REPO_DIR = ROOT / "files" / "dnf"
EXTERNAL_RPMS = ROOT / "files" / "scripts" / "external-rpms.txt"
COPR_API = "https://copr.fedorainfracloud.org/api_3"
# Repo settings that change what is trusted or how it is verified.
TRACKED_REPO_KEYS = (
    "baseurl", "metalink", "mirrorlist", "gpgcheck", "repo_gpgcheck",
    "gpgkey", "includepkgs", "excludepkgs", "enabled",
)
USER_AGENT = "celestial-linux-supply-chain-audit"


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=60) as resp:
        return resp.read()


def fetch_json(url):
    return json.loads(fetch(url))


def releasever():
    versions = set()
    for recipe in RECIPES.glob("recipe-*.yml"):
        m = re.search(r"^image-version:\s*(\d+)", recipe.read_text(), re.M)
        if m:
            versions.add(m.group(1))
    if len(versions) != 1:
        sys.exit(f"expected one image-version across recipes, found {versions}")
    return versions.pop()


def referenced_repo_files():
    """Return the .repo files in files/dnf that some recipe module adds."""
    names = set()
    for path in RECIPES.rglob("*.yml"):
        names.update(re.findall(r"^\s*-\s*([\w.+-]+\.repo)\s*$", path.read_text(), re.M))
    missing = sorted(n for n in names if not (REPO_DIR / n).exists())
    if missing:
        sys.exit(f"recipes reference repo files that do not exist: {missing}")
    return sorted(names)


def parse_repo_file(name):
    parser = configparser.ConfigParser(interpolation=None)
    parser.read(REPO_DIR / name)
    return {section: dict(parser[section]) for section in parser.sections()}


def query_repo(repo_id, repo_file, version, cachedir):
    """Latest build of each package the repo's includepkgs lets through."""
    with tempfile.TemporaryDirectory() as reposdir:
        Path(reposdir, repo_file).write_bytes((REPO_DIR / repo_file).read_bytes())
        out = subprocess.run(
            # -y imports the repo signing keys; skip_if_unavailable=0 makes an
            # unreachable or badly signed repo fail instead of looking empty.
            ["dnf", "repoquery", "-q", "-y", "--refresh",
             f"--setopt={repo_id}.skip_if_unavailable=0",
             f"--setopt=reposdir={reposdir}", f"--setopt=cachedir={cachedir}",
             f"--releasever={version}", f"--repo={repo_id}",
             "--arch=x86_64,noarch", "--latest-limit=1",
             "--qf", "%{name}\t%{evr}\t%{arch}\t%{buildtime}\t%{downloadsize}"
                     "\t%{sourcerpm}\t%{location}\n"],
            check=True, capture_output=True, text=True,
        ).stdout
    packages = {}
    for line in out.splitlines():
        name, evr, arch, buildtime, size, srpm, location = line.split("\t")
        if name.endswith(("-debuginfo", "-debugsource")):
            continue
        packages[f"{name}.{arch}"] = {
            "evr": evr, "buildtime": buildtime, "size": size,
            "sourcerpm": srpm, "location": location,
        }
    return packages


def copr_project(baseurl):
    m = re.search(r"/results/([^/]+)/([^/]+)/", baseurl or "")
    return (m.group(1), m.group(2)) if m else None


def copr_snapshot(owner, project, source_names):
    info = fetch_json(f"{COPR_API}/project?ownername={owner}&projectname={project}")
    snap = {
        "additional_repos": info.get("additional_repos") or [],
        "runtime_dependencies": info.get("runtime_dependencies") or "",
        "sources": {},
    }
    packages = fetch_json(
        f"{COPR_API}/package/list?ownername={owner}&projectname={project}"
    )["items"]
    for pkg in packages:
        if pkg["name"] in source_names:
            snap["sources"][pkg["name"]] = {
                "source_type": pkg.get("source_type"),
                "source": pkg.get("source_dict") or {},
            }
    return snap


def srpm_name(srpm):
    # name-version-release.src.rpm -> name
    return srpm.rsplit("-", 2)[0] if srpm else ""


def external_rpms_snapshot():
    snap = {}
    for line in EXTERNAL_RPMS.read_text().splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        pinned, url = line.split()
        actual = hashlib.sha256(fetch(url)).hexdigest()
        entry = {"pinned_sha256": pinned, "published_matches_pin": actual == pinned}
        m = re.match(r"https://github.com/([^/]+/[^/]+)/releases/download/([^/]+)/", url)
        if m:
            entry["pinned_tag"] = m.group(2)
            try:
                latest = fetch_json(f"https://api.github.com/repos/{m.group(1)}/releases/latest")
                entry["latest_tag"] = latest.get("tag_name")
            except Exception as exc:  # rate limits must not hide the hash check
                entry["latest_tag"] = f"unknown ({exc})"
        snap[url] = entry
    return snap


def snapshot():
    version = releasever()
    state = {"releasever": version, "repos": {}, "external_rpms": {}}
    key_hashes = {}
    with tempfile.TemporaryDirectory() as cachedir:
        for repo_file in referenced_repo_files():
            for repo_id, cfg in parse_repo_file(repo_file).items():
                entry = {
                    "file": repo_file,
                    "settings": {k: cfg[k] for k in TRACKED_REPO_KEYS if k in cfg},
                    "gpgkey_sha256": {},
                    "packages": query_repo(repo_id, repo_file, version, cachedir),
                }
                for url in cfg.get("gpgkey", "").split():
                    if url not in key_hashes:
                        key_hashes[url] = hashlib.sha256(fetch(url)).hexdigest()
                    entry["gpgkey_sha256"][url] = key_hashes[url]
                project = copr_project(cfg.get("baseurl"))
                if project and "copr" in repo_id:
                    sources = {srpm_name(p["sourcerpm"]) for p in entry["packages"].values()}
                    entry["copr"] = copr_snapshot(*project, sources)
                state["repos"][repo_id] = entry
    state["external_rpms"] = external_rpms_snapshot()
    return state


def inspect_rpm(url):
    """Summarise what an RPM does at install time."""
    with tempfile.TemporaryDirectory() as tmp:
        path = Path(tmp, "pkg.rpm")
        path.write_bytes(fetch(url))
        q = lambda *args: subprocess.run(
            ["rpm", "-qp", "--nosignature", *args, str(path)],
            capture_output=True, text=True,
        ).stdout.strip()
        scripts = q("--scripts", "--triggers", "--filetriggers")
        modes = q("--qf", "[%{FILEMODES:perms} %{FILENAMES}\n]").splitlines()
        special = [m for m in modes if re.match(r"^...[sS]|^......[sS]", m)]
        caps = [c for c in q("--filecaps").splitlines() if "= " in c and not c.endswith("= ")]
        files = [m.split(" ", 1)[1] for m in modes if " " in m]
        outside_usr = [f for f in files if not f.startswith("/usr/")]
        return {
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            "signature": q("--qf", "%|RSAHEADER?{%{RSAHEADER:pgpsig}}:{%|SIGPGP?{%{SIGPGP:pgpsig}}:{}|}|"),
            "scriptlets": scripts,
            "setuid_setgid": special,
            "file_caps": caps,
            "outside_usr": outside_usr[:40],
            "requires": sorted(set(q("-R").splitlines())),
        }


def diff(old, new):
    """Return (findings, packages to inspect) as markdown lines."""
    lines, to_inspect = [], []
    if old.get("releasever") != new["releasever"]:
        lines.append(f"- Fedora release changed: {old.get('releasever')} -> {new['releasever']}")
    for repo_id in sorted(set(old.get("repos", {})) | set(new["repos"])):
        o, n = old.get("repos", {}).get(repo_id), new["repos"].get(repo_id)
        if o is None:
            lines.append(f"\n### `{repo_id}` (new repo)")
            to_inspect += [(repo_id, k, v) for k, v in n["packages"].items()]
            continue
        if n is None:
            lines.append(f"\n### `{repo_id}`\n- Repo removed from the recipes")
            continue
        repo_lines = []
        for key in sorted(set(o["settings"]) | set(n["settings"])):
            if o["settings"].get(key) != n["settings"].get(key):
                repo_lines.append(f"- Setting `{key}`: `{o['settings'].get(key)}` -> `{n['settings'].get(key)}`")
        if o["gpgkey_sha256"] != n["gpgkey_sha256"]:
            repo_lines.append("- **Signing key changed** (SHA-256 of the gpgkey file differs)")
        oc, nc = o.get("copr", {}), n.get("copr", {})
        for key in ("additional_repos", "runtime_dependencies"):
            if oc.get(key) != nc.get(key):
                repo_lines.append(f"- **COPR `{key}` changed**: `{oc.get(key)}` -> `{nc.get(key)}`")
        for src in sorted(set(oc.get("sources", {})) | set(nc.get("sources", {}))):
            a, b = oc.get("sources", {}).get(src), nc.get("sources", {}).get(src)
            if a != b:
                repo_lines.append(f"- **Build source for `{src}` changed**:\n  - was: `{json.dumps(a)}`\n  - now: `{json.dumps(b)}`")
        for pkg in sorted(set(o["packages"]) | set(n["packages"])):
            a, b = o["packages"].get(pkg), n["packages"].get(pkg)
            if a is None:
                repo_lines.append(f"- New package `{pkg}` {b['evr']}")
                to_inspect.append((repo_id, pkg, b))
            elif b is None:
                repo_lines.append(f"- Package gone: `{pkg}`")
            elif (a["evr"], a["buildtime"], a["size"]) != (b["evr"], b["buildtime"], b["size"]):
                note = "" if a["evr"] != b["evr"] else " (**same version, rebuilt**)"
                repo_lines.append(f"- `{pkg}`: {a['evr']} -> {b['evr']}{note}")
                to_inspect.append((repo_id, pkg, b))
        if repo_lines:
            lines.append(f"\n### `{repo_id}`")
            lines += repo_lines
    ext_lines = []
    for url, b in new["external_rpms"].items():
        a = old.get("external_rpms", {}).get(url)
        if not b["published_matches_pin"]:
            ext_lines.append(f"- **Published file no longer matches the pinned hash**: {url}")
        if b.get("latest_tag") and b.get("pinned_tag") and b["latest_tag"] != b["pinned_tag"]:
            if not a or a.get("latest_tag") != b["latest_tag"]:
                ext_lines.append(f"- New upstream release {b['latest_tag']} (pinned {b['pinned_tag']}): {url}")
        if a is None:
            ext_lines.append(f"- New pinned RPM: {url}")
    if ext_lines:
        lines.append("\n### External RPMs")
        lines += ext_lines
    return lines, to_inspect


def render_inspection(repo_id, pkg, meta):
    try:
        info = inspect_rpm(meta["location"])
    except Exception as exc:
        return [f"\n#### `{pkg}` from `{repo_id}`\n- Could not download for inspection: {exc}"]
    out = [f"\n#### `{pkg}` {meta['evr']} from `{repo_id}`",
           f"- SHA-256: `{info['sha256']}`",
           f"- Signature: `{info['signature'] or 'none'}`"]
    for label, key in (("setuid/setgid files", "setuid_setgid"),
                       ("File capabilities", "file_caps"),
                       ("Files outside /usr", "outside_usr")):
        if info[key]:
            out.append(f"- **{label}**:\n" + "\n".join(f"  - `{x}`" for x in info[key]))
    if info["scriptlets"]:
        out.append("- Scriptlets:\n\n```\n" + info["scriptlets"][:4000] + "\n```")
    return out


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("command", choices=("check", "update"))
    parser.add_argument("--report", type=Path, help="write the markdown report here")
    parser.add_argument("--new-lock", type=Path,
                        help="on changes, write the snapshot the report describes here")
    args = parser.parse_args()

    state = snapshot()
    if args.command == "update":
        LOCK.write_text(json.dumps(state, indent=2, sort_keys=True) + "\n")
        print(f"wrote {LOCK.relative_to(ROOT)}")
        return 0

    old = json.loads(LOCK.read_text()) if LOCK.exists() else {}
    lines, to_inspect = diff(old, state)
    if not lines:
        print("No changes in third-party sources.")
        return 0
    report = ["## Supply-chain audit: changes since the last reviewed lock", *lines]
    if to_inspect:
        report.append("\n## Install-time behaviour of new or changed packages")
        for item in to_inspect:
            report += render_inspection(*item)
    text = "\n".join(report) + "\n"
    if args.report:
        args.report.write_text(text)
    if args.new_lock:
        args.new_lock.write_text(json.dumps(state, indent=2, sort_keys=True) + "\n")
    print(text)
    return 2


if __name__ == "__main__":
    sys.exit(main())
