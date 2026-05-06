#!/usr/bin/env bash

set -oue pipefail

python3 - <<'PY'
from __future__ import annotations

import colorsys
from pathlib import Path


def clamp(value: float, low: float = 0.0, high: float = 1.0) -> float:
    return min(high, max(low, value))


def read_scheme(path: Path) -> dict[str, str]:
    return {
        key.strip(): value.strip().lstrip("#")
        for key, value in (line.split(" ") for line in path.read_text().splitlines() if line)
    }


def rgb_to_hex(r: float, g: float, b: float) -> str:
    return f"{round(clamp(r) * 255):02X}{round(clamp(g) * 255):02X}{round(clamp(b) * 255):02X}"


def hsl(
    hex_value: str,
    *,
    hue_shift: float = 0.0,
    sat_scale: float = 1.0,
    light_shift: float = 0.0,
    sat: float | None = None,
    light: float | None = None,
) -> str:
    hex_value = hex_value.strip().lstrip("#")
    r, g, b = (int(hex_value[index : index + 2], 16) / 255 for index in (0, 2, 4))
    hue, luminance, saturation = colorsys.rgb_to_hls(r, g, b)

    hue = (hue + hue_shift / 360.0) % 1.0
    saturation = clamp((saturation if sat is None else sat) * sat_scale)
    luminance = clamp((luminance if light is None else light) + light_shift)

    return rgb_to_hex(*colorsys.hls_to_rgb(hue, luminance, saturation))


def base_colours(source: dict[str, str]) -> dict[str, str]:
    return {
        "bg": source["background"],
        "fg": source["onBackground"],
        "green": source["green"],
        "aqua": source["teal"],
        "blue": source["blue"],
        "yellow": source["yellow"],
        "orange": source["peach"],
        "red": source["red"],
        "purple": source["mauve"],
        "grey": source["overlay2"],
    }


def validate_scheme(source: dict[str, str], scheme: dict[str, str], name: str) -> None:
    missing = set(source) - set(scheme)
    if missing:
        raise SystemExit(f"{name} is missing Caelestia colour roles: {sorted(missing)}")


