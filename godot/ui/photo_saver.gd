class_name PhotoSaver
extends RefCounted

## Writes a picture of the scene to the game's own folder (water-mind "저장", GDD §17). Saving to the
## phone's gallery or sharing needs the platform's media APIs and is part of Photo Mode (P1-009);
## until then the file lands in `user://photos`, whose real location the toast names.

const DIR := "user://photos"

## Saves `image` as a PNG named after the local time and returns its absolute path, or "" on failure
## (the reason is logged). `dir` is for tests.
static func save(image: Image, dir: String = DIR) -> String:
	if image == null or image.is_empty():
		push_error("PhotoSaver: nothing to save")
		return ""
	var error := DirAccess.make_dir_recursive_absolute(dir)
	if error != OK:
		push_error("PhotoSaver: cannot create %s (%s)" % [dir, error_string(error)])
		return ""
	var path := "%s/%s.png" % [dir, file_stem(Time.get_datetime_dict_from_system())]
	var suffix := 2
	while FileAccess.file_exists(path):  # two photos in the same second keep both
		path = "%s/%s_%d.png" % [dir, file_stem(Time.get_datetime_dict_from_system()), suffix]
		suffix += 1
	error = image.save_png(path)
	if error != OK:
		push_error("PhotoSaver: cannot write %s (%s)" % [path, error_string(error)])
		return ""
	return ProjectSettings.globalize_path(path)

## "ripple_garden_20261006_143205" for a datetime dictionary.
static func file_stem(when: Dictionary) -> String:
	return "ripple_garden_%04d%02d%02d_%02d%02d%02d" % [when["year"], when["month"], when["day"], when["hour"], when["minute"], when["second"]]
