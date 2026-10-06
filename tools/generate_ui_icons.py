#!/usr/bin/env python3
"""Draws the UI icon set (single-colour silhouettes in the style of the design mockups).

Every icon is white on transparent; the game tints it (dark brown on cream buttons, cream on the
dark pills). Shapes live on a 48x48 grid and are written at 96x96 px so they stay sharp on
high-density screens. The game looks icons up by file name (godot/ui/ui_icons.gd lists them).

    python tools/generate_ui_icons.py

Placeholder art (DECISIONS D-011/D-018): replace with drawn icons when they arrive
(assets/design/ASSET_REQUESTS.md section 5). No third-party sources are used.
"""
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "godot" / "ui" / "icons"
W = "#ffffff"


def fill(d, rule="nonzero"):
    return f'<path d="{d}" fill="{W}" fill-rule="{rule}"/>'


def stroke(d, width=4.0):
    return (f'<path d="{d}" fill="none" stroke="{W}" stroke-width="{width}" '
            f'stroke-linecap="round" stroke-linejoin="round"/>')


def circle(cx, cy, r):
    return f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{W}"/>'


def ring(cx, cy, r, width=4.0):
    return f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="none" stroke="{W}" stroke-width="{width}"/>'


def hole(cx, cy, r):
    """A circular sub-path; combined with evenodd it cuts a hole."""
    return f"M{cx - r} {cy} a{r} {r} 0 1 0 {2 * r} 0 a{r} {r} 0 1 0 {-2 * r} 0 Z"


def polygon(points):
    return "M" + " L".join(f"{x:.2f} {y:.2f}" for x, y in points) + " Z"


def star_points(cx, cy, outer, inner, count=5, start=-90.0):
    points = []
    for i in range(count * 2):
        radius = outer if i % 2 == 0 else inner
        angle = math.radians(start + i * 180.0 / count)
        points.append((cx + math.cos(angle) * radius, cy + math.sin(angle) * radius))
    return points


def cog():
    points = []
    teeth = 8
    for i in range(teeth * 4):
        angle = math.radians(i * 360.0 / (teeth * 4) - 90.0 + 360.0 / (teeth * 8))
        radius = 21.0 if (i % 4) in (0, 1) else 15.5
        points.append((24 + math.cos(angle) * radius, 24 + math.sin(angle) * radius))
    return fill(polygon(points) + " " + hole(24, 24, 7), "evenodd")


def sun(cx=24, cy=24, scale=1.0):
    parts = [circle(cx, cy, 8.5 * scale)]
    for i in range(8):
        angle = math.radians(i * 45)
        x1, y1 = cx + math.cos(angle) * 13 * scale, cy + math.sin(angle) * 13 * scale
        x2, y2 = cx + math.cos(angle) * 19 * scale, cy + math.sin(angle) * 19 * scale
        parts.append(stroke(f"M{x1:.1f} {y1:.1f} L{x2:.1f} {y2:.1f}", 3.6 * scale))
    return "".join(parts)


def cloud(dx=0.0, dy=0.0, s=1.0):
    def p(x, y):
        return f"{dx + x * s:.1f} {dy + y * s:.1f}"
    d = (f"M{p(10, 36)} C{p(4, 36)} {p(3, 27)} {p(10, 25)} C{p(10, 17)} {p(20, 13)} {p(25, 18)} "
         f"C{p(29, 11)} {p(41, 13)} {p(40, 23)} C{p(47, 24)} {p(46, 36)} {p(39, 36)} Z")
    return fill(d)


FISH = "M5 24 C11 14 25 12 33 18 L43 11 L41 24 L43 37 L33 30 C25 36 11 34 5 24 Z"

