#!/usr/bin/env python3
"""Copies approved pictures from a generated art drop into godot/art under the D-029 names, cleaning
the cut-outs on the way. The drop (drop_01 .. drop_03, drop_06 .. drop_10) is recognised from the paths inside the zip.

The drop_01 PNGs were cut out of one generated sheet on a light background (SHEET_BG). That left two
defects that show on the game's darker grass and water:
  * soft edge pixels still carry the sheet's colour, a pale halo around every picture;
  * light areas touching the background (white petals, a belly highlight) were keyed out as
    pinholes.
`clean` fills small transparent pockets that do not reach the border, un-mixes the sheet colour from
semi-transparent pixels and tightens the soft alpha band.

drop_02 (animation poses) and drop_03 (equipment and camp items) deliver large sheets with several
pictures each, whose cut-out is already clean: the edges carry the picture's own colour, but the body is
~1 % see-through and stray specks from the key sit between the pictures. The pictures do not sit in
an even grid (they cross the cell lines), so `pieces` finds them as the large visible parts of the sheet
in reading order (`rows` rows, left to right) and gives each the small parts inside its box (a fishing
line, a sparkle); the remaining specks are dropped. `finish` makes a chosen picture opaque, crops, turns
and scales it down to the size the game draws (premultiplied, so the transparent pixels' colour cannot
bleed into the edge). Several pictures of one sheet can be the animation frames of one picture
(`name.png`, `name_f2.png`, ...): they are cropped to one shared canvas, lined up on ALIGN (a fish's
head, a frog's feet, an insect's middle) and scaled alike, so the picture does not jump between frames.
A fish's tail frames are drawn with the whole body turned; `level_head` turns each back so its head lies
over the straight picture's head (only the tail moves) before they are lined up.

drop_06's own PNGs are the pictures of its reference sheet cut out with fixed boxes and enlarged ~6x: they
carry the sheet's drawn checkerboard, parts of the neighbouring pictures and their file-name labels. So
the pictures are cut again from the sheet (CUTS_06): `key_checker` takes away the grey checkerboard (and
the soft shadow on it) reached from the box's edge and un-mixes the grey from the outline, `keep_picture`
drops what the box caught of a panel line or a label. They stay at the sheet's size (100..200 px), which
covers the size the game draws them. Its foreground was painted separately at full size and is copied, like drop_08's two region scenes.

Only pictures listed in DROP_01 / SHEETS / CUTS_06 / COPIES are imported; the rest of the drop is waiting for a decision
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


# Sheet drops: drop -> {sheet: (rows, pictures on the sheet, [godot/art path or None per picture in reading order])}.
# A path may be (path, degrees to turn clockwise). Item ids are the content ids (rods.json, baits.json,
# equipment.json); the sheet's own item names are in the drop's docs/drop_03_item_mapping.json.
SHEETS = {
    "drop_02": {
        # Head up, seen from straight above: tail bent one way, straight, bent the other. Turned to head right.
        "fish/region_01/fish_common_carp_top_anim_sheet_alt.png": (1, 3, [
            ("fish/fish_common_carp_top_f2.png", 90), ("fish/fish_common_carp_top.png", 90), ("fish/fish_common_carp_top_f3.png", 90)]),
        # The cat's four poses are different sleeping positions, not one breathing cycle: one is used.
        "animals/region_01/animal_cat_sleeping_01_anim_sheet.png": (2, 4, ["props/cat.png", None, None, None]),
        # eyes open, blinking / looking up, croaking
        "animals/region_01/animal_frog_01_anim_sheet.png": (2, 4, ["props/frog.png", "props/frog_f2.png", "props/frog_f3.png", "props/frog_f4.png"]),
        # sitting, eyes closed / beak open, wings up: in flight it beats wings up, wings down
        "animals/region_01/animal_bird_blue_01_anim_sheet.png": (2, 4, ["animals/bird_f2.png", None, None, "animals/bird.png"]),
        # wings raised, wings level / two more of the same
        "animals/region_01/animal_dragonfly_01_anim_sheet.png": (2, 4, ["animals/dragonfly.png", "animals/dragonfly_f2.png", None, None]),
        # open from above, half-closed / closed, blurred: open and closed make the beat
        "animals/region_01/animal_butterfly_01_anim_sheet.png": (2, 4, ["animals/butterfly.png", None, "animals/butterfly_f2.png", None]),
        # facing left, from behind / facing right, wings up and down
        "animals/region_01/animal_firefly_01_anim_sheet.png": (2, 4, [None, None, "animals/firefly.png", "animals/firefly_f2.png"]),
    },
    "drop_03": {
        # forest_rest, river_breeze, moonlight_flow, spring_promise / misty_dawn, mossy_creek, sunset_reed,
        # clearwater_travel / deepwater_longline, seaside_driftwood, starlight_glassfloat, old_memory.
        # forest_rest, river_breeze, moonlight_flow and spring_promise carry the game's own names; the
        # rest go by theme.
        "equipment/rods/rod_collection_sheet_12.png": (3, 12, [f"items/rod_{rod}.png" for rod in [
            "bamboo", "light", "moonwood", "old_master", "pier", "stream", "river", "long",
            "deepwater", "coastal", "reef", "heavy"]]),
        # worm, shrimp, dough_ball, grasshopper / corn, bread_cube, beetle, small_fish
        "equipment/baits/bait_collection_sheet_a_8.png": (2, 8, [f"items/bait_{b}.png" if b else None for b in [
            "worm", "shrimp", "bread", "insect", "corn", None, None, "small_fish"]]),
        # shellfish, glowing_moth, berry_paste, rice_cake / silkworm_pupa, crayfish, pellet_ball, moon_drop
        "equipment/baits/bait_collection_sheet_b_8.png": (2, 8, [f"items/bait_{b}.png" if b else None for b in [
            "shellfish", "moon_moth", "berry", None, "larva", None, "old_recipe", None]]),
        "equipment/bags/bag_collection_sheet_4.png": (2, 4, [f"items/bag_{b}.png" for b in ["basic", "leather", "sea", "camping"]]),
        # straw_hat, fishing_vest, gloves / rubber_boots, towel, thermos: the game's accessories are hats
        "equipment/accessories/accessory_collection_sheet_6.png": (2, 6, ["items/acc_straw_hat.png", None, None, None, None, None]),
        # Camp items are props: drawn in the world and on the camp screen's cards.
        # camping_chair, wood_table, camp_lantern / wildflower_pot, birdhouse, camping_tent
        "camp/props/camp_prop_collection_sheet_a_6.png": (2, 6, [f"props/{k}.png" for k in [
            "camp_chair", "wood_table", "lantern", "flower_pot", "birdhouse", "tent"]]),
        # campfire, signpost, picnic_basket / tree_stump_stool, flower_crate, wash_basin_station
        "camp/props/camp_prop_collection_sheet_b_6.png": (2, 6, ["props/campfire.png", "props/signboard.png", None, None, None, None]),
    },
}
# drop_06: box (left, top, right, bottom) on its reference sheet -> (godot/art path, degrees to turn clockwise).
# The top-view fish lie head down; the side view is mirrored to head left. Not cut: the tent (drop_03's is
# larger and matches the other camp props), the angler (faces the viewer, the mockup's sits with its back to
# us looking at the water), the scenes (enlarged from a 330 px picture), the UI frames (see the README).
REFERENCE_06 = "source_masters/corrected_core_reference_sheet.png"
CUTS_06 = {
    (22, 382, 140, 549): ("fish/fish_crucian_carp_top.png", -90),
    (175, 382, 256, 549): ("fish/fish_minnow_top.png", -90),
    (288, 382, 425, 549): ("fish/fish_catfish_top.png", -90),
    (451, 382, 534, 549): ("fish/fish_loach_top.png", -90),
    (584, 382, 692, 549): ("fish/fish_gudgeon_top.png", -90),
    (733, 392, 848, 538): ("fish/fish_bitterling_top.png", -90),
    (884, 382, 997, 549): ("fish/fish_bluegill_top.png", -90),
    (1048, 372, 1161, 549): ("fish/fish_largemouth_bass_top.png", -90),
    (1208, 372, 1299, 549): ("fish/fish_snakehead_top.png", -90),
    (1323, 395, 1529, 508): ("fish/fish_gudgeon_side.png", "mirror"),
    (11, 621, 144, 742): ("props/crate.png", 0),
    (137, 630, 279, 741): ("props/bench.png", 0),
    (480, 636, 589, 741): ("props/junk.png", 0),
    (582, 627, 697, 741): ("props/stump.png", 0),
    (692, 627, 792, 740): ("props/flower_03.png", 0),
    (795, 663, 912, 772): ("items/acc_bucket_hat.png", 0),
    (905, 663, 1020, 772): ("items/acc_river_cap.png", 0),
    (1018, 663, 1145, 772): ("items/acc_starry_hat.png", 0),
    (20, 764, 147, 852): ("items/bait_cricket.png", 0),
    (158, 773, 303, 841): ("items/bait_minnow.png", 0),
    (316, 749, 459, 850): ("items/bait_crab.png", 0),
    (473, 761, 611, 851): ("items/bait_squid.png", 0),
    (620, 756, 777, 855): ("items/bait_seaweed.png", 0),
}
# Pictures taken as they are (full-size, already clean): drop -> {drop path: godot/art path}. A folder in
# LONGEST is scaled down to it; the others (the foreground) keep their size.
COPIES = {
    "drop_06": {"source_masters/r01_foreground_hires_source.png": "world/r01_foreground.png"},
    # The only moment drawn as its own scene; the other ten are the mockup cropped with stickers on it.
    "drop_07": {"moments/moment_rainbow.png": "moments/moment_rainbow.png"},
    # Region 01's scene painted from scratch at 1024x1536, restored and barren in the same framing.
    "drop_08": {"world/region_01/r01_scene.png": "world/r01_scene.png",
                "world/region_01/r01_scene_barren.png": "world/r01_scene_barren.png"},
    # The tent of drop_03 again, with its guy ropes and stakes inside the picture.
    "drop_09": {"props/camp/tent.png": "props/tent.png"},
}
# drop_09's angler poses were painted one by one: the chair is not at the same place nor quite the same size
# in each. The chair is the part that must not move when the pose changes, so every pose is scaled and moved
# to put its chair's three leg caps (left, front, right; found as the dark blobs at the bottom) on idle's.
ANGLER_09 = "characters/angler/angler_%s.png"
FEET_09 = {
    "idle": ((336, 1023), (628, 1133), (870, 1056)),
    "bite": ((290, 977), (577, 1128), (825, 1024)),
    "reel": ((331, 1032), (625, 1131), (842, 1016)),
    "cast": ((325, 1063), (601, 1177), (826, 1081)),
    "hold": ((330, 1022), (649, 1153), (883, 1069)),
}
ANGLER_MARGIN = 120  # px of room around the 1254 canvas for the moved and enlarged poses
# drop_10's UI frames are one picture per file, each on a large canvas with a faint (alpha < 8) shadow spread to
# its edges; a 9-slice stretches any margin left around the frame, so each is cut to its visible part.
# The journal binding is drawn with three rings; the game repeats one ring down the page, so one ring
# interval (between the midpoints of rings 1-2 and 2-3) is cut from it.
UI_10 = ["ui_wood_cta", "ui_wood_sign", "ui_wood_panel", "ui_paper_card", "ui_cream_button", "ui_cream_tab",
         "ui_green_tab", "ui_dark_pill", "ui_round_dark", "ui_reel_button", "ui_tension_bar",
         "ui_leaf_corner_01", "ui_leaf_corner_02", "ui_leaf_corner_03", "ui_leaf_corner_04", "ui_notebook_binding"]
BINDING_10 = (313, 595, 636, 1027)  # x0, y0, x1, y1: the middle ring and its strip
UI_VISIBLE = 8  # alpha above this is the frame, below it the shadow haze
CHECKER_SAT, CHECKER_LOW = 18, 150  # the checkerboard and the shadow on it: channels within 18, brightness 150+
CHECKER_GREY = 238  # its average
RIM_SPREAD = 80  # an outline pixel this far from the grey (largest channel) is fully the picture's
KEEP_SHARE = 0.02  # a part of a cut at least this share of its largest part belongs to the picture

LONGEST = {"fish": 256, "props": 256, "items": 256, "animals": 128, "moments": 512, "character": 400, "ui": 640}  # px, the longest side written per folder
# How the frames of an animated picture line up on their shared canvas (x, y as 0 left/top .. 1 right/bottom).
ALIGN = {"fish": (1.0, 0.5), "props": (0.5, 1.0), "animals": (0.5, 0.5)}
LONGEST_FOR = {"props/frog.png": 192, "props/tent.png": 384,  # the tent is drawn 210 design px wide
               "ui/ui_notebook_binding.png": 192, **{f"ui/ui_leaf_corner_0{i}.png": 256 for i in range(1, 5)}}
OPAQUE_FROM = 235  # the sheets' body alpha is ~253; this and above becomes 255
ITEM_SHARE = 0.25  # a part at least this share of the sheet's largest picture is a picture of its own
SPECK_SHARE = 0.01  # a smaller part inside a picture's box below this share of it is key debris
PAD = 4  # px of transparent margin kept around the cropped picture


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


def pieces(sheet: Image.Image, rows: int) -> list[Image.Image]:
    """The sheet's pictures in reading order, each on its own sheet-sized canvas without the others."""
    sheet = sheet.convert("RGBA")
    px = sheet.load()
    parts = _parts(px, sheet.width, sheet.height)
    if not parts:
        raise ValueError("empty sheet")
    biggest = max(len(part) for part in parts)
    items = [part for part in parts if len(part) >= biggest * ITEM_SHARE]
    boxes = []
    for part in items:
        xs, ys = [x for x, _ in part], [y for _, y in part]
        boxes.append((min(xs) - PAD, min(ys) - PAD, max(xs) + PAD, max(ys) + PAD))
    members = [list(part) for part in items]
    for part in parts:
        if len(part) >= biggest * ITEM_SHARE:
            continue
        cx, cy = sum(x for x, _ in part) / len(part), sum(y for _, y in part) / len(part)
        for i, (left, top, right, bottom) in enumerate(boxes):
            if left <= cx <= right and top <= cy <= bottom and len(part) >= len(items[i]) * SPECK_SHARE:
                members[i] += part
                break

    def reading(i: int) -> tuple[int, float]:
        left, top, right, bottom = boxes[i]
        return int((top + bottom) / 2 * rows / sheet.height), (left + right) / 2

    result = []
    for i in sorted(range(len(items)), key=reading):
        image = Image.new("RGBA", sheet.size)
        out = image.load()
        for x, y in members[i]:
            out[x, y] = px[x, y]
        result.append(image)
    return result


