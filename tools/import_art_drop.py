#!/usr/bin/env python3
"""Copies approved pictures from a generated art drop into godot/art under the D-029 names, cleaning
the cut-outs on the way.

The drop_01 PNGs were cut out of one generated sheet on a light background (SHEET_BG). That left two
defects that show on the game's darker grass and water:
  * soft edge pixels still carry the sheet's colour, a pale halo around every picture;
  * light areas touching the background (white petals, a belly highlight) were keyed out as
    pinholes.
`clean` fills small transparent pockets that do not reach the border, un-mixes the sheet colour from
semi-transparent pixels and tightens the soft alpha band.

Only pictures listed in DROP_01 are imported; the rest of the drop is waiting for a decision
(assets/placeholders/README.md lists what was taken and why the others were not).

    python tools/import_art_drop.py path/to/ripple_garden_asset_drop_01.zip

Afterwards let Godot import the new files (`godot --headless --path godot --import`).
"""
import sys
import zipfile
from collections import deque
from io import BytesIO
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "godot" / "art"
PREFIX = "assets/design/generated/drop_01/"

SHEET_BG = (244, 245, 239)
ALPHA_LOW, ALPHA_HIGH = 0.45, 0.92  # soft alpha below LOW goes, above HIGH becomes opaque
MAX_PINHOLE = 40  # px: a larger enclosed gap is part of the drawing (between stems, inside the tyre)

# Drop path (under PREFIX) -> godot/art path. Fish ids are the catalog ids.
DROP_01 = {
    **{f"fish/region_01/fish_{name}_side.png": f"fish/fish_{name}_side.png" for name in [
        "crucian_carp", "common_carp", "minnow", "catfish", "loach", "bitterling", "bluegill",
        "largemouth_bass", "snakehead",
    ]},  # gudgeon: its tail is cut off at the picture's edge
    "props/region_01/prop_lily_pad_01.png": "props/lily_pad.png",
    "props/region_01/prop_water_lily_01.png": "props/lily_pad_02.png",
    "props/region_01/prop_reed_01.png": "props/reed.png",
    "props/region_01/prop_cattail_01.png": "props/reed_02.png",
    "props/region_01/prop_flower_white_01.png": "props/flower.png",
    "props/region_01/prop_flower_pink_01.png": "props/flower_02.png",
    "props/region_01/prop_grass_tuft_01.png": "props/grass_tuft.png",
    "props/region_01/prop_bush_01.png": "props/bush.png",
}


def _fill_pinholes(px, w: int, h: int) -> None:
    clear = lambda x, y: px[x, y][3] < 128
    seen = [[False] * w for _ in range(h)]
    for sy in range(h):
        for sx in range(w):
            if seen[sy][sx] or not clear(sx, sy):
                continue
            pocket, reaches_border, queue = [], False, deque([(sx, sy)])
            seen[sy][sx] = True
            while queue:
                x, y = queue.popleft()
                pocket.append((x, y))
                reaches_border |= x in (0, w - 1) or y in (0, h - 1)
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if 0 <= nx < w and 0 <= ny < h and not seen[ny][nx] and clear(nx, ny):
                        seen[ny][nx] = True
                        queue.append((nx, ny))
            if reaches_border or len(pocket) > MAX_PINHOLE:
                continue
            # Grow inwards: each pass paints the pocket pixels that touch something already solid.
            left = set(pocket)
            while left:
                painted = {}
                for x, y in left:
                    around = [px[nx, ny] for nx in (x - 1, x, x + 1) for ny in (y - 1, y, y + 1)
                              if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in left]
                    if around:
                        painted[(x, y)] = tuple(sum(c[i] for c in around) // len(around) for i in range(3)) + (255,)
                if not painted:
                    break
                for (x, y), colour in painted.items():
                    px[x, y] = colour
                left -= painted.keys()


def clean(image: Image.Image) -> Image.Image:
    image = image.convert("RGBA")
    px = image.load()
    w, h = image.size
    _fill_pinholes(px, w, h)
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a in (0, 255):
                continue
            alpha = a / 255
            colour = [min(255, max(0, round((v - (1 - alpha) * bg) / alpha))) for v, bg in zip((r, g, b), SHEET_BG)]
            t = min(1.0, max(0.0, (alpha - ALPHA_LOW) / (ALPHA_HIGH - ALPHA_LOW)))
            new_alpha = round(255 * t * t * (3 - 2 * t))
            px[x, y] = (*colour, new_alpha) if new_alpha else (0, 0, 0, 0)
    return image


def main() -> None:
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    with zipfile.ZipFile(sys.argv[1]) as drop:
        for source, target in DROP_01.items():
            out = ART / target
            out.parent.mkdir(parents=True, exist_ok=True)
            clean(Image.open(BytesIO(drop.read(PREFIX + source)))).save(out, optimize=True)
            print(f"{source} -> godot/art/{target}")


if __name__ == "__main__":
    main()