ICONS = {
    # navigation
    "fish": fill(FISH + " " + hole(14, 22, 2.4), "evenodd"),
    "journal": fill("M3 11 C10 8 18 9 23 13 L23 41 C18 37 10 36 3 38 Z M25 13 C30 9 38 8 45 11 L45 38 "
                    "C38 36 30 37 25 41 Z M28 25 C31 21 36 21 39 25 C36 29 31 29 28 25 Z M38.5 25 L42 21.5 L42 28.5 Z",
                    "evenodd"),
    "gear": fill("M12 18 C12 12 17 9 24 9 C31 9 36 12 36 18 L39 22 L39 41 C39 43 38 44 36 44 L12 44 C10 44 9 43 9 41 "
                 "L9 22 Z M16 27 L32 27 L32 36 L16 36 Z", "evenodd") + stroke("M19 9 C19 4 29 4 29 9", 3.5),
    "camp": fill("M24 5 L45 41 L3 41 Z M24 22 L31 41 L17 41 Z", "evenodd") + stroke("M24 5 L24 1 M20 3 L24 1", 2.5),
    "settings": cog(),
    "map": fill("M4 10 L16 6 L32 11 L44 7 L44 38 L32 42 L16 37 L4 41 Z M17 10 L17 34 L31 38 L31 14 Z", "evenodd"),
    "back": stroke("M31 7 L14 24 L31 41", 6),
    "forward": stroke("M17 7 L34 24 L17 41", 6),
    "close": stroke("M11 11 L37 37 M37 11 L11 37", 6),
    "check": stroke("M8 25 L19 36 L40 12", 6),
    # status / weather
    "mountain": fill("M1 42 L17 12 L25 26 L31 17 L47 42 Z M17 12 L22 21 L17 19 L12 22 Z", "evenodd"),
    "clear": sun(),
    "cloudy": cloud(0, 2),
    "rain": cloud(0, -6) + stroke("M14 36 L11 44 M24 36 L21 44 M34 36 L31 44", 3.5),
    "mist": stroke("M6 16 L42 16 M10 25 L38 25 M6 34 L42 34", 4.5),
    "storm": cloud(0, -6) + fill("M25 30 L17 41 L24 41 L20 48 L33 35 L26 35 L30 30 Z"),
    "night": fill("M30 5 A19 19 0 1 0 43 33 A15 15 0 1 1 30 5 Z"),
    "weather": sun(17, 17, 0.72) + cloud(4, 8, 0.85),
    "clock": ring(24, 24, 18, 4.5) + stroke("M24 12 L24 25 L32 30", 4),
    "pin": fill("M24 45 C14 32 9 25 9 18 C9 9 16 3 24 3 C32 3 39 9 39 18 C39 25 34 32 24 45 Z " + hole(24, 18, 6), "evenodd"),
    "calendar": fill("M5 10 L43 10 L43 43 L5 43 Z M9 19 L39 19 L39 39 L9 39 Z", "evenodd")
    + fill("M13 23 L19 23 L19 28 L13 28 Z M21 23 L27 23 L27 28 L21 28 Z M29 23 L35 23 L35 28 L29 28 Z "
           "M13 31 L19 31 L19 36 L13 36 Z M21 31 L27 31 L27 36 L21 36 Z")
    + stroke("M14 5 L14 13 M34 5 L34 13", 4),
    "ruler": fill("M3 16 L45 16 L45 32 L3 32 Z M8 16 L10 16 L10 23 L8 23 Z M15 16 L17 16 L17 26 L15 26 Z "
                  "M22 16 L24 16 L24 23 L22 23 Z M29 16 L31 16 L31 26 L29 26 Z M36 16 L38 16 L38 23 L36 23 Z", "evenodd"),
    # currencies and progress
    "ripple": stroke("M24 25 C24 22 28 22 28 25 C28 30 20 31 19 25 C18 18 30 16 33 24 C36 32 26 39 18 36 "
                     "C9 33 8 19 15 13 C22 7 36 8 41 18", 4),
    "memory": fill("M24 27 C14 27 7 20 7 11 C17 11 24 17 24 27 Z M24 27 C24 18 30 12 41 12 C41 21 34 27 24 27 Z")
    + stroke("M24 26 L24 43", 4),
    "sprout": fill("M24 26 C15 26 10 19 10 12 C18 12 24 17 24 26 Z M24 22 C24 14 29 9 38 9 C38 17 32 22 24 22 Z")
    + stroke("M24 22 L24 36", 4) + fill("M7 37 C14 32 34 32 41 37 L41 43 L7 43 Z"),
    "star": fill(polygon(star_points(24, 25, 21, 9))),
    "crown": fill("M5 37 L7 13 L17 23 L24 8 L31 23 L41 13 L43 37 Z M5 40 L43 40 L43 44 L5 44 Z"),
    "lock": stroke("M15 22 L15 15 C15 4 33 4 33 15 L33 22", 5) + fill("M9 21 L39 21 L39 44 L9 44 Z " + hole(24, 31, 3.5), "evenodd"),
    "sort": stroke("M7 12 L41 12 M7 24 L33 24 M7 36 L24 36", 5),
    # fishing
    "reel": fill(hole(21, 26, 17) + " " + hole(21, 26, 10), "evenodd") + circle(21, 26, 4)
    + stroke("M33 14 L40 7", 4.5) + circle(42, 6, 4.5),
    "hook": stroke("M30 4 L30 30 C30 42 14 42 14 32 L14 27 L19 31", 5) + circle(30, 4, 3.5),
    "release": fill("M9 21 C14 12 26 10 33 16 L42 10 L40 21 L42 32 L33 26 C26 32 14 30 9 21 Z " + hole(17, 19, 2.2), "evenodd")
    + stroke("M4 39 C10 34 14 44 20 39 C26 34 30 44 36 39 C40 36 42 38 44 39", 3.5),
    "record": fill("M3 11 C10 8 18 9 23 13 L23 41 C18 37 10 36 3 38 Z M25 13 C30 9 38 8 45 11 L45 38 C38 36 30 37 25 41 Z"),
    "bite": fill("M8 6 L40 6 C44 6 46 8 46 12 L46 30 C46 34 44 36 40 36 L20 36 L10 44 L12 36 L8 36 C4 36 2 34 2 30 "
                 "L2 12 C2 8 4 6 8 6 Z"),
    # gear categories
    "rod": stroke("M8 42 L40 6", 4) + ring(15, 34, 6, 3.5) + stroke("M40 6 L40 30", 1.6),
    "bait": stroke("M8 36 C8 26 18 26 20 32 C22 38 30 38 30 28 C30 18 40 16 41 24", 6.5) + circle(41, 24, 4),
    "bag": fill("M12 18 C12 12 17 9 24 9 C31 9 36 12 36 18 L39 22 L39 41 C39 43 38 44 36 44 L12 44 C10 44 9 43 9 41 "
                "L9 22 Z M16 27 L32 27 L32 36 L16 36 Z", "evenodd") + stroke("M19 9 C19 4 29 4 29 9", 3.5),
    "hat": fill("M14 30 C14 16 18 10 24 10 C30 10 34 16 34 30 Z M3 31 C10 27 38 27 45 31 C45 36 3 36 3 31 Z"),
    # camp edit
    "decorate": fill("M24 40 C17 34 15 25 24 16 C33 25 31 34 24 40 Z M22 40 C13 41 6 35 5 25 C13 25 20 31 22 40 Z "
                     "M26 40 C35 41 42 35 43 25 C35 25 28 31 26 40 Z"),
    "layout": fill("M6 6 L21 6 L21 21 L6 21 Z M27 6 L42 6 L42 21 L27 21 Z M6 27 L21 27 L21 42 L6 42 Z M27 27 L42 27 L42 42 L27 42 Z"),
    "furniture": fill("M10 20 C10 14 14 11 24 11 C34 11 38 14 38 20 L38 26 L10 26 Z M4 22 L10 22 L10 33 L38 33 L38 22 L44 22 "
                      "L44 38 L4 38 Z") + stroke("M8 38 L8 43 M40 38 L40 43", 4),
    "ornament": fill("M13 30 L35 30 L32 44 L16 44 Z") + fill("M24 30 C17 30 12 24 12 17 C19 17 24 22 24 30 Z "
                                                             "M24 30 C24 21 29 15 37 14 C37 23 31 30 24 30 Z"),
    "rotate": stroke("M38 20 C35 11 25 7 16 11 C8 15 6 25 9 32 M10 28 L9 33 L14 33", 4.5)
    + stroke("M10 28 C13 37 23 41 32 37 C40 33 42 23 39 16 M38 20 L39 15 L34 15", 4.5),
    "trash": fill("M10 13 L38 13 L35 44 L13 44 Z M17 18 L19 18 L20 39 L18 39 Z M23 18 L25 18 L25 39 L23 39 Z "
                  "M29 18 L31 18 L30 39 L28 39 Z", "evenodd") + stroke("M7 11 L41 11 M19 11 L19 6 L29 6 L29 11", 4),
    # journal tabs
    "freshwater": stroke("M33 7 C14 7 14 21 24 24 C34 27 34 41 15 41", 5.5) + stroke("M40 7 L44 11", 3),
    "lake": fill("M24 33 C19 29 18 22 24 15 C30 22 29 29 24 33 Z M22 33 C15 34 10 29 9 22 C15 22 20 27 22 33 Z "
                 "M26 33 C33 34 38 29 39 22 C33 22 28 27 26 33 Z") + fill("M3 36 C12 33 36 33 45 36 C45 42 3 42 3 36 Z"),
    "valley": fill("M1 42 L15 14 L24 30 L33 14 L47 42 Z"),
    "sea": stroke("M3 19 C9 13 15 13 21 19 C27 25 33 25 39 19 C41 17 43 16 45 16 "
                  "M3 33 C9 27 15 27 21 33 C27 39 33 39 39 33 C41 31 43 30 45 30", 4.5),
    "special": stroke("M20 8 L20 30 C20 41 6 41 6 32 L6 28", 4.5) + fill(polygon(star_points(36, 12, 9, 4))),
    # water-mind
    "lotus": fill("M24 38 C17 32 16 22 24 12 C32 22 31 32 24 38 Z M21 38 C12 39 5 33 3 24 C11 23 18 29 21 38 Z "
                  "M27 38 C36 39 43 33 45 24 C37 23 30 29 27 38 Z"),
    "eye_off": fill("M2 24 C9 13 16 9 24 9 C32 9 39 13 46 24 C39 35 32 39 24 39 C16 39 9 35 2 24 Z "
                    + hole(24, 24, 7) + " M9 24 C14 17 19 14 24 14 C29 14 34 17 39 24 C34 31 29 34 24 34 C19 34 14 31 9 24 Z",
                    "evenodd") + stroke("M7 41 L41 7", 4.5),
    "camera": fill("M4 15 L14 15 L18 9 L30 9 L34 15 L44 15 L44 41 L4 41 Z " + hole(24, 27, 10) + " " + hole(24, 27, 6), "evenodd"),
    "frame": fill("M5 7 L43 7 L43 41 L5 41 Z M11 13 L11 35 L37 35 L37 13 Z", "evenodd")
    + fill("M14 32 L21 22 L26 28 L29 25 L34 32 Z") + circle(30, 18, 3),
    "zoom_in": ring(20, 20, 13, 5) + stroke("M30 30 L43 43", 6) + stroke("M14 20 L26 20 M20 14 L20 26", 4),
    "zoom_out": ring(20, 20, 13, 5) + stroke("M30 30 L43 43", 6) + stroke("M14 20 L26 20", 4),
    "signature": stroke("M5 33 C10 21 14 14 17 16 C21 19 11 38 15 38 C19 38 22 25 26 25 C29 25 27 34 30 34 "
                        "C33 34 35 28 38 28 C40 28 40 32 43 32", 4) + stroke("M5 42 L43 42", 3),
    "music": fill("M17 34 C17 39 12 42 8 41 C4 40 4 35 8 33 C11 31 14 32 17 33 L17 8 L41 4 L41 30 C41 35 36 38 32 37 "
                  "C28 36 28 31 32 29 C35 27 38 28 41 29 L41 12 L21 15 L21 34 Z"),
    "laurel": stroke("M30 44 C16 38 10 24 16 6", 3)
    + fill("M15 38 C8 38 5 33 5 30 C11 30 14 34 15 38 Z M12 30 C6 28 4 22 5 19 C11 21 12 26 12 30 Z "
           "M12 21 C7 17 7 11 9 8 C14 12 13 17 12 21 Z M20 39 C20 33 24 30 27 30 C27 35 24 38 20 39 Z "
           "M17 31 C18 25 22 23 25 23 C24 28 21 31 17 31 Z M15 22 C16 17 19 14 22 14 C21 19 18 21 15 22 Z"),
}