def _checker(pixel: tuple[int, ...]) -> bool:
    r, g, b = pixel[:3]
    return max(r, g, b) - min(r, g, b) <= CHECKER_SAT and r + g + b >= 3 * CHECKER_LOW


def key_checker(image: Image.Image) -> Image.Image:
    """`image` without the checkerboard reached from its edge; the outline next to it un-mixed from the grey."""
    image = image.convert("RGBA")
    px = image.load()
    w, h = image.size
    gone = [[False] * w for _ in range(h)]
    queue = deque((x, y) for x in range(w) for y in range(h) if (x in (0, w - 1) or y in (0, h - 1)) and _checker(px[x, y]))
    for x, y in queue:
        gone[y][x] = True
    while queue:
        x, y = queue.popleft()
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h and not gone[ny][nx] and _checker(px[nx, ny]):
                gone[ny][nx] = True
                queue.append((nx, ny))
    for y in range(h):
        for x in range(w):
            if gone[y][x]:
                px[x, y] = (0, 0, 0, 0)
                continue
            if not any(gone[ny][nx] for nx in (x - 1, x, x + 1) for ny in (y - 1, y, y + 1) if 0 <= nx < w and 0 <= ny < h):
                continue
            r, g, b, _ = px[x, y]
            alpha = min(1.0, max(abs(v - CHECKER_GREY) for v in (r, g, b)) / RIM_SPREAD)
            if alpha < 0.1:
                px[x, y] = (0, 0, 0, 0)
            elif alpha < 1:
                colour = [min(255, max(0, round((v - (1 - alpha) * CHECKER_GREY) / alpha))) for v in (r, g, b)]
                px[x, y] = (*colour, round(255 * alpha))
    return image


