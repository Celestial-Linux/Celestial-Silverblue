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

terminal_old = r'''def c2s(c: str, *i: list[int]) -> str:
    """Hex to ANSI sequence (e.g. ffffff, 11 -> \x1b]11;rgb:ff/ff/ff\x1b\\)"""
    return f"\x1b]{';'.join(map(str, i))};rgb:{c[0:2]}/{c[2:4]}/{c[4:6]}\x1b\\"


def gen_sequences(colours: dict[str, str]) -> str:
    """
    10: foreground
    11: background
    12: cursor
    17: selection
    4:
        0 - 7: normal colours
        8 - 15: bright colours
        16+: 256 colours
    """
    return (
        c2s(colours["onSurface"], 10)
        + c2s(colours["surface"], 11)
        + c2s(colours["secondary"], 12)
        + c2s(colours["secondary"], 17)
        + c2s(colours["term0"], 4, 0)
        + c2s(colours["term1"], 4, 1)
        + c2s(colours["term2"], 4, 2)
        + c2s(colours["term3"], 4, 3)
        + c2s(colours["term4"], 4, 4)
        + c2s(colours["term5"], 4, 5)
        + c2s(colours["term6"], 4, 6)
        + c2s(colours["term7"], 4, 7)
        + c2s(colours["term8"], 4, 8)
        + c2s(colours["term9"], 4, 9)
        + c2s(colours["term10"], 4, 10)
        + c2s(colours["term11"], 4, 11)
        + c2s(colours["term12"], 4, 12)
        + c2s(colours["term13"], 4, 13)
        + c2s(colours["term14"], 4, 14)
        + c2s(colours["term15"], 4, 15)
        + c2s(colours["primary"], 4, 16)
        + c2s(colours["secondary"], 4, 17)
        + c2s(colours["tertiary"], 4, 18)
    )


def write_file(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)

    with tempfile.NamedTemporaryFile("w") as f:
        f.write(content)
        f.flush()
        shutil.move(f.name, path)


@log_exception
def apply_terms(sequences: str) -> None:
    state = c_state_dir / "sequences.txt"
    state.parent.mkdir(parents=True, exist_ok=True)
    state.write_text(sequences)

    pts_path = Path("/dev/pts")
    for pt in pts_path.iterdir():
        if pt.name.isdigit():
            try:
                # Use non-blocking write with timeout to prevent hangs
                import os

                fd = os.open(str(pt), os.O_WRONLY | os.O_NONBLOCK | os.O_NOCTTY)
                try:
                    os.write(fd, sequences.encode())
                finally:
                    os.close(fd)
            except (PermissionError, OSError, BlockingIOError):
                # Skip terminals that are busy, closed, or inaccessible
                pass
'''

terminal_new = '''def gen_kitty_config(colours: dict[str, str]) -> str:
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

    return "\\n".join(f"{name} #{colour}" for name, colour in settings.items()) + "\\n"


def write_file(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.is_symlink():
        path.unlink()

    with tempfile.NamedTemporaryFile("w") as f:
        f.write(content)
        f.flush()
        shutil.move(f.name, path)


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
    if terminal_old not in content:
        raise SystemExit(f"Expected Caelestia terminal sequence block not found in {theme_path}")
    content = content.replace(terminal_old, terminal_new)

content = content.replace("apply_terms(gen_sequences(colours))", "apply_terms(colours)")

write_file_new = '''def write_file(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.is_symlink():
        path.unlink()

    with tempfile.NamedTemporaryFile("w") as f:
        f.write(content)
        f.flush()
        shutil.move(f.name, path)
'''

if write_file_new not in content:
    write_file_replacements = [
        '''def write_file(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)

    with tempfile.NamedTemporaryFile("w") as f:
        f.write(content)
        f.flush()
        shutil.move(f.name, path)
''',
    ]

    for old in write_file_replacements:
        if old in content:
            content = content.replace(old, write_file_new)
            break
    else:
        raise SystemExit(f"Expected Caelestia write_file block not found in {theme_path}")

if content != original:
    theme_path.write_text(content)
PY
