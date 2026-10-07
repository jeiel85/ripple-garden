#!/usr/bin/env python3
"""Copies approved pictures from a generated art drop into godot/art under the D-029 names, cleaning
the cut-outs on the way. The drop (drop_01, drop_02) is recognised from the paths inside the zip.

The drop_01 PNGs were cut out of one generated sheet on a light background (SHEET_BG). That left two
defects that show on the game's darker grass and water:
  * soft edge pixels still carry the sheet's colour, a pale halo around every picture;
  * light areas touching the background (white petals, a belly highlight) were keyed out as
    pinholes.
`clean` fills small transparent pockets that do not reach the border, un-mixes the sheet colour from
semi-transparent pixels and tightens the soft alpha band.

drop_02 delivers large animation sheets (a grid of poses per file) whose cut-out is already clean: the
edges carry the picture's own colour, but the body is ~1 % see-through and stray specks from the key
sit between the poses. `frame` takes one cell of the grid, keeps the pose (drops the specks), makes the
body opaque, crops, turns and scales it down to the size the game draws (premultiplied, so the
transparent pixels' colour cannot bleed into the edge). The game has no sprite animation yet, so one
pose per picture.

Only pictures listed in DROP_01 / DROP_02 are imported; the rest of the drop is waiting for a decision
(assets/placeholders/README.md lists what was taken and why the others were not).

    python tools/import_art_drop.py path/to/ripple_garden_asset_drop_0N.zip

Afterwards let Godot import the new files (`godot --headless --path godot --import`).
"""
import re
import sys
import zipfile
from collections import deque
from io import BytesIO
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "godot" / "art"
PREFIX = "assets/design/generated/%s/"

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


# drop_02 sheet -> (column, row, columns, rows of the grid, degrees to turn clockwise, longest side px, godot/art path)
DROP_02 = {
    # Head up, seen from straight above; the middle pose is the straight one. Turned to head right.
    "fish/region_01/fish_common_carp_top_anim_sheet_alt.png": (1, 0, 3, 1, 90, 256, "fish/fish_common_carp_top.png"),
    "animals/region_01/animal_cat_sleeping_01_anim_sheet.png": (0, 0, 2, 2, 0, 256, "props/cat.png"),
    "animals/region_01/animal_frog_01_anim_sheet.png": (0, 0, 2, 2, 0, 192, "props/frog.png"),
}
OPAQUE_FROM = 235  # the sheets' body alpha is ~253; this and above becomes 255
SPECK_SHARE = 0.01  # a part smaller than this share of the pose is key debris
PAD = 4  # px of transparent margin kept around the cropped pose


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


def _parts(px, w: int, h: int) -> list[list[tuple[int, int]]]:
    """The 8-connected visible parts of the picture."""
    seen = [[False] * w for _ in range(h)]
    parts = []
    for sy in range(h):
        for sx in range(w):
            if seen[sy][sx] or px[sx, sy][3] <= 16:
                continue
            part, queue = [], deque([(sx, sy)])
            seen[sy][sx] = True
            while queue:
                x, y = queue.popleft()
                part.append((x, y))
                for nx in (x - 1, x, x + 1):
                    for ny in (y - 1, y, y + 1):
                        if 0 <= nx < w and 0 <= ny < h and not seen[ny][nx] and px[nx, ny][3] > 16:
                            seen[ny][nx] = True
                            queue.append((nx, ny))
            parts.append(part)
    return parts


def frame(sheet: Image.Image, column: int, row: int, columns: int, rows: int, turn: int, longest: int) -> Image.Image:
    sheet = sheet.convert("RGBA")
    cw, ch = sheet.width // columns, sheet.height // rows
    image = sheet.crop((column * cw, row * ch, (column + 1) * cw, (row + 1) * ch))
    px = image.load()
    parts = _parts(px, image.width, image.height)
    if not parts:
        raise ValueError("empty cell")
    biggest = max(len(part) for part in parts)
    for part in parts:
        if len(part) < biggest * SPECK_SHARE:
            for x, y in part:
                px[x, y] = (0, 0, 0, 0)
    for y in range(image.height):
        for x in range(image.width):
            r, g, b, a = px[x, y]
            if a >= OPAQUE_FROM:
                px[x, y] = (r, g, b, 255)
            elif a <= 16:
                px[x, y] = (0, 0, 0, 0)
    left, top, right, bottom = image.getbbox()
    image = image.crop((max(0, left - PAD), max(0, top - PAD), min(image.width, right + PAD), min(image.height, bottom + PAD)))
    if turn:
        image = image.rotate(-turn, expand=True)
    scale = longest / max(image.size)
    if scale < 1:
        size = (max(1, round(image.width * scale)), max(1, round(image.height * scale)))
        image = image.convert("RGBa").resize(size, Image.LANCZOS).convert("RGBA")
    return image


def main() -> None:
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    with zipfile.ZipFile(sys.argv[1]) as drop:
        names = {m.group(1) for m in (re.match(r"assets/design/generated/(drop_\d+)/", n) for n in drop.namelist()) if m}
        if names == {"drop_01"}:
            for source, target in DROP_01.items():
                _write(clean(Image.open(BytesIO(drop.read(PREFIX % "drop_01" + source)))), source, target)
        elif names == {"drop_02"}:
            for source, (column, row, columns, rows, turn, longest, target) in DROP_02.items():
                sheet = Image.open(BytesIO(drop.read(PREFIX % "drop_02" + source)))
                _write(frame(sheet, column, row, columns, rows, turn, longest), source, target)
        else:
            sys.exit(f"not a known drop (found {sorted(names) or 'no drop folder'})")


def _write(image: Image.Image, source: str, target: str) -> None:
    out = ART / target
    out.parent.mkdir(parents=True, exist_ok=True)
    image.save(out, optimize=True)
    print(f"{source} -> godot/art/{target} {image.width}x{image.height}")


if __name__ == "__main__":
    main()