def keep_picture(image: Image.Image) -> Image.Image:
    """Only the parts of a cut that belong to its picture: large enough and not touching the box's edge."""
    px = image.load()
    w, h = image.size
    parts = _parts(px, w, h)
    biggest = max(len(part) for part in parts)
    result = Image.new("RGBA", image.size)
    out = result.load()
    for part in parts:
        if len(part) < biggest * KEEP_SHARE or any(x in (0, w - 1) or y in (0, h - 1) for x, y in part):
            continue
        for x, y in part:
            out[x, y] = px[x, y]
    if result.getbbox() is None:
        raise ValueError("every part touches the box's edge: widen the box")
    return result


def prepare(image: Image.Image, turn: int) -> Image.Image:
    """Opaque body, no key debris alpha, cropped to the picture plus PAD, turned."""
    px = image.load()
    for y in range(image.height):
        for x in range(image.width):
            r, g, b, a = px[x, y]
            if a >= OPAQUE_FROM:
                px[x, y] = (r, g, b, 255)
            elif a <= 16:
                px[x, y] = (0, 0, 0, 0)
    left, top, right, bottom = image.getbbox()
    image = image.crop((max(0, left - PAD), max(0, top - PAD), min(image.width, right + PAD), min(image.height, bottom + PAD)))
    return image.rotate(-turn, expand=True) if turn else image


