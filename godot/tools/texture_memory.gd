extends SceneTree

## Reports what the pictures cost in video memory: the total, the largest few, and any picture over
## the side limit. Exit code 0 = within budget, 1 = over (CI runs it beside validate_content.gd).
## Usage: godot --headless --path godot -s res://tools/texture_memory.gd
##
## The sizes come from the PNG headers, so the tool needs no import step and measures exactly what
## ships. Lossless RGBA8 with mipmaps is assumed (see TextureBudget).

const ROOTS: PackedStringArray = ["res://art", "res://branding"]

func _initialize() -> void:
	var entries: Array = []
	for root in ROOTS:
		TextureBudget.scan_dir(root, entries)
	var report := TextureBudget.report(entries)
	print("TEXTURES: %d pictures, %.1f MB of video memory (RGBA8 + mipmaps)" % [
		report["count"], float(report["total_bytes"]) / 1048576.0])
	for entry in (report["largest"] as Array).slice(0, 8):
		print("  %6.1f MB  %4dx%-4d  %s" % [
			float(entry["bytes"]) / 1048576.0, entry["width"], entry["height"], entry["path"]])
	if (report["too_big"] as Array).is_empty() and not report["over_budget"]:
		print("TEXTURES OK")
		quit(0)
		return
	for path in report["too_big"]:
		printerr("TEXTURES: %s is larger than %d px on a side" % [path, TextureBudget.MAX_SIDE])
	if report["over_budget"]:
		printerr("TEXTURES: %.1f MB is over the %.0f MB budget" % [
			float(report["total_bytes"]) / 1048576.0, float(TextureBudget.TOTAL_BUDGET_BYTES) / 1048576.0])
	quit(1)
