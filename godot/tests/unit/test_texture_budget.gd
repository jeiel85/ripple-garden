extends TestCase

## BACKLOG "그림 텍스처 메모리": the picture budget and the report CI runs beside content validation.

func test_vram_bytes_counts_rgba_and_mipmaps() -> void:
	assert_eq(TextureBudget.vram_bytes(100, 100, false), 40000, "RGBA8 is four bytes a pixel")
	assert_eq(TextureBudget.vram_bytes(100, 100, true), 53333, "mipmaps add a third")
	assert_eq(TextureBudget.vram_bytes(0, 0, true), 0)

func test_png_size_reads_the_header_without_importing() -> void:
	var entries: Array = []
	TextureBudget.scan_dir("res://art/world", entries)
	assert_true(entries.size() > 0, "the world pictures are found")
	var first: Dictionary = entries[0]
	assert_eq(TextureBudget.png_size(first["path"]), Vector2i(int(first["width"]), int(first["height"])),
		"the header size matches what the scan stored")

func test_report_names_the_largest_and_the_oversized() -> void:
	var report := TextureBudget.report([
		{"path": "small", "width": 10, "height": 10},
		{"path": "huge", "width": TextureBudget.MAX_SIDE + 1, "height": 8},
	])
	assert_eq(report["count"], 2)
	assert_eq((report["largest"] as Array)[0]["path"], "huge")
	assert_eq(report["too_big"], ["huge"], "a picture over the side limit is named")
	assert_false(report["over_budget"], "two small pictures are under the budget")

func test_the_shipped_pictures_fit_the_budget() -> void:
	var entries: Array = []
	for root in ["res://art", "res://branding"]:
		TextureBudget.scan_dir(root, entries)
	assert_true(entries.size() > 100, "the scan found the pictures")
	var report := TextureBudget.report(entries)
	assert_false(report["over_budget"],
		"all pictures at once need %.0f MB" % (float(report["total_bytes"]) / 1048576.0))
	assert_eq(report["too_big"], [], "no picture is wider or taller than %d px" % TextureBudget.MAX_SIDE)
