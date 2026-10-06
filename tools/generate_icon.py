#!/usr/bin/env python3
"""Draws the Ripple Garden icon: a still pond with rippling rings, a small fish and a lily pad.

Writes the same drawing in three forms from one set of shapes:
  godot/icon.svg                        the project icon (vector)
  assets/branding/ripple_garden_512.png preview / store art placeholder
  assets/branding/ripple_garden.ico     Windows icon (16..256 px) used by shortcuts
  godot/branding/splash.png             boot splash image

    python tools/generate_icon.py

Pillow and numpy are only needed to regenerate; the outputs are committed.
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SIZE = 128  # drawing coordinates (the SVG viewBox)
TOP = (0x1B, 0x63, 0x73)
BOTTOM = (0x57, 0xBA, 0xA8)

RINGS = [(14, 6, 1.0), (30, 13, 0.7), (46, 20, 0.42)]  # rx, ry, opacity around (64, 76)
FISH_BODY = (64, 70, 22, 10)  # cx, cy, rx, ry
FISH_TAIL = [(42, 70), (27, 59), (27, 81)]
FISH_EYE = (74, 67, 2.6)
PAD = (96, 101, 15, 6.5)
FLOWER = (99, 97, 4.2)


def svg() -> str:
    rings = "\n".join(
        f'  <ellipse cx="64" cy="76" rx="{rx}" ry="{ry}" fill="none" stroke="#ffffff" stroke-opacity="{op}" stroke-width="3"/>'
        for rx, ry, op in RINGS)
    tail = " ".join(f"{x},{y}" for x, y in FISH_TAIL)
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">
  <defs>
    <linearGradient id="water" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#{TOP[0]:02x}{TOP[1]:02x}{TOP[2]:02x}"/>
      <stop offset="1" stop-color="#{BOTTOM[0]:02x}{BOTTOM[1]:02x}{BOTTOM[2]:02x}"/>
    </linearGradient>
  </defs>
  <rect width="128" height="128" rx="28" fill="url(#water)"/>
{rings}
  <polygon points="{tail}" fill="#ffd36b"/>
  <ellipse cx="{FISH_BODY[0]}" cy="{FISH_BODY[1]}" rx="{FISH_BODY[2]}" ry="{FISH_BODY[3]}" fill="#ffe9a8"/>
  <circle cx="{FISH_EYE[0]}" cy="{FISH_EYE[1]}" r="{FISH_EYE[2]}" fill="#2a2110"/>
  <ellipse cx="{PAD[0]}" cy="{PAD[1]}" rx="{PAD[2]}" ry="{PAD[3]}" fill="#4f9a5a"/>
  <circle cx="{FLOWER[0]}" cy="{FLOWER[1]}" r="{FLOWER[2]}" fill="#f08fb0"/>
</svg>
'''


def render(pixels: int = 1024) -> Image.Image:
    """Same shapes as the SVG, drawn at high resolution and later scaled down for smooth edges."""
    scale = pixels / SIZE
    gradient = np.zeros((pixels, pixels, 4), dtype=np.uint8)
    for channel in range(3):
        column = np.linspace(TOP[channel], BOTTOM[channel], pixels)
        gradient[:, :, channel] = column[:, None].astype(np.uint8)
    gradient[:, :, 3] = 255
    image = Image.fromarray(gradient, "RGBA")

    mask = Image.new("L", (pixels, pixels), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, pixels - 1, pixels - 1), radius=28 * scale, fill=255)
    canvas = Image.new("RGBA", (pixels, pixels), (0, 0, 0, 0))
    canvas.paste(image, (0, 0), mask)

    for rx, ry, opacity in RINGS:
        layer = Image.new("RGBA", (pixels, pixels), (0, 0, 0, 0))
        ImageDraw.Draw(layer).ellipse(
            ((64 - rx) * scale, (76 - ry) * scale, (64 + rx) * scale, (76 + ry) * scale),
            outline=(255, 255, 255, int(255 * opacity)), width=int(3 * scale))
        canvas = Image.alpha_composite(canvas, layer)

    draw = ImageDraw.Draw(canvas)
    draw.polygon([(x * scale, y * scale) for x, y in FISH_TAIL], fill=(0xFF, 0xD3, 0x6B, 255))
    cx, cy, rx, ry = FISH_BODY
    draw.ellipse(((cx - rx) * scale, (cy - ry) * scale, (cx + rx) * scale, (cy + ry) * scale), fill=(0xFF, 0xE9, 0xA8, 255))
    ex, ey, er = FISH_EYE
    draw.ellipse(((ex - er) * scale, (ey - er) * scale, (ex + er) * scale, (ey + er) * scale), fill=(0x2A, 0x21, 0x10, 255))
    px, py, prx, pry = PAD
    draw.ellipse(((px - prx) * scale, (py - pry) * scale, (px + prx) * scale, (py + pry) * scale), fill=(0x4F, 0x9A, 0x5A, 255))
    fx, fy, fr = FLOWER
    draw.ellipse(((fx - fr) * scale, (fy - fr) * scale, (fx + fr) * scale, (fy + fr) * scale), fill=(0xF0, 0x8F, 0xB0, 255))
    return canvas


def main() -> None:
    (ROOT / "godot" / "icon.svg").write_text(svg(), encoding="utf-8", newline="\n")
    branding = ROOT / "assets" / "branding"
    branding.mkdir(parents=True, exist_ok=True)
    master = render(1024)
    master.resize((512, 512), Image.LANCZOS).save(branding / "ripple_garden_512.png")
    splash = ROOT / "godot" / "branding"
    splash.mkdir(parents=True, exist_ok=True)
    master.resize((384, 384), Image.LANCZOS).save(splash / "splash.png")
    sizes = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
    master.resize((256, 256), Image.LANCZOS).save(branding / "ripple_garden.ico", sizes=sizes)
    print("wrote godot/icon.svg, godot/branding/splash.png, assets/branding/ripple_garden_512.png, assets/branding/ripple_garden.ico")


if __name__ == "__main__":
    main()
