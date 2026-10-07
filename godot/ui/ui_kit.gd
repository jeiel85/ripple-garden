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

## `wrap` lets long text break onto lines. Leave it off for buttons that share a row with something
## that expands: a wrapping button has no minimum width, so the neighbour would squash it flat.
static func button(text: String, callback: Callable, primary: bool = false, min_height: float = UiTheme.TOUCH_MIN_PX,
		wrap: bool = false) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size = Vector2(0, min_height)
	node.focus_mode = Control.FOCUS_ALL
	if wrap:
		node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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

## A tinted icon from UiIcons. `color` defaults to inheriting the modulate of the parent.
## Sets `control`'s text to the named step of UiTheme.TEXT_SIZES and keeps it there when the theme is
## rebuilt (Text Scale, Large UI), instead of a fixed pixel size.
static func text_size(control: Control, size_name: String) -> void:
	var apply := func() -> void:
		if not control.has_theme_font_size(size_name, UiTheme.SIZES_TYPE):
			return  # not under the game's theme (yet)
		var wanted := control.get_theme_font_size(size_name, UiTheme.SIZES_TYPE)
		# Setting an override emits theme_changed again: only set a size that differs.
		if not control.has_theme_font_size_override("font_size") or control.get_theme_font_size("font_size") != wanted:
			control.add_theme_font_size_override("font_size", wanted)
	control.theme_changed.connect(apply)
	control.tree_entered.connect(apply)
	apply.call()

static func icon(icon_name: String, size_px: float, color: Variant = null) -> TextureRect:
	var node := TextureRect.new()
	node.texture = UiIcons.texture(icon_name)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.custom_minimum_size = Vector2(size_px, size_px)
	node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if color is Color:
		node.self_modulate = color
	return node

## A button with an icon. `vertical` puts the icon above the label (the mockups' navigation and
## action buttons); otherwise the icon sits left of the label. The icon is also the accessibility
## cue, so the label is never dropped: icon-only buttons set it as tooltip_text instead.
static func icon_button(icon_name: String, text: String, callback: Callable, variation: String = "",
		icon_px: float = UiTheme.ICON_L, vertical: bool = true) -> Button:
	var node := Button.new()
	node.text = text
	node.icon = UiIcons.texture(icon_name)
	# Not expand_icon: an expanded icon is left out of the minimum size and can be squeezed to nothing.
	node.add_theme_constant_override("icon_max_width", int(icon_px))
	node.custom_minimum_size = Vector2(0, UiTheme.TOUCH_MIN_PX)
	node.focus_mode = Control.FOCUS_ALL
	if text.is_empty():
		node.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER  # an icon-only button keeps its icon in the middle
	elif vertical:
		node.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		node.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		node.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	if not variation.is_empty():
		node.theme_type_variation = variation
	node.pressed.connect(callback)
	return node

## A round icon-only button over the scenery. `label` is its accessibility name (tooltip); with
## `caption` the name is also printed under the icon (the water-mind buttons in the mockup).
static func round_button(icon_name: String, label: String, callback: Callable, caption: bool = false,
		size_px: float = UiTheme.TOUCH_MIN_PX) -> Button:
	var node := icon_button(icon_name, label if caption else "", callback, "RoundButton", size_px * (0.34 if caption else 0.42), true)
	node.tooltip_text = label
	node.custom_minimum_size = Vector2(size_px, size_px)
	if caption:
		# The caption must stay inside the circle whatever the language and the device's font.
		node.set_meta("caption_width", size_px - CAPTION_PADDING)
		node.theme_changed.connect(func() -> void: fit_caption(node))
	return node

## Room left on each side of a round button's caption.
const CAPTION_PADDING := 20.0
const MIN_CAPTION_PX := 12

## Shrinks a round button's caption until it fits its circle (call again after changing the text).
static func fit_caption(button: Button) -> void:
	if not button.has_meta("caption_width") or button.get_meta("fitting", false):
		return
	button.set_meta("fitting", true)  # the override below notifies a theme change: do not recurse
	button.remove_theme_font_size_override("font_size")
	var font := button.get_theme_font("font")
	var natural := button.get_theme_font_size("font_size")
	var size := natural
	var width: float = button.get_meta("caption_width")
	while size > MIN_CAPTION_PX and font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
		size -= 1
	if size != natural:
		button.add_theme_font_size_override("font_size", size)
	button.set_meta("fitting", false)

