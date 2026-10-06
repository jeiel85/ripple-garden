class_name TestCase
extends RefCounted

## Base class for headless tests run by res://tests/run_tests.gd.
## Every method whose name starts with `test_` is executed once.
## A test fails if any assertion fails or if the engine logs an error
## (script error, push_error) while it runs.

var tree: SceneTree
var _failures: PackedStringArray = []

func get_failures() -> PackedStringArray:
	return _failures

func clear_failures() -> void:
	_failures.clear()

func fail(message: String) -> void:
	_failures.append(message)

func assert_true(condition: bool, message: String = "expected true") -> void:
	if not condition:
		fail(message)

func assert_false(condition: bool, message: String = "expected false") -> void:
	if condition:
		fail(message)

func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if typeof(actual) != typeof(expected) or actual != expected:
		fail("%sexpected <%s> but was <%s>" % [
			"" if message.is_empty() else message + ": ", var_to_str(expected), var_to_str(actual)
		])

func assert_not_null(value: Variant, message: String = "expected non-null") -> void:
	if value == null:
		fail(message)