def shrink(image: Image.Image, scale: float) -> Image.Image:
    if scale >= 1:
        return image
    size = (max(1, round(image.width * scale)), max(1, round(image.height * scale)))
    return image.convert("RGBa").resize(size, Image.LANCZOS).convert("RGBA")


def animation_base(path: str) -> str:
    """`props/frog_f3.png` -> `props/frog.png`; a still picture is its own base."""
    return re.sub(r"_f\d+\.png$", ".png", path)


HEAD_SHARE = 0.4  # the front share of a fish (head right) that stays rigid while the tail beats


def _head(image: Image.Image, length: int) -> tuple[list[tuple[int, int]], float, float]:
    """The opaque pixels of the front `length` px of a head-right picture, and their centre."""
    px = image.load()
    left = max(0, image.width - length)
    points = [(x, y) for y in range(image.height) for x in range(left, image.width) if px[x, y][3] > 128]
    cx = sum(x for x, _ in points) / len(points)
    cy = sum(y for _, y in points) / len(points)
    return points, cx, cy


def level_head(straight: Image.Image, bent: Image.Image) -> tuple[Image.Image, float, float]:
    """`bent` turned so its head best covers the straight picture's head; returns it with its head centre."""
    length = round(straight.width * HEAD_SHARE)
    target, tx, ty = _head(straight, length)
    wanted = {(round(x - tx), round(y - ty)) for x, y in target}
    best = (-1.0, bent, 0.0, 0.0)
    for degrees in range(-45, 46, 3):
        turned = bent.rotate(degrees, resample=Image.BICUBIC, expand=True)
        turned = turned.crop(turned.getbbox())
        points, cx, cy = _head(turned, length)
        got = {(round(x - cx), round(y - cy)) for x, y in points}
        overlap = len(wanted & got) / len(wanted | got)
        if overlap > best[0]:
            best = (overlap, turned, cx, cy)
    return best[1], best[2], best[3]