def build_nurture_light(source: dict[str, str]) -> dict[str, str]:
    base = base_colours(source)

    def c(name: str, **kwargs: float) -> str:
        return hsl(base[name], **kwargs)

    scheme = {
        "primary_paletteKeyColor": c("green", sat_scale=0.82, light=0.36),
        "secondary_paletteKeyColor": c("aqua", sat_scale=0.58, light=0.40),
        "tertiary_paletteKeyColor": c("orange", sat_scale=0.62, light=0.47),
        "neutral_paletteKeyColor": c("fg", sat_scale=0.38, light=0.52),
        "neutral_variant_paletteKeyColor": c("grey", sat_scale=0.34, light=0.56),
        "background": c("bg", sat_scale=0.74, light=0.96),
        "onBackground": c("fg", sat_scale=0.88, light=0.28),
        "surface": c("bg", sat_scale=0.74, light=0.96),
        "surfaceDim": c("bg", sat_scale=0.48, light=0.89),
        "surfaceBright": c("bg", sat_scale=0.86, light=0.98),
        "surfaceContainerLowest": c("bg", sat_scale=0.90, light=0.99),
        "surfaceContainerLow": c("bg", sat_scale=0.58, light=0.94),
        "surfaceContainer": c("bg", sat_scale=0.48, light=0.92),
        "surfaceContainerHigh": c("bg", sat_scale=0.40, light=0.89),
        "surfaceContainerHighest": c("bg", sat_scale=0.36, light=0.86),
        "onSurface": c("fg", sat_scale=0.88, light=0.27),
        "surfaceVariant": c("grey", sat_scale=0.22, light=0.82),
        "onSurfaceVariant": c("fg", sat_scale=0.58, light=0.39),
        "inverseSurface": c("fg", sat_scale=0.70, light=0.25),
        "inverseOnSurface": c("bg", sat_scale=0.64, light=0.94),
        "outline": c("fg", sat_scale=0.32, light=0.55),
        "outlineVariant": c("grey", sat_scale=0.20, light=0.74),
        "shadow": "000000",
        "scrim": "000000",
        "surfaceTint": c("green", sat_scale=0.82, light=0.36),
        "primary": c("green", sat_scale=0.86, light=0.32),
        "onPrimary": c("bg", sat_scale=0.80, light=0.98),
        "primaryContainer": c("green", sat_scale=0.54, light=0.78),
        "onPrimaryContainer": c("green", sat_scale=0.86, light=0.18),
        "inversePrimary": c("green", sat_scale=0.62, light=0.70),
        "secondary": c("aqua", sat_scale=0.58, light=0.34),
        "onSecondary": c("bg", sat_scale=0.80, light=0.98),
        "secondaryContainer": c("aqua", sat_scale=0.42, light=0.82),
        "onSecondaryContainer": c("aqua", sat_scale=0.70, light=0.19),
        "tertiary": c("orange", sat_scale=0.68, light=0.38),
        "onTertiary": c("bg", sat_scale=0.80, light=0.98),
        "tertiaryContainer": c("orange", sat_scale=0.62, light=0.83),
        "onTertiaryContainer": c("orange", sat_scale=0.78, light=0.20),
        "error": c("red", sat_scale=0.86, light=0.42),
        "onError": c("bg", sat_scale=0.80, light=0.98),
        "errorContainer": c("red", sat_scale=0.62, light=0.84),
        "onErrorContainer": c("red", sat_scale=0.82, light=0.20),
        "primaryFixed": c("green", sat_scale=0.48, light=0.86),
        "primaryFixedDim": c("green", sat_scale=0.54, light=0.74),
        "onPrimaryFixed": c("green", sat_scale=0.86, light=0.18),
        "onPrimaryFixedVariant": c("green", sat_scale=0.80, light=0.30),
        "secondaryFixed": c("aqua", sat_scale=0.40, light=0.88),
        "secondaryFixedDim": c("aqua", sat_scale=0.42, light=0.78),
        "onSecondaryFixed": c("aqua", sat_scale=0.72, light=0.17),
        "onSecondaryFixedVariant": c("aqua", sat_scale=0.64, light=0.30),
        "tertiaryFixed": c("orange", sat_scale=0.52, light=0.89),
        "tertiaryFixedDim": c("orange", sat_scale=0.58, light=0.77),
        "onTertiaryFixed": c("orange", sat_scale=0.82, light=0.17),
        "onTertiaryFixedVariant": c("orange", sat_scale=0.76, light=0.31),
        "term0": c("fg", sat_scale=0.52, light=0.24),
        "term1": c("red", sat_scale=0.78, light=0.43),
        "term2": c("green", sat_scale=0.82, light=0.33),
        "term3": c("yellow", sat_scale=0.76, light=0.43),
        "term4": c("blue", sat_scale=0.64, light=0.43),
        "term5": c("purple", sat_scale=0.62, light=0.49),
        "term6": c("aqua", sat_scale=0.62, light=0.39),
        "term7": c("bg", sat_scale=0.64, light=0.91),
        "term8": c("fg", sat_scale=0.36, light=0.48),
        "term9": c("red", sat_scale=0.70, light=0.56),
        "term10": c("green", sat_scale=0.60, light=0.47),
        "term11": c("yellow", sat_scale=0.58, light=0.56),
        "term12": c("blue", sat_scale=0.54, light=0.56),
        "term13": c("purple", sat_scale=0.54, light=0.62),
        "term14": c("aqua", sat_scale=0.50, light=0.54),
        "term15": c("bg", sat_scale=0.82, light=0.98),
        "rosewater": c("orange", hue_shift=-12, sat_scale=0.40, light=0.80),
        "flamingo": c("red", hue_shift=8, sat_scale=0.42, light=0.78),
        "pink": c("purple", sat_scale=0.42, light=0.78),
        "mauve": c("purple", hue_shift=18, sat_scale=0.42, light=0.72),
        "red": c("red", sat_scale=0.72, light=0.55),
        "maroon": c("red", hue_shift=-8, sat_scale=0.62, light=0.48),
        "peach": c("orange", sat_scale=0.66, light=0.61),
        "yellow": c("yellow", sat_scale=0.64, light=0.59),
        "green": c("green", sat_scale=0.58, light=0.45),
        "teal": c("aqua", sat_scale=0.54, light=0.48),
        "sky": c("aqua", hue_shift=12, sat_scale=0.50, light=0.62),
        "sapphire": c("blue", hue_shift=-8, sat_scale=0.54, light=0.50),
        "blue": c("blue", sat_scale=0.56, light=0.56),
        "lavender": c("purple", hue_shift=22, sat_scale=0.36, light=0.72),
        "klink": c("blue", sat_scale=0.56, light=0.48),
        "klinkSelection": c("blue", sat_scale=0.56, light=0.48),
        "kvisited": c("aqua", sat_scale=0.54, light=0.42),
        "kvisitedSelection": c("aqua", sat_scale=0.54, light=0.42),
        "knegative": c("red", sat_scale=0.72, light=0.49),
        "knegativeSelection": c("red", sat_scale=0.72, light=0.49),
        "kneutral": c("yellow", sat_scale=0.64, light=0.50),
        "kneutralSelection": c("yellow", sat_scale=0.64, light=0.50),
        "kpositive": c("green", sat_scale=0.58, light=0.39),
        "kpositiveSelection": c("green", sat_scale=0.58, light=0.39),
        "text": c("fg", sat_scale=0.88, light=0.27),
        "subtext1": c("fg", sat_scale=0.58, light=0.39),
        "subtext0": c("fg", sat_scale=0.44, light=0.48),
        "overlay2": c("fg", sat_scale=0.34, light=0.57),
        "overlay1": c("fg", sat_scale=0.28, light=0.65),
        "overlay0": c("fg", sat_scale=0.22, light=0.72),
        "surface2": c("grey", sat_scale=0.22, light=0.82),
        "surface1": c("bg", sat_scale=0.40, light=0.89),
        "surface0": c("bg", sat_scale=0.48, light=0.92),
        "base": c("bg", sat_scale=0.74, light=0.96),
        "mantle": c("bg", sat_scale=0.58, light=0.94),
        "crust": c("bg", sat_scale=0.48, light=0.91),
        "success": c("green", sat_scale=0.58, light=0.38),
        "onSuccess": c("bg", sat_scale=0.80, light=0.98),
        "successContainer": c("green", sat_scale=0.44, light=0.82),
        "onSuccessContainer": c("green", sat_scale=0.82, light=0.18),
    }

    validate_scheme(source, scheme, "Nurture light scheme")

    return scheme


