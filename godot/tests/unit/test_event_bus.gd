extends TestCase

## P0-003: EventBus conventions — typed parameters, no Dictionary payloads, past-tense names.

const FORBIDDEN_PREFIXES: PackedStringArray = ["request_", "on_", "do_", "set_", "get_", "start_", "begin_"]

func _bus_signals() -> Array[Dictionary]:
	var bus := tree.root.get_node("EventBus")
	return bus.get_script().get_script_signal_list()

func test_bus_declares_signals() -> void:
	assert_true(_bus_signals().size() >= 10, "EventBus declares suspiciously few signals")

func test_every_signal_parameter_is_typed() -> void:
	for sig in _bus_signals():
		for arg in sig["args"]:
			assert_true(arg["type"] != TYPE_NIL,
				"%s(%s) is untyped — declare an explicit type" % [sig["name"], arg["name"]])

func test_no_signal_carries_a_dictionary_payload() -> void:
	for sig in _bus_signals():
		for arg in sig["args"]:
			assert_true(arg["type"] != TYPE_DICTIONARY,
				"%s(%s) is a Dictionary payload — use typed parameters" % [sig["name"], arg["name"]])

func test_signal_names_are_snake_case_facts() -> void:
	var snake := RegEx.create_from_string("^[a-z]+(_[a-z]+)*$")
	for sig in _bus_signals():
		var sig_name: String = sig["name"]
		assert_not_null(snake.search(sig_name), "%s is not snake_case" % sig_name)
		for prefix in FORBIDDEN_PREFIXES:
			assert_false(sig_name.begins_with(prefix),
				"%s reads like a command; events are facts that already happened" % sig_name)

func test_signals_deliver_typed_arguments() -> void:
	var bus := tree.root.get_node("EventBus")
	var received: Array = []
	var handler := func(fish_id: String, size_cm: float, first_discovery: bool) -> void:
		received.append([fish_id, size_cm, first_discovery])
	bus.fish_caught.connect(handler)
	bus.fish_caught.emit("fish_crucian_carp", 12.5, true)
	bus.fish_caught.disconnect(handler)
	assert_deep_eq(received, [["fish_crucian_carp", 12.5, true]])
