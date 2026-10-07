#!/usr/bin/env python3
"""Cuts the bundled fonts (godot/fonts, D-031) down to the characters the game can show, so a 7 MB CJK
font costs a few hundred KB. The full fonts are not kept in the repository; download them from
github.com/google/fonts (OFL) into one folder and run:

    python tools/subset_fonts.py path/to/folder

Kept in every font: printable ASCII, the punctuation below, and every character of the strings
(godot/data/localization.csv) and of the scripts' string literals. The Korean fonts also keep the 2,350
Hangul syllables of KS X 1001 and the compatibility jamo; the Japanese ones the full hiragana / katakana
and CJK punctuation. A string that later needs a new character (a new kanji) shows in the fallback font
until this is run again — test_fonts.gd fails when that happens.

Needs fontTools and brotli (pip install fonttools brotli).
"""
import csv
import re
import sys
from pathlib import Path

from fontTools import subset
from fontTools.ttLib import TTFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "godot" / "fonts"
CSV = ROOT / "godot" / "data" / "localization.csv"

# source file -> (bundled file, script)
FONTS = {
    "GowunDodum-Regular.ttf": ("GowunDodum-Regular.woff2", "ko"),
    "Jua-Regular.ttf": ("Jua-Regular.woff2", "ko"),
    "MPLUSRounded1c-Regular.ttf": ("MPLUSRounded1c-Regular.woff2", "ja"),
    "MPLUSRounded1c-Bold.ttf": ("MPLUSRounded1c-Bold.woff2", "ja"),
}
PUNCTUATION = "·…–—‘’“”•→←↑↓×÷°℃~「」『』【】〜・！？：；（）％＋－＝／★☆♪"


def text_characters() -> set[str]:
    chars: set[str] = set()
    with open(CSV, encoding="utf-8", newline="") as handle:
        for row in csv.reader(handle):
            for cell in row[1:]:
                chars.update(cell)
    for script in (ROOT / "godot").rglob("*.gd"):
        for literal in re.findall(r'"([^"\n]*)"', script.read_text(encoding="utf-8")):
            chars.update(literal)
    return chars


def script_characters(script: str) -> set[str]:
    if script == "ko":
        hangul = {chr(c) for c in range(0xAC00, 0xD7A4) if _ks_x_1001(chr(c))}
        return hangul | {chr(c) for c in range(0x3131, 0x3164)}
    return {chr(c) for r in ((0x3000, 0x3040), (0x3041, 0x30A0), (0x30A0, 0x3100), (0xFF01, 0xFF5F)) for c in range(*r)}


def _ks_x_1001(char: str) -> bool:
    """One of the 2,350 precomposed syllables of KS X 1001: in CP949 they are the rows B0..C8 with a
    trail byte A1..FE (Python's euc-kr codec also encodes the others, as 8-byte jamo sequences)."""
    code = char.encode("cp949")
    return len(code) == 2 and 0xB0 <= code[0] <= 0xC8 and code[1] >= 0xA1


def main() -> None:
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    source = Path(sys.argv[1])
    base = text_characters() | {chr(c) for c in range(0x20, 0x7F)} | set(PUNCTUATION)
    OUT.mkdir(parents=True, exist_ok=True)
    for name, (target, script) in FONTS.items():
        font = TTFont(source / name)
        cmap = font.getBestCmap()
        wanted = {ord(c) for c in base | script_characters(script) if c.isprintable() or c == " "}
        options = subset.Options()
        options.flavor = "woff2"
        options.layout_features = ["*"]
        options.name_IDs = ["*"]  # keep the copyright and licence records
        options.notdef_outline = True
        subsetter = subset.Subsetter(options)
        subsetter.populate(unicodes=sorted(wanted & set(cmap)))
        subsetter.subset(font)
        font.flavor = "woff2"
        font.save(OUT / target)
        print(f"{name} -> godot/fonts/{target}: {len(wanted & set(cmap))} characters, {(OUT / target).stat().st_size // 1024} KB")


if __name__ == "__main__":
    main()