## A large card-like button with an icon, a title and a smaller line under it (the catch-result
## actions: "방생 / 다음에도 또 만나길"). The labels are children of the button, so its minimum
## size follows them; the button keeps its own press, focus and disabled handling.
static func action_card(icon_name: String, title: String, subtitle: String, callback: Callable, variation: String = "") -> Button:
	var node := Button.new()
	node.focus_mode = Control.FOCUS_ALL
	if not variation.is_empty():
		node.theme_type_variation = variation
	node.tooltip_text = "%s — %s" % [title, subtitle]
	var on_wood := variation in ["PrimaryButton", "WaterButton"]
	var text_color := UiTheme.WOOD_TEXT if on_wood else UiTheme.INK
	var column := vbox(2)
	column.name = "Content"
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 10
	column.offset_right = -10
	column.offset_top = 12
	column.offset_bottom = -30 if variation == "WaterButton" else -12  # stay above the band of water
	var picture := icon(icon_name, UiTheme.ICON_M, text_color)  # with a title under it: the body-text size
	picture.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(picture)
	var title_label := label(title, "TitleLabel", HORIZONTAL_ALIGNMENT_CENTER, false)
	title_label.name = "Title"
	title_label.add_theme_color_override("font_color", text_color)
	column.add_child(title_label)
	var sub_label := label(subtitle, "SmallLabel", HORIZONTAL_ALIGNMENT_CENTER, true)
	sub_label.name = "Subtitle"
	sub_label.custom_minimum_size.x = 150  # wraps inside the card instead of widening the row
	text_size(sub_label, "caption")
	sub_label.add_theme_color_override("font_color", Color(text_color, 0.8))
	column.add_child(sub_label)
	node.add_child(column)
	var fit := func() -> void:
		var needed := column.get_combined_minimum_size()
		# The column's own insets, including the room kept above the water band.
		var insets := column.offset_top - column.offset_bottom
		node.custom_minimum_size = Vector2(maxf(needed.x + 20.0, UiTheme.TOUCH_MIN_PX), maxf(needed.y + insets, UiTheme.TOUCH_MIN_PX))
	column.minimum_size_changed.connect(fit)
	fit.call()
	node.pressed.connect(callback)
	return node

## A wide button whose icon and word sit centred together (the mockups' wooden "낚시" / "완료"): a Button
## alone pins its icon to an edge. The label is returned through the button's "label" meta.
static func centered_button(icon_name: String, text: String, callback: Callable, variation: String, icon_px: float = UiTheme.ICON_L) -> Button:
	var node := Button.new()
	node.theme_type_variation = variation
	node.focus_mode = Control.FOCUS_ALL
	node.tooltip_text = text
	var content := hbox(14)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	if variation == "WaterButton":
		content.offset_bottom = -20  # above the band of water
	var on_wood := variation in ["PrimaryButton", "WaterButton"]
	content.add_child(icon(icon_name, icon_px, UiTheme.WOOD_TEXT if on_wood else UiTheme.GREEN_TEXT))
	var word := label(text, "CtaLabel", HORIZONTAL_ALIGNMENT_CENTER, false)
	content.add_child(word)
	node.add_child(content)
	node.set_meta("label", word)
	node.custom_minimum_size = Vector2(maxf(content.get_combined_minimum_size().x + 48.0, 200.0), UiTheme.TOUCH_MIN_PX)
	# The word only has its real size once the theme reaches it (in the tree): the button grows to fit then.
	content.minimum_size_changed.connect(func() -> void:
		node.custom_minimum_size.x = maxf(node.custom_minimum_size.x, content.get_combined_minimum_size().x + 48.0))
	node.pressed.connect(callback)
	return node

## A vertical hair line, the separator inside status pills.
static func divider(height: float = 26.0, color: Color = Color(1, 0.96, 0.88, 0.5)) -> ColorRect:
	var node := ColorRect.new()
	node.color = color
	node.custom_minimum_size = Vector2(2, height)
	node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

