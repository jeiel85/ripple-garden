#!/usr/bin/env python3
"""Cuts fixed-word UI pieces out of the mockups into godot/art/ui/ (D-032; Korean only: the words are baked in).

The bottom bar (mockup 01), the title boards of the journal, gear, camp and map (04-07) and the catch result's three
action cards (03).

Each mockup is one flat picture, so each piece is cut with a rounded-rectangle mask fitted to its border (the
blurred scenery around it is left out). The camp button has the mockup's orange "new" dot baked on its top-right
corner; the game draws its own dot, so that corner is replaced by the button's clean top-left corner, mirrored.
Pictures keep the mockup's pixel size (941 px wide mockup, a little more than the 720 px design); the HUD sizes the
buttons from each picture's aspect ratio.

    python tools/crop_mockup_ui.py
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageOps

ROOT = Path(__file__).resolve().parents[1]
MOCKUPS = ROOT / "assets" / "design" / "mockups"
OUT = ROOT / "godot" / "art" / "ui"
SUPER = 4  # mask supersampling, for smooth rounded corners
# name: (mockup, left, top, right, bottom, corner radius) in mockup pixels, on the piece's outer edge.
PIECES = {
    "nav_journal": ("01_main_world.png", 35, 1477, 151, 1587, 24),
    "nav_gear": ("01_main_world.png", 166, 1477, 282, 1587, 24),
    "nav_cast": ("01_main_world.png", 309, 1440, 673, 1596, 72),
    "nav_camp": ("01_main_world.png", 699, 1477, 907, 1587, 24),
    # Title boards: the plank only (the hanging ropes and the leaves reaching past it are left out).
    "sign_journal": ("04_journal.png", 252, 46, 690, 142, 18),
    "sign_gear": ("05_equipment.png", 37, 140, 440, 322, 18),  # its two-line subtitle is on the board
    "sign_camp": ("06_camp_edit.png", 108, 125, 326, 205, 14),
    "sign_map": ("07_region_map.png", 268, 128, 656, 236, 18),
    # Catch result actions.
    "card_release": ("03_catch_result.png", 38, 1386, 292, 1553, 36),
    "card_record": ("03_catch_result.png", 324, 1386, 582, 1553, 36),
    "card_again": ("03_catch_result.png", 602, 1370, 905, 1554, 40),
}
DOT_CORNER = 62  # px of the camp button's top-right corner replaced (covers the baked dot)


def rounded_mask(size: tuple[int, int], radius: int) -> Image.Image:
    big = Image.new("L", (size[0] * SUPER, size[1] * SUPER), 0)
    ImageDraw.Draw(big).rounded_rectangle((0, 0, big.width - 1, big.height - 1), radius * SUPER, fill=255)
    return big.resize(size, Image.LANCZOS)


def main() -> None:
    for name, (source, x0, y0, x1, y1, radius) in PIECES.items():
        piece = Image.open(MOCKUPS / source).convert("RGB").crop((x0, y0, x1, y1))
        if name == "nav_camp":
            corner = ImageOps.mirror(piece.crop((0, 0, DOT_CORNER, DOT_CORNER)))
            piece.paste(corner, (piece.width - DOT_CORNER, 0))
        rgba = piece.convert("RGBA")
        rgba.putalpha(rounded_mask(piece.size, radius))
        rgba.save(OUT / f"{name}.png", optimize=True)
        print(f"{name}: {piece.width}x{piece.height}")


if __name__ == "__main__":
    main()
