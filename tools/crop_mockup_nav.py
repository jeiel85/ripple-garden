#!/usr/bin/env python3
"""Cuts the bottom-bar buttons out of mockup 01 into godot/art/ui/nav_*.png (Korean only: the words are baked in).

The mockup is one flat picture, so each button is cut with a rounded-rectangle mask fitted to its border (the
blurred scenery around it is left out). The camp button has the mockup's orange "new" dot baked on its top-right
corner; the game draws its own dot, so that corner is replaced by the button's clean top-left corner, mirrored.
Pictures keep the mockup's pixel size (941 px wide mockup, a little more than the 720 px design); the HUD sizes the
buttons from each picture's aspect ratio.

    python tools/crop_mockup_nav.py
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageOps

ROOT = Path(__file__).resolve().parents[1]
MOCKUP = ROOT / "assets" / "design" / "mockups" / "01_main_world.png"
OUT = ROOT / "godot" / "art" / "ui"
SUPER = 4  # mask supersampling, for smooth rounded corners
# name: (left, top, right, bottom, corner radius) in mockup pixels, measured on the border's outer edge.
BUTTONS = {
    "nav_journal": (35, 1477, 151, 1587, 24),
    "nav_gear": (166, 1477, 282, 1587, 24),
    "nav_cast": (309, 1440, 673, 1596, 72),
    "nav_camp": (699, 1477, 907, 1587, 24),
}
DOT_CORNER = 62  # px of the camp button's top-right corner replaced (covers the baked dot)


def rounded_mask(size: tuple[int, int], radius: int) -> Image.Image:
    big = Image.new("L", (size[0] * SUPER, size[1] * SUPER), 0)
    ImageDraw.Draw(big).rounded_rectangle((0, 0, big.width - 1, big.height - 1), radius * SUPER, fill=255)
    return big.resize(size, Image.LANCZOS)


def main() -> None:
    mockup = Image.open(MOCKUP).convert("RGB")
    for name, (x0, y0, x1, y1, radius) in BUTTONS.items():
        piece = mockup.crop((x0, y0, x1, y1))
        if name == "nav_camp":
            corner = ImageOps.mirror(piece.crop((0, 0, DOT_CORNER, DOT_CORNER)))
            piece.paste(corner, (piece.width - DOT_CORNER, 0))
        rgba = piece.convert("RGBA")
        rgba.putalpha(rounded_mask(piece.size, radius))
        rgba.save(OUT / f"{name}.png", optimize=True)
        print(f"{name}: {piece.width}x{piece.height}")


if __name__ == "__main__":
    main()