def write_group(images: list[tuple[Image.Image, str]], source: str) -> None:
    """Writes one picture with its frames: one canvas, lined up on ALIGN (fish: on the head), one scale for all."""
    folder = images[0][1].split("/")[0]
    if folder == "fish" and len(images) > 1:
        straight = images[0][0]
        _, hx, hy = _head(straight, round(straight.width * HEAD_SHARE))
        placed = [(straight, images[0][1], -hx, -hy)]
        for image, path in images[1:]:
            turned, cx, cy = level_head(straight, image)
            placed.append((turned, path, -cx, -cy))
    else:
        width = max(image.width for image, _ in images)
        height = max(image.height for image, _ in images)
        ax, ay = ALIGN.get(folder, (0.5, 0.5))  # a still picture has nothing to line up
        placed = [(image, path, (width - image.width) * ax, (height - image.height) * ay) for image, path in images]
    left = min(x for _, _, x, _ in placed)
    top = min(y for _, _, _, y in placed)
    width = round(max(x + image.width for image, _, x, _ in placed) - left)
    height = round(max(y + image.height for image, _, _, y in placed) - top)
    scale = LONGEST_FOR.get(animation_base(images[0][1]), LONGEST[folder]) / max(width, height)
    for image, path, x, y in placed:
        canvas = Image.new("RGBA", (width, height))
        canvas.paste(image, (round(x - left), round(y - top)))
        _write(shrink(canvas, scale), source, path)


