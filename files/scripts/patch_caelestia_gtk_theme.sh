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

content = theme_path.read_text()
new = """    gtk_theme = "adw-gtk3-dark" if mode == "dark" else "adw-gtk3"
    color_scheme = "prefer-dark" if mode == "dark" else "prefer-light"
    subprocess.run(["gsettings", "set", "org.gnome.desktop.interface", "gtk-theme", gtk_theme])
    subprocess.run(["gsettings", "set", "org.gnome.desktop.interface", "color-scheme", color_scheme])
"""

if new in content:
    raise SystemExit(0)

replacements = [
    # Current upstream shape: hard-coded dark GTK theme followed by mode-derived color scheme.
    (
        """    subprocess.run(["dconf", "write", "/org/gnome/desktop/interface/gtk-theme", "'adw-gtk3-dark'"])
    subprocess.run(["dconf", "write", "/org/gnome/desktop/interface/color-scheme", f"'prefer-{mode}'"])
""",
        new,
    ),
    # Previous Celestial patch applied on top of current upstream.
    (
        """    gtk_theme = "adw-gtk3-dark" if mode == "dark" else "adw-gtk3"
    color_scheme = "prefer-dark" if mode == "dark" else "default"
    subprocess.run(["dconf", "write", "/org/gnome/desktop/interface/gtk-theme", f"'{gtk_theme}'"])
    subprocess.run(["dconf", "write", "/org/gnome/desktop/interface/color-scheme", f"'{color_scheme}'"])
    subprocess.run(["dconf", "write", "/org/gnome/desktop/interface/color-scheme", f"'prefer-{mode}'"])
""",
        new,
    ),
    # Previous Celestial patch applied before upstream added color-scheme handling.
    (
        """    gtk_theme = "adw-gtk3-dark" if mode == "dark" else "adw-gtk3"
    subprocess.run(["dconf", "write", "/org/gnome/desktop/interface/gtk-theme", f"'{gtk_theme}'"])
""",
        new,
    ),
    # Older upstream shape.
    (
        """    subprocess.run(["dconf", "write", "/org/gnome/desktop/interface/gtk-theme", "'adw-gtk3-dark'"])
""",
        new,
    ),
]

for old, replacement in replacements:
    if old in content:
        theme_path.write_text(content.replace(old, replacement))
        raise SystemExit(0)

raise SystemExit(f"Expected Caelestia GTK theme block not found in {theme_path}")
PY