## Coloured pictures the Theme uses directly (they cannot be tinted per control): toggle switches and
## the drop-down arrow, in the palette of godot/ui/ui_theme.gd. (width, height, viewBox, body)
THEME_ICONS = {
    "theme_toggle_on": (92, 52, "0 0 46 26",
                        '<rect x="1" y="1" width="44" height="24" rx="12" fill="#627d4c"/>'
                        '<circle cx="33" cy="13" r="9" fill="#fbf4e6"/>'),
    "theme_toggle_off": (92, 52, "0 0 46 26",
                         '<rect x="1" y="1" width="44" height="24" rx="12" fill="#d3c2a1"/>'
                         '<circle cx="13" cy="13" r="9" fill="#fffaf0"/>'),
    "theme_arrow": (40, 40, "0 0 20 20",
                    '<path d="M4 7 L10 13 L16 7" fill="none" stroke="#4a3826" stroke-width="3" '
                    'stroke-linecap="round" stroke-linejoin="round"/>'),
}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for old in OUT.glob("*.svg"):
        if old.stem not in ICONS and old.stem not in THEME_ICONS:
            old.unlink()
    for name, body in ICONS.items():
        svg = ('<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" viewBox="0 0 48 48">'
               f"{body}</svg>\n")
        (OUT / f"{name}.svg").write_text(svg, encoding="utf-8", newline="\n")
    for name, (width, height, view_box, body) in THEME_ICONS.items():
        svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="{view_box}">'
               f"{body}</svg>\n")
        (OUT / f"{name}.svg").write_text(svg, encoding="utf-8", newline="\n")
    print(f"wrote {len(ICONS) + len(THEME_ICONS)} icons to {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