def build_nurture_dark(source: dict[str, str]) -> dict[str, str]:
    base = base_colours(source)

    def c(name: str, **kwargs: float) -> str:
        return hsl(base[name], **kwargs)

    scheme = {
        "primary_paletteKeyColor": c("green", sat_scale=0.64, light=0.64),
        "secondary_paletteKeyColor": c("aqua", sat_scale=0.52, light=0.58),
        "tertiary_paletteKeyColor": c("orange", sat_scale=0.54, light=0.60),
        "neutral_paletteKeyColor": c("fg", sat_scale=0.34, light=0.62),
        "neutral_variant_paletteKeyColor": c("grey", sat_scale=0.28, light=0.46),
        "background": c("bg", sat_scale=0.82, light=0.12),
        "onBackground": c("fg", sat_scale=0.66, light=0.86),
        "surface": c("bg", sat_scale=0.76, light=0.13),
        "surfaceDim": c("bg", sat_scale=0.70, light=0.10),
        "surfaceBright": c("bg", sat_scale=0.64, light=0.24),
        "surfaceContainerLowest": c("bg", sat_scale=0.74, light=0.08),
        "surfaceContainerLow": c("bg", sat_scale=0.72, light=0.15),
        "surfaceContainer": c("bg", sat_scale=0.70, light=0.17),
        "surfaceContainerHigh": c("bg", sat_scale=0.66, light=0.20),
        "surfaceContainerHighest": c("bg", sat_scale=0.62, light=0.24),
        "onSurface": c("fg", sat_scale=0.66, light=0.86),
        "surfaceVariant": c("grey", sat_scale=0.20, light=0.25),
        "onSurfaceVariant": c("fg", sat_scale=0.42, light=0.72),
        "inverseSurface": c("fg", sat_scale=0.62, light=0.86),
        "inverseOnSurface": c("bg", sat_scale=0.80, light=0.14),
        "outline": c("fg", sat_scale=0.24, light=0.56),
        "outlineVariant": c("grey", sat_scale=0.18, light=0.30),
        "shadow": "000000",
        "scrim": "000000",
        "surfaceTint": c("green", sat_scale=0.62, light=0.68),
        "primary": c("green", sat_scale=0.62, light=0.68),
        "onPrimary": c("bg", sat_scale=0.84, light=0.13),
        "primaryContainer": c("green", sat_scale=0.42, light=0.28),
        "onPrimaryContainer": c("green", sat_scale=0.56, light=0.88),
        "inversePrimary": c("green", sat_scale=0.54, light=0.44),
        "secondary": c("aqua", sat_scale=0.48, light=0.68),
        "onSecondary": c("bg", sat_scale=0.84, light=0.13),
        "secondaryContainer": c("aqua", sat_scale=0.34, light=0.26),
        "onSecondaryContainer": c("aqua", sat_scale=0.48, light=0.87),
        "tertiary": c("orange", sat_scale=0.58, light=0.70),
        "onTertiary": c("bg", sat_scale=0.84, light=0.13),
        "tertiaryContainer": c("orange", sat_scale=0.38, light=0.28),
        "onTertiaryContainer": c("orange", sat_scale=0.52, light=0.88),
        "error": c("red", sat_scale=0.70, light=0.72),
        "onError": c("bg", sat_scale=0.84, light=0.13),
        "errorContainer": c("red", sat_scale=0.48, light=0.28),
        "onErrorContainer": c("red", sat_scale=0.68, light=0.88),
        "primaryFixed": c("green", sat_scale=0.48, light=0.86),
        "primaryFixedDim": c("green", sat_scale=0.54, light=0.74),
        "onPrimaryFixed": c("green", sat_scale=0.82, light=0.16),
        "onPrimaryFixedVariant": c("green", sat_scale=0.74, light=0.30),
        "secondaryFixed": c("aqua", sat_scale=0.40, light=0.86),
        "secondaryFixedDim": c("aqua", sat_scale=0.44, light=0.74),
        "onSecondaryFixed": c("aqua", sat_scale=0.70, light=0.15),
        "onSecondaryFixedVariant": c("aqua", sat_scale=0.62, light=0.29),
        "tertiaryFixed": c("orange", sat_scale=0.48, light=0.87),
        "tertiaryFixedDim": c("orange", sat_scale=0.54, light=0.75),
        "onTertiaryFixed": c("orange", sat_scale=0.78, light=0.15),
        "onTertiaryFixedVariant": c("orange", sat_scale=0.70, light=0.30),
        "term0": c("bg", sat_scale=0.82, light=0.12),
        "term1": c("red", sat_scale=0.68, light=0.66),
        "term2": c("green", sat_scale=0.58, light=0.62),
        "term3": c("yellow", sat_scale=0.56, light=0.66),
        "term4": c("blue", sat_scale=0.52, light=0.64),
        "term5": c("purple", sat_scale=0.52, light=0.66),
        "term6": c("aqua", sat_scale=0.52, light=0.62),
        "term7": c("fg", sat_scale=0.58, light=0.82),
        "term8": c("fg", sat_scale=0.26, light=0.50),
        "term9": c("red", sat_scale=0.62, light=0.76),
        "term10": c("green", sat_scale=0.52, light=0.72),
        "term11": c("yellow", sat_scale=0.50, light=0.76),
        "term12": c("blue", sat_scale=0.46, light=0.74),
        "term13": c("purple", sat_scale=0.46, light=0.76),
        "term14": c("aqua", sat_scale=0.46, light=0.72),
        "term15": c("fg", sat_scale=0.60, light=0.92),
        "rosewater": c("orange", hue_shift=-12, sat_scale=0.36, light=0.78),
        "flamingo": c("red", hue_shift=8, sat_scale=0.42, light=0.75),
        "pink": c("purple", sat_scale=0.42, light=0.76),
        "mauve": c("purple", hue_shift=18, sat_scale=0.44, light=0.72),
        "red": c("red", sat_scale=0.62, light=0.68),
        "maroon": c("red", hue_shift=-8, sat_scale=0.58, light=0.60),
        "peach": c("orange", sat_scale=0.62, light=0.68),
        "yellow": c("yellow", sat_scale=0.58, light=0.72),
        "green": c("green", sat_scale=0.54, light=0.66),
        "teal": c("aqua", sat_scale=0.48, light=0.66),
        "sky": c("aqua", hue_shift=12, sat_scale=0.46, light=0.72),
        "sapphire": c("blue", hue_shift=-8, sat_scale=0.50, light=0.66),
        "blue": c("blue", sat_scale=0.50, light=0.68),
        "lavender": c("purple", hue_shift=22, sat_scale=0.38, light=0.76),
        "klink": c("blue", sat_scale=0.52, light=0.64),
        "klinkSelection": c("blue", sat_scale=0.52, light=0.64),
        "kvisited": c("aqua", sat_scale=0.50, light=0.60),
        "kvisitedSelection": c("aqua", sat_scale=0.50, light=0.60),
        "knegative": c("red", sat_scale=0.62, light=0.62),
        "knegativeSelection": c("red", sat_scale=0.62, light=0.62),
        "kneutral": c("yellow", sat_scale=0.58, light=0.62),
        "kneutralSelection": c("yellow", sat_scale=0.58, light=0.62),
        "kpositive": c("green", sat_scale=0.54, light=0.58),
        "kpositiveSelection": c("green", sat_scale=0.54, light=0.58),
        "text": c("fg", sat_scale=0.66, light=0.86),
        "subtext1": c("fg", sat_scale=0.42, light=0.74),
        "subtext0": c("fg", sat_scale=0.34, light=0.64),
        "overlay2": c("fg", sat_scale=0.28, light=0.54),
        "overlay1": c("fg", sat_scale=0.22, light=0.46),
        "overlay0": c("fg", sat_scale=0.18, light=0.38),
        "surface2": c("grey", sat_scale=0.20, light=0.30),
        "surface1": c("bg", sat_scale=0.66, light=0.20),
        "surface0": c("bg", sat_scale=0.70, light=0.17),
        "base": c("bg", sat_scale=0.82, light=0.12),
        "mantle": c("bg", sat_scale=0.74, light=0.10),
        "crust": c("bg", sat_scale=0.76, light=0.08),
        "success": c("green", sat_scale=0.54, light=0.58),
        "onSuccess": c("bg", sat_scale=0.84, light=0.13),
        "successContainer": c("green", sat_scale=0.40, light=0.27),
        "onSuccessContainer": c("green", sat_scale=0.56, light=0.86),
    }

    validate_scheme(source, scheme, "Nurture dark scheme")

    return scheme


def write_scheme(source: dict[str, str], scheme: dict[str, str], destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text("\n".join(f"{key} {scheme[key]}" for key in source) + "\n")


scheme_roots = sorted(Path("/usr/lib").glob("python*/site-packages/caelestia/data/schemes"))
if not scheme_roots:
    raise SystemExit("Caelestia scheme data directory was not found under /usr/lib/python*/site-packages")

for scheme_root in scheme_roots:
    light_source_path = scheme_root / "everforest" / "medium" / "light.txt"
    dark_source_path = scheme_root / "everforest" / "medium" / "dark.txt"
    if not light_source_path.exists():
        raise SystemExit(f"Expected Everforest light scheme was not found at {light_source_path}")
    if not dark_source_path.exists():
        raise SystemExit(f"Expected Everforest dark scheme was not found at {dark_source_path}")

    light_source = read_scheme(light_source_path)
    dark_source = read_scheme(dark_source_path)
    write_scheme(
        light_source,
        build_nurture_light(light_source),
        scheme_root / "nurture" / "default" / "light.txt",
    )
    write_scheme(
        dark_source,
        build_nurture_dark(dark_source),
        scheme_root / "nurture" / "default" / "dark.txt",
    )
PY
