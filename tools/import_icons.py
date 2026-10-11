#!/usr/bin/env python3
"""Copies a drawn icon set into godot/ui/icons as 128 px PNGs.

The icons are pure white silhouettes on transparent (the game tints them, see UiIcons). The generated files
are named after the request list; ALIASES maps those to the game's icon names. Every canvas is kept as drawn
(not cropped) so the padding and visual size the artist gave the whole set stay consistent; only
a premultiplied downscale is applied, so the transparent pixels' colour cannot bleed into the edges.

    python tools/import_icons.py DIR [DIR ...]      # folders of <name>.png; later folders win
"""
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "godot" / "ui" / "icons"
SIZE = 128
ALIASES = {
    "fishing": "fish", "region": "mountain", "weather_clear": "clear", "weather_cloudy": "cloudy",
    "weather_rain": "rain", "weather_fog": "mist", "weather_storm": "storm",
}


def main() -> None:
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    found: dict[str, Path] = {}
    for folder in sys.argv[1:]:
        for path in sorted(Path(folder).glob("*.png")):
            found[ALIASES.get(path.stem, path.stem)] = path
    known = {svg.stem for svg in OUT.glob("*.svg")}
    for name, path in sorted(found.items()):
        if name not in known:
            print(f"skipped {path.name}: the game has no icon named '{name}'")
            continue
        image = Image.open(path).convert("RGBa").resize((SIZE, SIZE), Image.LANCZOS).convert("RGBA")
        image.save(OUT / f"{name}.png", optimize=True)
        print(f"{path.name} -> godot/ui/icons/{name}.png")
    missing = sorted(known - found.keys())
    print("not replaced (still the coded SVG): " + ", ".join(missing) if missing else "the whole set is drawn")


if __name__ == "__main__":
    main()
