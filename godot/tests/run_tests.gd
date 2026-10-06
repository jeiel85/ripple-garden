extends SceneTree

## Headless test runner.
## Usage: godot --headless --path godot -s res://tests/run_tests.gd
## Exit code 0 = all passed, 1 = failures (including engine errors).

const TEST_DIRS: PackedStringArray = ["res://tests/unit"]

class ErrorCollector extends Logger:
	var _mutex := Mutex.new()
	var _errors: PackedStringArray = []

	func _log_error(function: String, file: String, line: int, code: String,
			rationale: String, _editor_notify: bool, error_type: int,
			_script_backtrace: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		var text := rationale if not rationale.is_empty() else code
		_mutex.lock()
		_errors.append("%s (%s:%d in %s)" % [text, file, line, function])
		_mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass

	func take() -> PackedStringArray:
		_mutex.lock()
		var taken := _errors.duplicate()
		_errors.clear()
		_mutex.unlock()
		return taken

var _collector := ErrorCollector.new()

func _init() -> void:
	OS.add_logger(_collector)

func _initialize() -> void:
	# Wait one frame so autoload singletons have finished _ready().
	process_frame.connect(_run, CONNECT_ONE_SHOT)

func _run() -> void:
	var passed := 0
	var failed := 0

	for startup_error in _collector.take():
		printerr("FAIL [startup] ", startup_error)
		failed += 1

	for path in _discover():
		var script: GDScript = load(path)
		if script == null or not script.can_instantiate():
			printerr("FAIL [load] ", path)
			failed += 1
			continue
		for method in script.get_script_method_list():
			var method_name: String = method["name"]
			if not method_name.begins_with("test_"):
				continue
			var test_case: TestCase = script.new()
			test_case.tree = self
			await test_case.call(method_name)
			var problems := test_case.get_failures()
			problems.append_array(_collector.take())
			var label := "%s::%s" % [path.get_file(), method_name]
			if problems.is_empty():
				print("ok   ", label)
				passed += 1
			else:
				failed += 1
				for problem in problems:
					printerr("FAIL ", label, " — ", problem)

	print("\n%d passed, %d failed" % [passed, failed])
	OS.remove_logger(_collector)
	quit(0 if failed == 0 and passed > 0 else 1)

func _discover() -> PackedStringArray:
	var found := PackedStringArray()
	for dir_path in TEST_DIRS:
		for file_name in DirAccess.get_files_at(dir_path):
			if file_name.begins_with("test_") and file_name.ends_with(".gd"):
				found.append(dir_path.path_join(file_name))
	found.sort()
	return found
