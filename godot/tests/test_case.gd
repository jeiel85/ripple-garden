class_name TestCase
extends RefCounted

## Base class for headless tests run by res://tests/run_tests.gd.
## Every method whose name starts with `test_` is executed once.
## A test fails if any assertion fails or if the engine logs an error
## (script error, push_error) while it runs.

var tree: SceneTree
var _failures: PackedStringArray = []
var _expected_engine_errors: PackedStringArray = []

func get_failures() -> PackedStringArray:
	return _failures

## Declares that the code under test will log an engine error containing
## `substring`. Each call consumes one matching error; the test fails if the
## error is never logged.
func expect_engine_error(substring: String) -> void:
	_expected_engine_errors.append(substring)

func get_expected_engine_errors() -> PackedStringArray:
	return _expected_engine_errors

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

## Recursive, type-strict comparison: 1 and 1.0 differ, as do arrays with different order.
## Reports the path of the first difference, which is what makes save round-trip failures readable.
func assert_deep_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	var difference := _first_difference(actual, expected, "$")
	if not difference.is_empty():
		fail("%s%s" % ["" if message.is_empty() else message + ": ", difference])

func _first_difference(actual: Variant, expected: Variant, path: String) -> String:
	if typeof(actual) != typeof(expected):
		return "%s: type %s != %s (%s vs %s)" % [path, type_string(typeof(actual)), type_string(typeof(expected)),
			var_to_str(actual), var_to_str(expected)]
	if typeof(actual) == TYPE_DICTIONARY:
		for key in expected:
			if not actual.has(key):
				return "%s.%s: missing" % [path, key]
		for key in actual:
			if not expected.has(key):
				return "%s.%s: unexpected" % [path, key]
			var nested := _first_difference(actual[key], expected[key], "%s.%s" % [path, key])
			if not nested.is_empty():
				return nested
		return ""
	if typeof(actual) == TYPE_ARRAY:
		if actual.size() != expected.size():
			return "%s: array size %d != %d" % [path, actual.size(), expected.size()]
		for i in actual.size():
			var nested := _first_difference(actual[i], expected[i], "%s[%d]" % [path, i])
			if not nested.is_empty():
				return nested
		return ""
	if actual != expected:
		return "%s: %s != %s" % [path, var_to_str(actual), var_to_str(expected)]
	return ""
