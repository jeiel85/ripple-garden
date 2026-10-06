# Drawn art (D-029)

Pictures here replace the placeholder shapes. Anything missing is still drawn from shapes, so files can
arrive one at a time. What to draw and how is in `assets/design/ASSET_REQUESTS.md`.

| Folder | File | Used for |
|---|---|---|
| `world/` | `<art>_scene.png`, `<art>_scene_barren.png`, `<art>_foreground.png` | The painted pond (restored / level 0) and the front frame. `<art>` is the layout's `art` (Region 01: `r01`) |
| `character/` | `angler_idle.png`, `angler_cast.png`, `angler_bite.png`, `angler_reel.png`, `angler_hold.png` | The angler by fishing state; a missing pose shows idle. No rod: the game draws it |
| `fish/` | `<fish id>_top.png` (head right), `<fish id>_side.png` (head left) | Swimming fish; catch result and journal |
| `props/` | `<prop kind>.png`, `<prop kind>_02.png`, ... | Restoration props and camp decorations (kinds: `world/prop_kinds.gd`) |

Adding a picture:

1. Put the PNG in its folder with the exact name.
2. Let Godot import it: open the editor once, or run `godot --headless --path godot --import`. Commit the `.import` file too.
3. Tune size and anchor in `art.json` (`width` / `height` in design pixels of the 720×1280 screen, `anchor` and
   `hands` as fractions of the picture), then check with `tools/capture_screenshot.gd`.
4. A new `<art>_scene.png` means the region layout (`data/region_layouts.json`: pond, zones, angler, rod_origin,
   camp_slots) has to be moved onto the painting.

Record the source and licence of every picture in `assets/placeholders/README.md`.
