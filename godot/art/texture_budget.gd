class_name TextureBudget
extends RefCounted

## What the pictures cost in video memory (BACKLOG "그림 텍스처 메모리"). Pictures are imported
## lossless, so one costs width * height * 4 bytes (RGBA8), plus a third more when mipmaps are
## generated. `tools/texture_memory.gd` reports the totals and CI runs it; these limits keep a new
## picture from quietly pushing the game past what a mid-range Android phone can hold.
##
## Only one region's scenery is loaded at a time, so TOTAL_BUDGET_BYTES is a generous ceiling that
## catches a runaway import (a picture imported at twice its size) rather than the normal state.

## No single picture should be wider or taller than this; larger ones are downscaled before import.
const MAX_SIDE := 2048
## Every picture in the game at once, with mipmaps (a ceiling, not the normal state).
const TOTAL_BUDGET_BYTES := 256 * 1024 * 1024

## Bytes a picture takes on the GPU. `mipmaps` adds the smaller copies (1/3 of the base).
static func vram_bytes(width: int, height: int, mipmaps: bool = true) -> int:
	var base := width * height * 4
	return base + base / 3 if mipmaps else base

## Width and height from a PNG header, without importing the picture (Vector2i.ZERO if unreadable).
static func png_size(path: String) -> Vector2i:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return Vector2i.ZERO
	var signature := file.get_buffer(8)
	if signature != PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10]):
		return Vector2i.ZERO
	file.seek(16)
	var bytes := file.get_buffer(8)
	if bytes.size() != 8:
		return Vector2i.ZERO
	var width := (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3]
	var height := (bytes[4] << 24) | (bytes[5] << 16) | (bytes[6] << 8) | bytes[7]
	return Vector2i(width, height)

## Adds every PNG under `root` (recursively) to `entries` as {path, width, height}.
static func scan_dir(root: String, entries: Array) -> void:
	var dir := DirAccess.open(root)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while not name.is_empty():
		if name.begins_with("."):
			name = dir.get_next()
			continue
		var path := root.path_join(name)
		if dir.current_is_dir():
			scan_dir(path, entries)
		elif name.get_extension().to_lower() == "png":
			var size := png_size(path)
			if size.x > 0 and size.y > 0:
				entries.append({"path": path, "width": size.x, "height": size.y})
		name = dir.get_next()
	dir.list_dir_end()

## Totals for a list of {path, width, height} entries: the sum, the largest first, and the breaches.
static func report(entries: Array) -> Dictionary:
	var total := 0
	var largest: Array = []
	var too_big: Array = []
	for entry in entries:
		var width := int(entry["width"])
		var height := int(entry["height"])
		var bytes := vram_bytes(width, height)
		total += bytes
		largest.append({"path": entry["path"], "bytes": bytes, "width": width, "height": height})
		if width > MAX_SIDE or height > MAX_SIDE:
			too_big.append(entry["path"])
	largest.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["bytes"] > b["bytes"])
	return {
		"count": entries.size(),
		"total_bytes": total,
		"largest": largest,
		"too_big": too_big,
		"over_budget": total > TOTAL_BUDGET_BYTES,
	}
