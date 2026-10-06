extends Node

## Audio bus access point (TECH_SPEC §12). Buses are defined in
## res://audio/default_bus_layout.tres; callers address them by name.

const REQUIRED_BUSES: PackedStringArray = [
	"Master", "BGM", "Water", "Wind", "Wildlife", "Weather", "Fishing", "Camp",
]

func _ready() -> void:
	var missing := missing_buses()
	if not missing.is_empty():
		push_error("Audio bus layout is missing buses: %s" % ", ".join(missing))

func missing_buses() -> PackedStringArray:
	var missing := PackedStringArray()
	for bus_name in REQUIRED_BUSES:
		if AudioServer.get_bus_index(bus_name) == -1:
			missing.append(bus_name)
	return missing

## Sets bus volume on a 0..1 linear scale. Returns false for unknown buses.
func set_bus_volume_linear(bus_name: String, linear: float) -> bool:
	var index := AudioServer.get_bus_index(bus_name)
	if index == -1:
		push_warning("Unknown audio bus: %s" % bus_name)
		return false
	AudioServer.set_bus_volume_linear(index, clampf(linear, 0.0, 1.0))
	return true

## Returns the bus volume on a 0..1 linear scale, or -1.0 for unknown buses.
func get_bus_volume_linear(bus_name: String) -> float:
	var index := AudioServer.get_bus_index(bus_name)
	if index == -1:
		return -1.0
	return AudioServer.get_bus_volume_linear(index)

func set_bus_muted(bus_name: String, muted: bool) -> bool:
	var index := AudioServer.get_bus_index(bus_name)
	if index == -1:
		push_warning("Unknown audio bus: %s" % bus_name)
		return false
	AudioServer.set_bus_mute(index, muted)
	return true
