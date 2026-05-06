#!/usr/bin/env bash

set -euo pipefail

python3 - <<'PY'
from pathlib import Path

matches = sorted(Path("/usr/lib").glob("python*/site-packages/caelestia/utils/theme.py"))
if not matches:
    raise SystemExit("Caelestia theme.py was not found under /usr/lib/python*/site-packages")
if len(matches) > 1:
    raise SystemExit(f"Found multiple Caelestia theme.py files: {matches}")

theme_path = matches[0]
old = """    subprocess.run(["dconf", "write", "/org/gnome/desktop/interface/gtk-theme", "'adw-gtk3-dark'"])
"""
new = """    gtk_theme = "adw-gtk3-dark" if mode == "dark" else "adw-gtk3"
    subprocess.run(["dconf", "write", "/org/gnome/desktop/interface/gtk-theme", f"'{gtk_theme}'"])
"""

content = theme_path.read_text()
if new in content:
    raise SystemExit(0)
if old not in content:
    raise SystemExit(f"Expected Caelestia GTK theme line not found in {theme_path}")

theme_path.write_text(content.replace(old, new))
PY
