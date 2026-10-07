# Drawn art (D-029)

Pictures here replace the placeholder shapes. Anything missing is still drawn from shapes, so files can
arrive one at a time. What to draw and how is in `assets/design/ASSET_REQUESTS.md`.

| Folder | File | Used for |
|---|---|---|
| `world/` | `<art>_scene.png`, `<art>_scene_barren.png`, `<art>_foreground.png` | The painted pond (restored / level 0) and the front frame. `<art>` is the layout's `art` (Region 01: `r01`). Placed centred and sized to fill a 20:9 screen (`ArtLibrary.scene_rect`); the barren one is only used with the restored one |
| `character/` | `angler_idle.png`, `angler_cast.png`, `angler_bite.png`, `angler_reel.png`, `angler_hold.png` | The angler by fishing state; a missing pose shows idle. No rod: the game draws it |
| `fish/` | `<fish id>_top.png` (head right), `<fish id>_side.png` (head left) | Swimming fish; catch result and journal |
| `props/` | `<prop kind>.png`, `<prop kind>_02.png`, ... | Restoration props and camp decorations (kinds: `world/prop_kinds.gd`); the camp screen's cards use the same picture |
| `items/` | `<item id>.png` (`rod_bamboo`, `bait_worm`, `bag_basic`, `acc_straw_hat`, ...) | The equipment screen's item pictures |
| `animals/` | `dragonfly.png`, `butterfly.png`, `firefly.png`, `bird.png` | Ambient wildlife over the pond; `art.json` sets `width`, `faces` (`left`/`right`, which way the picture looks) and wing-beat `fps` |
| `moments/` | `<moment id>.png` (`moment_rain_rings`, ...; ids in `data/moments.json`) | The journal's moment cards and page, once the moment is seen |

**Animation frames.** A picture can have frames beside it: `<name>_f2.png`, `<name>_f3.png`, ... on **the same canvas size**
(a test checks it). A fish's `_top` frames are its tail bent one way, then the other (the straight picture is the base) and follow
its swimming; an animal's frames beat at `fps`; a prop's frames are poses it takes now and then (a frog blinks, looks up, croaks).
Reduced Motion shows the base picture only.

Adding a picture:

1. Put the PNG in its folder with the exact name.
2. Let Godot import it: open the editor once, or run `godot --headless --path godot --import`. Commit the `.import` file too.
3. Tune size and anchor in `art.json` (`width` / `height` in design pixels of the 720×1280 screen, `anchor` and
   `hands` as fractions of the picture), then check with `tools/capture_screenshot.gd`.
4. A new `<art>_scene.png` means the region layout (`data/region_layouts.json`: pond, zones, angler, rod_origin,
   camp_slots) has to be moved onto the painting.

Record the source and licence of every picture in `assets/placeholders/README.md`.

A generated drop zip is imported with `python tools/import_art_drop.py <zip>`: it renames the approved pictures to
these names and cleans the light-sheet halo and pinholes left by the cut-out (drop_01), or cuts single pictures out of
the sheets of drop_02 and drop_03. The list is in the script.
