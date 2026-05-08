#!/usr/bin/env bash

set -euo pipefail

python3 - <<'PY'
import re
from pathlib import Path

matches = sorted(Path("/usr/lib").glob("python*/site-packages/caelestia/utils/theme.py"))
if not matches:
    raise SystemExit("Caelestia theme.py was not found under /usr/lib/python*/site-packages")
if len(matches) > 1:
    raise SystemExit(f"Found multiple Caelestia theme.py files: {matches}")

theme_path = matches[0]

content = theme_path.read_text()
original = content

gtk_new = """    gtk_theme = "adw-gtk3-dark" if mode == "dark" else "adw-gtk3"
    color_scheme = "prefer-dark" if mode == "dark" else "prefer-light"
    subprocess.run(["gsettings", "set", "org.gnome.desktop.interface", "gtk-theme", gtk_theme])
    subprocess.run(["gsettings", "set", "org.gnome.desktop.interface", "color-scheme", color_scheme])
"""

gtk_replacements = [
    # Current upstream shape: hard-coded dark GTK theme followed by mode-derived color scheme.
    (
        """    subprocess.run(["dconf", "write", "/org/gnome/desktop/interface/gtk-theme", "'adw-gtk3-dark'"])
    subprocess.run(["dconf", "write", "/org/gnome/desktop/interface/color-scheme", f"'prefer-{mode}'"])
""",
        gtk_new,
    ),
    # Previous Celestial patch applied on top of current upstream.
    (
        """    gtk_theme = "adw-gtk3-dark" if mode == "dark" else "adw-gtk3"
    color_scheme = "prefer-dark" if mode == "dark" else "default"
    subprocess.run(["dconf", "write", "/org/gnome/desktop/interface/gtk-theme", f"'{gtk_theme}'"])
    subprocess.run(["dconf", "write", "/org/gnome/desktop/interface/color-scheme", f"'{color_scheme}'"])
    subprocess.run(["dconf", "write", "/org/gnome/desktop/interface/color-scheme", f"'prefer-{mode}'"])
""",
        gtk_new,
    ),
    # Previous Celestial patch applied before upstream added color-scheme handling.
    (
        """    gtk_theme = "adw-gtk3-dark" if mode == "dark" else "adw-gtk3"
    subprocess.run(["dconf", "write", "/org/gnome/desktop/interface/gtk-theme", f"'{gtk_theme}'"])
""",
        gtk_new,
    ),
    # Older upstream shape.
    (
        """    subprocess.run(["dconf", "write", "/org/gnome/desktop/interface/gtk-theme", "'adw-gtk3-dark'"])
""",
        gtk_new,
    ),
]

if gtk_new not in content:
    for old, replacement in gtk_replacements:
        if old in content:
            content = content.replace(old, replacement)
            break
    else:
        raise SystemExit(f"Expected Caelestia GTK theme block not found in {theme_path}")

terminal_new = r'''def gen_kitty_config(colours: dict[str, str]) -> str:
    settings = {
        "foreground": colours["onSurface"],
        "background": colours["surface"],
        "cursor": colours["secondary"],
        "selection_background": colours["secondary"],
    }
    settings.update({f"color{i}": colours[f"term{i}"] for i in range(16)})
    settings.update(
        {
            "color16": colours["primary"],
            "color17": colours["secondary"],
            "color18": colours["tertiary"],
        }
    )

    return "\n".join(f"{name} #{colour}" for name, colour in settings.items()) + "\n"


def write_file(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.is_symlink():
        path.unlink()

    path.write_text(content)


@log_exception
def apply_terms(colours: dict[str, str]) -> None:
    kitty_config = theme_dir / "kitty.conf"
    write_file(kitty_config, gen_kitty_config(colours))

    try:
        (c_state_dir / "sequences.txt").unlink()
    except FileNotFoundError:
        pass

    subprocess.run(
        ["kitty", "@", "set-colors", "--all", "--configured", str(kitty_config)],
        stderr=subprocess.DEVNULL,
    )
'''

if terminal_new not in content:
    terminal_pattern = re.compile(
        r"(?:"
        r"def \w+\(c: str, \*i: (?:list\[int\]|int)\) -> str:"
        r"|def gen_kitty_config\(colours: dict\[str, str\]\) -> str:"
        r")\n.*?"
        r"\n(?=@log_exception\ndef apply_hypr\(conf: str\) -> None:\n)",
        re.DOTALL,
    )
    content, terminal_count = terminal_pattern.subn(lambda _: terminal_new, content, count=1)
    if terminal_count != 1:
        raise SystemExit(f"Expected Caelestia terminal sequence block not found in {theme_path}")

content = content.replace("apply_terms(gen_sequences(colours))", "apply_terms(colours)")

write_file_new = '''def write_file(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.is_symlink():
        path.unlink()

    path.write_text(content)
'''

if write_file_new not in content:
    write_file_pattern = re.compile(
        r"def write_file\(path: Path, content: str\) -> None:\n"
        r".*?"
        r"\n(?=@log_exception\ndef apply_terms\()",
        re.DOTALL,
    )
    content, write_file_count = write_file_pattern.subn(lambda _: write_file_new, content, count=1)
    if write_file_count != 1:
        raise SystemExit(f"Expected Caelestia write_file block not found in {theme_path}")

if content != original:
    theme_path.write_text(content)
PY