## A wooden sign with an icon and a title (the mockups' "도감", "캠프", "지역 선택" boards).
static func sign_board(icon_name: String, title: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = "SignPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := hbox(14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(icon(icon_name, UiTheme.ICON_L, UiTheme.WOOD_TEXT))
	var title_label := label(title, "SignLabel", HORIZONTAL_ALIGNMENT_CENTER, false)
	title_label.name = "Title"
	row.add_child(title_label)
	panel.add_child(row)
	return panel

## Small "something new to look at" dot in the top-right corner of `owner_control` (D-018). It is a
## shape as well as a colour, and the owner's tooltip names it for assistive tech.
static func notice_dot(owner_control: Control) -> NoticeDot:
	var dot := NoticeDot.new()
	owner_control.add_child(dot)
	dot.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	dot.offset_left = -30
	dot.offset_right = -2
	dot.offset_top = 2
	dot.offset_bottom = 30
	dot.visible = false
	return dot

class NoticeDot extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var radius := minf(size.x, size.y) * 0.5
		draw_circle(size / 2.0, radius, Color.WHITE)
		draw_circle(size / 2.0, radius - 3.0, UiTheme.NOTICE)

## Stable icon-free portrait of a fish for the journal and inspect screens: draws the same
## silhouette the agents swim as, tinted from the species colour, or a dark outline when unseen.
## Drawn art (`fish/<id>_side.png`, head to the left, D-029) replaces the shapes; an unmet species
## then shows that picture as a dark silhouette.
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

	## Side view facing left, like the mockups' fish cards: body, lighter belly, dorsal, pelvic and
	## forked tail fins, gill line, a few scale arcs and a bright eye. Unmet species are a soft
	## silhouette with a question mark (UI_UX §5: a hint, never a blank).
	func _draw() -> void:
		var def := ContentDB.get_fish(fish_id)
		if def.is_empty():
			return
		var art := ArtLibrary.texture("fish", fish_id + "_side")
		if art != null:
			_draw_art(art)
			return
		var colors := species_colors(fish_id, int(def["rarity"]))
		var body: Color = colors["body"]
		var belly: Color = colors["belly"]
		var fin: Color = colors["fin"]
		if not known:
			body = Color(0.45, 0.42, 0.38, 0.55)
			belly = body
			fin = Color(0.45, 0.42, 0.38, 0.45)
		var half := minf(size.x * 0.34, size.y * 0.78) * length_scale
		var height := half * 0.42
		var center := size / 2.0 + Vector2(-half * 0.12, 0)
		var at := func(x: float, y: float) -> Vector2: return center + Vector2(x * half, y * height)

		# Tail, dorsal and pelvic fins go behind the body.
		draw_colored_polygon(PackedVector2Array([at.call(0.92, -0.18), at.call(1.42, -0.95), at.call(1.26, 0.0),
			at.call(1.42, 0.95), at.call(0.92, 0.18)]), fin)
		draw_colored_polygon(PackedVector2Array([at.call(-0.3, -0.9), at.call(-0.05, -1.55), at.call(0.35, -1.25),
			at.call(0.55, -0.7)]), fin)
		draw_colored_polygon(PackedVector2Array([at.call(-0.15, 0.75), at.call(0.05, 1.35), at.call(0.22, 0.8)]), fin)
		var upper := PackedVector2Array()
		var lower := PackedVector2Array()
		for i in 21:
			var x := lerpf(-1.0, 1.0, i / 20.0)
			var thickness := pow(maxf(0.0, 1.0 - x * x), 0.55) * (1.0 - 0.32 * maxf(x, 0.0))
			upper.append(at.call(x, -thickness))
			lower.append(at.call(x, thickness * 0.88))
		lower.reverse()
		draw_colored_polygon(upper + lower, body)
		var belly_line := PackedVector2Array()
		for i in 17:
			var x := lerpf(-0.85, 0.8, i / 16.0)
			var thickness := pow(maxf(0.0, 1.0 - x * x), 0.55) * (1.0 - 0.32 * maxf(x, 0.0))
			belly_line.append(at.call(x, thickness * 0.2))
		var belly_bottom := PackedVector2Array()
		for i in range(16, -1, -1):
			var x := lerpf(-0.85, 0.8, i / 16.0)
			var thickness := pow(maxf(0.0, 1.0 - x * x), 0.55) * (1.0 - 0.32 * maxf(x, 0.0))
			belly_bottom.append(at.call(x, thickness * 0.86))
		draw_colored_polygon(belly_line + belly_bottom, belly)
		if not known:
			draw_string(ThemeDB.fallback_font, at.call(-0.12, 0.45), "?", HORIZONTAL_ALIGNMENT_CENTER, -1, int(height * 1.4), Color(1, 1, 1, 0.75))
			return
		# Scales: a few soft arcs, then the gill line and the eye.
		for row in 2:
			for i in 5:
				var c: Vector2 = at.call(-0.2 + i * 0.22, -0.35 + row * 0.45)
				draw_arc(c, height * 0.22, -PI / 2.0, PI / 2.0, 6, Color(body.darkened(0.25), 0.35), maxf(1.0, height * 0.05), true)
		draw_arc(at.call(-0.42, 0.0), height * 0.75, -PI * 0.42, PI * 0.42, 10, Color(body.darkened(0.35), 0.6), maxf(1.5, height * 0.07), true)
		var eye: Vector2 = at.call(-0.7, -0.22)
		draw_circle(eye, maxf(2.5, height * 0.17), Color(0.98, 0.95, 0.85))
		draw_circle(eye, maxf(2.0, height * 0.12), Color(0.1, 0.08, 0.06))
		draw_circle(eye + Vector2(-1, -1) * height * 0.04, maxf(1.0, height * 0.04), Color.WHITE)

	func has_art() -> bool:
		return ArtLibrary.has("fish", fish_id + "_side")

	func _draw_art(art: Texture2D) -> void:
		var box_size := size * Vector2(0.92, 0.9) * length_scale
		var rect := ArtLibrary.fit_rect(art, Rect2((size - box_size) / 2.0, box_size))
		if known:
			draw_texture_rect(art, rect, false)
			return
		draw_texture_rect(art, rect, false, Color(0.3, 0.27, 0.24, 0.6))
		var font_size := int(clampf(rect.size.y * 0.5, 14.0, 64.0))
		draw_string(ThemeDB.fallback_font, rect.get_center() + Vector2(-font_size * 0.28, font_size * 0.35), "?",
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 1, 0.75))

	## Stable colours for a species until drawn art arrives (shared with the swimming agents).
	static func species_colors(id: String, rarity: int) -> Dictionary:
		return FishColors.for_species(id, rarity)
