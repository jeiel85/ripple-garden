class_name UiKit
extends RefCounted

## Builders for the controls the screens are made of. Everything user-facing goes through `tr()`
## (text is never concatenated into sentences; formats use one placeholder). Buttons that show only
## an icon would need an accessibility label; the buttons here always carry text.

static func label(text: String, variation: String = "", align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, wrap: bool = true) -> Label:
	var node := Label.new()
	node.text = text
	node.horizontal_alignment = align
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	if not variation.is_empty():
		node.theme_type_variation = variation
	return node

static func button(text: String, callback: Callable, primary: bool = false, min_height: float = UiTheme.TOUCH_MIN_PX) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size = Vector2(0, min_height)
	node.focus_mode = Control.FOCUS_ALL
	if primary:
		node.theme_type_variation = "PrimaryButton"
	node.pressed.connect(callback)
	return node

static func spacer(height: float) -> Control:
	var node := Control.new()
	node.custom_minimum_size = Vector2(0, height)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

static func margin(child: Control, pixels: int) -> MarginContainer:
	var node := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		node.add_theme_constant_override("margin_" + side, pixels)
	node.add_child(child)
	return node

static func vbox(separation: int = 14) -> VBoxContainer:
	var node := VBoxContainer.new()
	node.add_theme_constant_override("separation", separation)
	return node

static func hbox(separation: int = 14) -> HBoxContainer:
	var node := HBoxContainer.new()
	node.add_theme_constant_override("separation", separation)
	return node

## A rounded panel containing `content`, centred in its parent with a maximum width.
static func modal(content: Control, width: float = 620.0) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(width, 0)
	panel.add_child(margin(content, 26))
	return panel

## Stable icon-free portrait of a fish for the journal and inspect screens: draws the same
## silhouette the agents swim as, tinted from the species colour, or a dark outline when unseen.
class FishPortrait extends Control:
	var fish_id := ""
	var known := true
	var length_scale := 1.0

	func _init(p_fish_id: String = "", p_known: bool = true, p_length_scale: float = 1.0) -> void:
		fish_id = p_fish_id
		known = p_known
		length_scale = p_length_scale
		custom_minimum_size = Vector2(150, 90)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var def := ContentDB.get_fish(fish_id)
		if def.is_empty():
			return
		var hue := float(absi(hash(fish_id)) % 360) / 360.0
		var rarity := int(def["rarity"])
		var body := Color.from_hsv(hue, 0.30 + 0.07 * rarity, 0.78 - 0.02 * rarity)
		if not known:
			body = Color(0.04, 0.09, 0.11, 0.85)
		var center := size / 2.0
		var half := minf(size.x * 0.42, 62.0) * length_scale
		var points := PackedVector2Array()
		for i in 18:
			var angle := TAU * i / 18.0
			points.append(center + Vector2(cos(angle) * half, sin(angle) * half * 0.42))
		draw_colored_polygon(points, body)
		draw_colored_polygon(PackedVector2Array([
			center + Vector2(-half * 0.95, 0), center + Vector2(-half * 1.5, -half * 0.45),
			center + Vector2(-half * 1.3, 0), center + Vector2(-half * 1.5, half * 0.45)]), body.darkened(0.12))
		if known:
			draw_circle(center + Vector2(half * 0.62, -half * 0.08), maxf(2.5, half * 0.07), Color(0.08, 0.1, 0.12))