def main() -> None:
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    with zipfile.ZipFile(sys.argv[1]) as drop:
        names = {m.group(1) for m in (re.match(r"assets/design/generated/(drop_\d+)/", n) for n in drop.namelist()) if m}
        if names == {"drop_01"}:
            for source, target in DROP_01.items():
                _write(clean(Image.open(BytesIO(drop.read(PREFIX % "drop_01" + source)))), source, target)
        elif len(names) == 1 and next(iter(names)) in SHEETS:
            name = next(iter(names))
            for source, (rows, count, targets) in SHEETS[name].items():
                found = pieces(Image.open(BytesIO(drop.read(PREFIX % name + source))), rows)
                if len(found) != count:
                    sys.exit(f"{source}: expected {count} pictures, found {len(found)}")
                groups: dict[str, list[tuple[Image.Image, str]]] = {}
                for image, target in zip(found, targets):
                    if target is None:
                        continue
                    path, turn = target if isinstance(target, tuple) else (target, 0)
                    groups.setdefault(animation_base(path), []).append((prepare(image, turn), path))
                for base, images in groups.items():
                    images.sort(key=lambda pair: pair[1] != base)  # the picture first, then its frames
                    write_group(images, source)
        elif names == {"drop_06"}:
            sheet = Image.open(BytesIO(drop.read(PREFIX % "drop_06" + REFERENCE_06)))
            for box, (path, turn) in CUTS_06.items():
                image = prepare(keep_picture(key_checker(sheet.crop(box))), 0 if turn == "mirror" else turn)
                if turn == "mirror":
                    image = image.transpose(Image.FLIP_LEFT_RIGHT)
                write_group([(image, path)], f"{REFERENCE_06} {box}")
            copy(drop, "drop_06")
        elif names == {"drop_10"}:
            ui_frames(drop)
        elif names == {"drop_09"}:
            angler_poses(drop)
            copy(drop, "drop_09")
        elif len(names) == 1 and next(iter(names)) in COPIES:
            copy(drop, next(iter(names)))
        else:
            sys.exit(f"not a known drop (found {sorted(names) or 'no drop folder'})")


def fit_feet(feet, reference) -> tuple[float, float, float]:
    """Scale and offset (no turn) that put `feet` on `reference` with the least squared error."""
    mx, my = (sum(p[i] for p in feet) / len(feet) for i in (0, 1))
    rx, ry = (sum(p[i] for p in reference) / len(reference) for i in (0, 1))
    scale = sum((p[0] - mx) * (q[0] - rx) + (p[1] - my) * (q[1] - ry) for p, q in zip(feet, reference))         / sum((p[0] - mx) ** 2 + (p[1] - my) ** 2 for p in feet)
    return scale, rx - scale * mx, ry - scale * my


def angler_poses(drop: zipfile.ZipFile) -> None:
    placed = []
    for pose, feet in FEET_09.items():
        source = ANGLER_09 % pose
        image = Image.open(BytesIO(drop.read(PREFIX % "drop_09" + source))).convert("RGBa")
        scale, dx, dy = fit_feet(feet, FEET_09["idle"])
        size = (image.width + 2 * ANGLER_MARGIN, image.height + 2 * ANGLER_MARGIN)
        # The affine data maps each output pixel back to the source one.
        out = image.transform(size, Image.AFFINE, (1 / scale, 0, -(dx + ANGLER_MARGIN) / scale,
                                                  0, 1 / scale, -(dy + ANGLER_MARGIN) / scale), Image.BICUBIC)
        placed.append((out.convert("RGBA"), f"character/angler_{pose}.png"))
    boxes = [image.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox() for image, _ in placed]
    box = (min(b[0] for b in boxes) - PAD, min(b[1] for b in boxes) - PAD,
           max(b[2] for b in boxes) + PAD, max(b[3] for b in boxes) + PAD)
    write_group([(image.crop(box), path) for image, path in placed], "drop_09 " + ANGLER_09 % "*")


def ui_frames(drop: zipfile.ZipFile) -> None:
    for name in UI_10:
        source = f"ui/{name}.png"
        image = Image.open(BytesIO(drop.read(PREFIX % "drop_10" + source))).convert("RGBA")
        if name == "ui_notebook_binding":
            image = image.crop(BINDING_10)
        image = image.crop(image.getchannel("A").point(lambda a: 255 if a > UI_VISIBLE else 0).getbbox())
        target = f"ui/{name}.png"
        longest = LONGEST_FOR.get(target, LONGEST["ui"])
        _write(shrink(image, longest / max(image.size)), source, target)


def copy(drop: zipfile.ZipFile, name: str) -> None:
    for source, target in COPIES[name].items():
        image = Image.open(BytesIO(drop.read(PREFIX % name + source))).convert("RGBA")
        longest = LONGEST_FOR.get(target, LONGEST.get(target.split("/")[0]))
        _write(shrink(image, longest / max(image.size)) if longest else image, source, target)


def _write(image: Image.Image, source: str, target: str) -> None:
    out = ART / target
    out.parent.mkdir(parents=True, exist_ok=True)
    image.save(out, optimize=True)
    print(f"{source} -> godot/art/{target} {image.width}x{image.height}")


if __name__ == "__main__":
    main()
