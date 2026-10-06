extends SceneTree

## Content validation command (P0-026, DATA_SCHEMA §7): the one place that decides whether the shipped
## data is valid. It runs the game's own ContentValidator (every rule, every data file) plus the
## localization key check, prints each problem and exits non-zero when there is any. CI and
## developers run the same thing:
##
##   godot --headless --path godot -s res://tools/validate_content.gd
##
## Exit code 0 = valid, 1 = problems found.

func _initialize() -> void:
	# Autoloads (ContentDB) finish loading before the first frame.
	process_frame.connect(_run, CONNECT_ONE_SHOT)

func _run() -> void:
	var content_db: Node = root.get_node("ContentDB")
	var localization: GDScript = load("res://content/localization_check.gd")
	var problems := PackedStringArray()
	for line in content_db.errors:
		problems.append("content: %s" % line)
	var content := {
		"fish": content_db.fish, "regions": content_db.regions, "rods": content_db.rods,
		"baits": content_db.baits, "weather": content_db.weather,
		"bags": content_db.bags, "accessories": content_db.accessories, "decorations": content_db.decorations, "moments": content_db.moments,
	}
	var rows: Dictionary = localization.read_csv()
	problems.append_array(localization.problems(rows, localization.references(content)))
	problems.append_array(localization.row_problems(rows))
	problems.append_array(localization.malformed_lines())

	if problems.is_empty():
		print("CONTENT OK: %d fish, %d regions, %d rods, %d baits, %d bags, %d accessories, %d decorations, %d behaviors, %d weather, %d layouts" % [
			content_db.fish.size(), content_db.regions.size(), content_db.rods.size(), content_db.baits.size(),
			content_db.bags.size(), content_db.accessories.size(), content_db.decorations.size(),
			content_db.behaviors.size(), content_db.weather.size(), content_db.layouts.size()])
		quit(0)
		return
	printerr("CONTENT INVALID (%d problems)" % problems.size())
	for problem in problems:
		printerr(" - %s" % problem)
	quit(1)
