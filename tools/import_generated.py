#!/usr/bin/env python3
"""Puts redrawn pictures (made with `codex exec`, see assets/placeholders/README.md) into godot/art.

Files are named `<folder>_<name>.png`: `props_cat_f2.png`, `items_bait_crab.png`, `moments_moment_rainbow.png`,
and for the fish folder the fish's own name, `fish_largemouth_bass_top.png` -> `fish/fish_largemouth_bass_top.png`. Each is cut to its visible part (alpha above CUT, below
that is a faint haze), given a PAD px transparent margin and scaled down to the longest side its folder uses (the same sizes as tools/import_art_drop.py),
premultiplied so the transparent pixels' colour cannot bleed into the edge. Opaque scenes (moments) are
only scaled. Animation frames of one picture (`name.png`, `name_f2.png`, ...) share one canvas, lined up on
their bottom centre and scaled alike, so the picture does not jump between frames.

    python tools/import_generated.py DIR
"""
import re
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "godot" / "art"
CUT = 8  # alpha above this is the picture
PAD = 4  # px of transparent margin kept around a cut-out: an outline touching the texture edge looks clipped once filtered
LONGEST = {"fish": 256, "props": 256, "items": 256, "moments": 512}
CATEGORIES = tuple(LONGEST)


def visible(image: Image.Image) -> Image.Image:
    box = image.getchannel("A").point(lambda a: 255 if a > CUT else 0).getbbox()
    return image.crop(box)


def shrink(image: Image.Image, longest: int) -> Image.Image:
    scale = longest / max(image.size)
    if scale >= 1:
        return image
    size = (max(1, round(image.width * scale)), max(1, round(image.height * scale)))
    return image.convert("RGBa").resize(size, Image.LANCZOS).convert("RGBA")


def frame_base(name: str) -> str:
    return re.sub(r"_f\d+$", "", name)


def main() -> None:
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    groups: dict[tuple[str, str], list[tuple[str, Image.Image]]] = {}
    for path in sorted(Path(sys.argv[1]).glob("*.png")):
        category, _, name = path.stem.partition("_")
        if category == "fish":
            name = path.stem  # the fish's own file name starts with "fish_"
        if category not in CATEGORIES:
            print(f"skipped {path.name}: unknown category")
            continue
        image = Image.open(path).convert("RGBA")
        if category != "moments":
            image = visible(image)
        groups.setdefault((category, frame_base(name)), []).append((name, image))
    for (category, base), frames in sorted(groups.items()):
        # One canvas for all frames of a picture, bottom centre lined up and one scale.
        width = max(image.width for _, image in frames)
        height = max(image.height for _, image in frames)
        margin = 0 if category == "moments" else PAD  # a scene fills its picture
        for name, image in frames:
            canvas = Image.new("RGBA", (width, height))
            canvas.paste(image, ((width - image.width) // 2, height - image.height))
            picture = shrink(canvas, LONGEST[category] - 2 * margin)
            if margin:
                padded = Image.new("RGBA", (picture.width + 2 * margin, picture.height + 2 * margin))
                padded.paste(picture, (margin, margin))
                picture = padded
            out = ART / category / f"{name}.png"
            out.parent.mkdir(parents=True, exist_ok=True)
            picture.save(out, optimize=True)
            print(f"{category}/{name}.png -> {picture.width}x{picture.height}")


if __name__ == "__main__":
    main()
