#!/usr/bin/env python3
"""Lays the pictures of a folder out on one sheet for a quick look before they go into the game.

Generated pictures need a human eye: a "top view" that came back as a side view, a fish that looks like
another species, a stray shadow. Telling top from side views automatically was measured on the 72 fish
(2026-10-13, #90) and does not work — silhouette symmetry and back/belly brightness overlap between
right and wrong pictures — so this makes the look fast instead: `<name>_top`/`<name>_side` pairs share a
row, everything sits on a mid-blue backdrop (so a white halo or a black edge shows), and a picture with no
transparent pixel at all (a painted-in checkerboard) gets a red frame.

    python tools/review_sheet.py DIR [OUT.png]
"""
import re
import sys
from pathlib import Path

from PIL import Image, ImageDraw

CELL = (480, 110)
BACKDROP = (60, 90, 110, 255)


def fully_opaque(picture: Image.Image) -> bool:
    return picture.mode not in ("RGBA", "LA", "PA") or picture.getchannel("A").getextrema()[0] == 255


def rows_of(paths: list[Path]) -> list[list[Path]]:
    """Top/side pairs of one name share a row (top first); any other picture gets a row of its own."""
    rows: dict[str, list[Path]] = {}
    for path in paths:
        match = re.fullmatch(r"(.+)_(top|side)", path.stem)
        key = match.group(1) if match else path.stem
        rows.setdefault(key, []).append(path)
    return [sorted(row, key=lambda p: (not p.stem.endswith("_top"), p.stem)) for _, row in sorted(rows.items())]


def main() -> None:
    if len(sys.argv) not in (2, 3):
        sys.exit(__doc__)
    folder = Path(sys.argv[1])
    out = Path(sys.argv[2]) if len(sys.argv) == 3 else folder / "review_sheet.png"
    rows = rows_of(sorted(p for p in folder.glob("*.png") if p != out))
    if not rows:
        sys.exit(f"no pictures in {folder}")
    columns = max(len(row) for row in rows)
    sheet = Image.new("RGBA", (columns * (CELL[0] + 20), len(rows) * (CELL[1] + 24)), BACKDROP)
    draw = ImageDraw.Draw(sheet)
    flagged = []
    for r, row in enumerate(rows):
        for c, path in enumerate(row):
            picture = Image.open(path)
            opaque = fully_opaque(picture)
            thumb = picture.convert("RGBA")
            thumb.thumbnail(CELL)
            x, y = c * (CELL[0] + 20) + 10, r * (CELL[1] + 24) + 4
            sheet.alpha_composite(thumb, (x, y))
            draw.text((x, y + CELL[1] + 4), path.stem, fill=(255, 255, 255, 255))
            if opaque:
                flagged.append(path.name)
                draw.rectangle((x - 3, y - 3, x + thumb.width + 3, y + thumb.height + 3), outline=(230, 40, 40, 255), width=4)
    sheet.save(out)
    print(f"{out} ({sum(len(row) for row in rows)} pictures)")
    for name in flagged:
        print(f"NO TRANSPARENCY: {name}")


if __name__ == "__main__":
    main()
