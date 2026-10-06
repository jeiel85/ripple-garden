class_name Hud
extends Control

## The always-on interface, laid out like the main-world mockup (UI_UX §3, D-018):
##   top     a dark pill with region | clock | weather, a pill with the two currencies, a round
##           settings button, and under it the round water-mind button
##   bottom  Journal and Gear cards, the wooden fishing button (with a band of water) and Camp; the
##           round Restore button sits under the water-mind button on the right
## While a line is out the bottom row turns into the fishing controls of the bite/reel mockup:
## Cancel, a large round action button (hook / reel) ringed by the landing progress, and a shortcut
## to the journal, with a one-line tip underneath.
##
## The scenery stays most of the screen; the HUD fades after a few idle seconds and a touch brings it
## back. It only reports presses; the UIController decides what they do. It never changes state.
##
## The top bar is handed to the UIController (`top_bar`) so it can sit above full-screen panels
## (catch result, equipment...) that keep the status visible; the fade covers it either way.

signal journal_pressed
signal gear_pressed
signal restore_pressed
signal camp_pressed
signal map_pressed
signal settings_pressed
signal water_mind_pressed
signal cta_down
signal cta_up
signal cancel_pressed

const IDLE_FADE_SEC := 5.0
const FADE_TIME := 0.5
const CLOCK_REFRESH_SEC := 1.0

## Fishing state (lower-case name) -> [label key, enabled]. READY/AIM is the fishing button of the
## main row; every other state is the round action button of the fishing row.
const CTA_BY_STATE := {
	"ready": ["ui.cta.cast", true],
	"aim": ["ui.cta.cast", true],
	"cast": ["ui.cta.casting", false],
	"wait": ["ui.cta.waiting", false],
	"bite_hint": ["ui.cta.hook", true],
	"hook": ["ui.cta.hook", true],
	"fight": ["ui.cta.reel", true],
	"land": ["ui.cta.landing", false],
	"inspect": ["ui.cta.landing", false],
	"release": ["ui.cta.releasing", false],
}
## One-line tip under the fishing controls, per state (empty = none).
const TIP_BY_STATE := {
	"cast": "ui.tip.cast",
	"wait": "ui.tip.wait",
	"bite_hint": "ui.tip.bite",
	"hook": "ui.tip.bite",
	"fight": "ui.tip.fight",
}
const FISHING_STATES: PackedStringArray = ["cast", "wait", "bite_hint", "hook", "fight", "land"]

var reduced_motion := false
## Which parts the UIController currently allows (a full-screen panel keeps the status or the navigation;
## water-mind keeps neither). The fade and the fishing state decide within that.
var allow_top := true
var allow_bottom := true
## Top row (status pill, currencies, settings). Parented by the UIController above the modal host.
var top_bar: MarginContainer
var side_column: VBoxContainer
var bottom_bar: MarginContainer
var fishing_bar: MarginContainer

var status_pill: PanelContainer
var region_label: Label
var clock_label: Label
var weather_icon: TextureRect
var weather_label: Label
var currency_pill: PanelContainer
var ripple_label: Label
var memory_label: Label
var currency_words: Array[Label] = []
var settings_button: Button
var water_mind_button: Button
var journal_button: Button
var gear_button: Button
var cta_button: Button
var cta_label: Label
var restore_button: Button
var restore_dot: UiKit.NoticeDot
var camp_button: Button
var camp_dot: UiKit.NoticeDot
var journal_dot: UiKit.NoticeDot
var cancel_button: Button
var action_button: ReelButton
var fishing_journal_button: Button
var tip_label: Label

var _region_id := ""
var _weather: WeatherService = null
var _idle := 0.0
var _faded := false
var _fade_tween: Tween
var _can_fade := true
var _clock_timer := 0.0
var _state_name := "ready"

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

	top_bar = MarginContainer.new()
	top_bar.name = "TopBar"
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_child(_build_top())
	add_child(top_bar)

	side_column = UiKit.vbox(6)
	side_column.name = "SideColumn"
	side_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side_column.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	side_column.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	water_mind_button = UiKit.round_button("lotus", tr("ui.button.water_mind"), func() -> void: water_mind_pressed.emit())
	side_column.add_child(water_mind_button)
	restore_button = UiKit.round_button("sprout", tr("ui.button.restore"), func() -> void: restore_pressed.emit())
	restore_dot = UiKit.notice_dot(restore_button)
	side_column.add_child(restore_button)
	add_child(side_column)

	bottom_bar = MarginContainer.new()
	bottom_bar.name = "BottomBar"
	bottom_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_bar.add_child(_build_bottom())
	add_child(bottom_bar)

	fishing_bar = MarginContainer.new()
	fishing_bar.name = "FishingBar"
	fishing_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	fishing_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	fishing_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fishing_bar.add_child(_build_fishing())
	fishing_bar.visible = false
	add_child(fishing_bar)
	_set_margins(0.0, 0.0)

func _build_top() -> Control:
	var row := UiKit.hbox(10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	status_pill = PanelContainer.new()
	status_pill.theme_type_variation = "PillPanel"
	status_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var status := UiKit.hbox(10)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status.add_child(UiKit.icon("mountain", 30.0, UiTheme.PILL_TEXT))
	region_label = UiKit.label("", "PillLabel", HORIZONTAL_ALIGNMENT_LEFT, false)
	status.add_child(region_label)
	status.add_child(UiKit.divider())
	clock_label = UiKit.label("", "PillLabel", HORIZONTAL_ALIGNMENT_CENTER, false)
	status.add_child(clock_label)
	status.add_child(UiKit.divider())
	weather_icon = UiKit.icon("clear", 30.0, UiTheme.PILL_TEXT)
	status.add_child(weather_icon)
	weather_label = UiKit.label("", "PillLabel", HORIZONTAL_ALIGNMENT_LEFT, false)
	status.add_child(weather_label)
	status_pill.add_child(status)
	# The whole pill is the way to the region map (P1-010).
	var status_button := Button.new()
	status_button.theme_type_variation = "FlatButton"
	status_button.tooltip_text = tr("ui.map.open")
	status_button.focus_mode = Control.FOCUS_ALL
	status_button.pressed.connect(func() -> void: map_pressed.emit())
	status_pill.add_child(status_button)
	status_pill.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(status_pill)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(gap)

	currency_pill = PanelContainer.new()
	currency_pill.theme_type_variation = "PillPanel"
	currency_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	currency_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var money := UiKit.hbox(8)
	money.mouse_filter = Control.MOUSE_FILTER_IGNORE
	money.add_child(UiKit.icon("ripple", 30.0, UiTheme.WATER))
	var ripple_word := UiKit.label(tr("ui.currency.ripple"), "PillLabel", HORIZONTAL_ALIGNMENT_LEFT, false)
	money.add_child(ripple_word)
	ripple_label = UiKit.label("0", "PillLabel", HORIZONTAL_ALIGNMENT_LEFT, false)
	money.add_child(ripple_label)
	money.add_child(UiKit.spacer(0))
	money.add_child(UiKit.icon("memory", 30.0, Color("#bcd99a")))
	var memory_word := UiKit.label(tr("ui.currency.memory"), "PillLabel", HORIZONTAL_ALIGNMENT_LEFT, false)
	money.add_child(memory_word)
	memory_label = UiKit.label("0", "PillLabel", HORIZONTAL_ALIGNMENT_LEFT, false)
	money.add_child(memory_label)
	currency_words = [ripple_word, memory_word]
	currency_pill.add_child(money)
	currency_pill.tooltip_text = "%s · %s" % [tr("ui.currency.ripple"), tr("ui.currency.memory")]
	row.add_child(currency_pill)

	settings_button = UiKit.round_button("settings", tr("ui.button.settings"), func() -> void: settings_pressed.emit())
	row.add_child(settings_button)
	return row

func _build_bottom() -> Control:
	var row := UiKit.hbox(12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	journal_button = UiKit.icon_button("journal", tr("ui.button.journal"), func() -> void: journal_pressed.emit())
	gear_button = UiKit.icon_button("gear", tr("ui.button.gear"), func() -> void: gear_pressed.emit())
	cta_button = Button.new()
	cta_button.theme_type_variation = "WaterButton"
	cta_button.focus_mode = Control.FOCUS_ALL
	# Icon and word centred together, above the band of water (a Button alone pins its icon to an edge).
	var cta_content := UiKit.hbox(14)
	cta_content.alignment = BoxContainer.ALIGNMENT_CENTER
	cta_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cta_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	cta_content.offset_bottom = -20
	cta_content.add_child(UiKit.icon("fish", 58.0, UiTheme.WOOD_TEXT))
	cta_label = UiKit.label(tr("ui.cta.cast"), "CtaLabel", HORIZONTAL_ALIGNMENT_CENTER, false)
	cta_content.add_child(cta_label)
	cta_button.add_child(cta_content)
	cta_button.custom_minimum_size = Vector2(200, UiTheme.TOUCH_MIN_PX)
	cta_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cta_button.size_flags_stretch_ratio = 2.4
	cta_button.button_down.connect(func() -> void: cta_down.emit())
	cta_button.button_up.connect(func() -> void: cta_up.emit())
	camp_button = UiKit.icon_button("camp", tr("ui.button.camp"), func() -> void: camp_pressed.emit())
	for button in [journal_button, gear_button, camp_button]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.clip_text = false
		button.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	camp_button.size_flags_stretch_ratio = 1.3
	journal_dot = UiKit.notice_dot(journal_button)
	camp_dot = UiKit.notice_dot(camp_button)
	row.add_child(journal_button)
	row.add_child(gear_button)
	row.add_child(cta_button)
	row.add_child(camp_button)
	return row

func _build_fishing() -> Control:
	var column := UiKit.vbox(12)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := UiKit.hbox(12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	cancel_button = UiKit.icon_button("close", tr("ui.fishing.cancel"), func() -> void: cancel_pressed.emit())
	cancel_button.size_flags_vertical = Control.SIZE_SHRINK_END
	fishing_journal_button = UiKit.icon_button("fish", tr("ui.fishing.journal"), func() -> void: journal_pressed.emit())
	fishing_journal_button.size_flags_vertical = Control.SIZE_SHRINK_END
	for button in [cancel_button, fishing_journal_button]:
		button.custom_minimum_size.x = 132
	action_button = ReelButton.new()
	action_button.button_down.connect(func() -> void: cta_down.emit())
	action_button.button_up.connect(func() -> void: cta_up.emit())
	var left := Control.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var right := left.duplicate()
	row.add_child(cancel_button)
	row.add_child(left)
	row.add_child(action_button)
	row.add_child(right)
	row.add_child(fishing_journal_button)
	column.add_child(row)
	var tip_pill := PanelContainer.new()
	tip_pill.theme_type_variation = "PillPanel"
	tip_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip_pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tip_label = UiKit.label("", "PillLabel", HORIZONTAL_ALIGNMENT_CENTER, true)
	tip_label.custom_minimum_size.x = 540
	tip_pill.add_child(tip_label)
	column.add_child(tip_pill)
	return column

func setup(fishing: FishingController, region_id: String, weather: WeatherService) -> void:
	_region_id = region_id
	_weather = weather
	EventBus.fishing_state_changed.connect(func(_previous: String, current: String) -> void: set_cta_for_state(current))
	EventBus.game_time_band_changed.connect(func(_band: String) -> void: refresh_status())
	EventBus.weather_changed.connect(func(_weather: String) -> void: refresh_status())
	EventBus.economy_changed.connect(func(_ripple: int, _memory: int) -> void: refresh_currency())
	EventBus.game_state_replaced.connect(refresh_currency)
	fishing.fight_updated.connect(func(_tension: float, progress: float) -> void: action_button.set_progress(progress))
	set_cta_for_state(FishingController.State.keys()[fishing.state].to_lower())
	refresh_status()
	refresh_currency()

## "Quiet Pond | 14:32 | Clear" in the current language.
func refresh_status() -> void:
	region_label.text = tr(ContentDB.get_region(_region_id).get("name_key", ""))
	clock_label.text = clock_text(TimeService.get_hours())
	var weather_id := _weather.current_id if _weather != null else ""
	weather_icon.texture = UiIcons.texture(UiIcons.for_weather(weather_id))
	weather_label.text = tr(ContentDB.get_weather(weather_id).get("name_key", "")) if not weather_id.is_empty() else ""
	status_pill.tooltip_text = "%s · %s · %s" % [region_label.text, tr("ui.time." + TimeService.get_time_band()), weather_label.text]
	_refit()

func refresh_currency() -> void:
	ripple_label.text = format_count(GameState.get_ripple())
	memory_label.text = format_count(GameState.get_memory())
	_refit()

func _refit() -> void:
	if is_inside_tree():
		fit_top_bar(get_viewport_rect().size.x)

## "HH:MM" for a game hour 0..24.
static func clock_text(hours: float) -> String:
	var total := int(floorf(fposmod(hours, 24.0) * 60.0))
	return "%02d:%02d" % [total / 60, total % 60]

## 1240 -> "1,240" (digits grouped by three).
static func format_count(value: int) -> String:
	var digits := str(absi(value))
	var grouped := ""
	while digits.length() > 3:
		grouped = "," + digits.substr(digits.length() - 3) + grouped
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if value < 0 else "") + digits + grouped

func set_cta_for_state(state_name: String) -> void:
	_state_name = state_name
	var entry: Array = CTA_BY_STATE.get(state_name, CTA_BY_STATE["ready"])
	var fishing := state_name in FISHING_STATES
	cta_label.text = tr(entry[0]) if not fishing else tr("ui.cta.cast")
	cta_button.tooltip_text = cta_label.text
	cta_button.disabled = not (state_name in ["ready", "aim"])
	action_button.set_action(tr(entry[0]), "hook" if state_name in ["bite_hint", "hook"] else "reel", entry[1])
	if state_name != "fight":
		action_button.set_progress(0.0)
	var tip_key: String = TIP_BY_STATE.get(state_name, "")
	tip_label.text = tr(tip_key) if not tip_key.is_empty() else ""
	tip_label.get_parent().visible = not tip_key.is_empty()
	# Opening the journal mid-fight would leave the fish unattended: only while waiting. Settings follow
	# the same rule, and restoration (a change to the world, not a look) waits until the line is in.
	var fish_on := state_name in ["bite_hint", "hook", "fight", "land"]
	fishing_journal_button.disabled = fish_on
	settings_button.disabled = fish_on
	restore_button.disabled = fishing
	cancel_button.disabled = state_name == "land"
	_can_fade = state_name == "ready"
	wake()
	apply_visibility()

## Shows exactly the parts that belong on screen now.
func apply_visibility() -> void:
	var shown := not _faded
	var fishing := _state_name in FISHING_STATES
	top_bar.visible = shown and allow_top
	side_column.visible = shown
	bottom_bar.visible = shown and allow_bottom and not fishing and not (_state_name in ["inspect", "release"])
	fishing_bar.visible = shown and fishing

func is_fishing_layout() -> bool:
	return fishing_bar.visible

## A soft "ready" cue for restoration: a dot on the round button and a changed name, so the state is
## never carried by colour alone.
func set_restore_ready(is_ready: bool) -> void:
	restore_button.tooltip_text = tr("ui.button.restore_ready") if is_ready else tr("ui.button.restore")
	restore_dot.visible = is_ready

## Something new to look at in the camp (a decoration that became available).
func set_camp_notice(has_news: bool) -> void:
	camp_dot.visible = has_news
	camp_button.tooltip_text = tr("ui.notice.camp_new") if has_news else ""

## Something new waits in the journal (a species met but not looked at yet).
func set_journal_notice(has_new: bool) -> void:
	journal_dot.visible = has_new
	journal_button.tooltip_text = tr("ui.notice.journal_new") if has_new else ""

## Applies safe-area insets and the minimum touch size (design pixels), and drops optional words from
## the top bar when the screen is too narrow for them (the icons stay; they also carry tooltips).
func apply_layout(top_inset: float, bottom_inset: float, touch_min: float) -> void:
	_set_margins(top_inset, bottom_inset)
	for button in [journal_button, gear_button, camp_button, cancel_button, fishing_journal_button]:
		button.custom_minimum_size.y = touch_min * 1.1
	for button in [settings_button, water_mind_button, restore_button]:
		button.custom_minimum_size = Vector2(touch_min, touch_min)
	cta_button.custom_minimum_size.y = touch_min * 1.3
	action_button.custom_minimum_size = Vector2.ONE * touch_min * 1.75
	fit_top_bar(get_viewport_rect().size.x if is_inside_tree() else 720.0)

## Fits the top row into `available_width` by dropping optional parts in order: the currency words,
## then the weather word, and as a last resort the region name is shortened with an ellipsis. Each
## dropped word is still in the pill's tooltip, and its icon stays.
func fit_top_bar(available_width: float) -> void:
	for word in currency_words:
		word.visible = true
	weather_label.visible = true
	# A label that may trim reports no minimum width, so trimming is only switched on when needed.
	region_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	region_label.clip_text = false
	region_label.custom_minimum_size.x = 0
	var row := top_bar.get_child(0) as Control
	var margins := 32.0
	if row.get_combined_minimum_size().x + margins <= available_width:
		return
	for word in currency_words:
		word.visible = false
	if row.get_combined_minimum_size().x + margins <= available_width:
		return
	weather_label.visible = false
	var overflow := row.get_combined_minimum_size().x + margins - available_width
	if overflow > 0.0:
		var natural := region_label.get_combined_minimum_size().x
		region_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		region_label.clip_text = true
		region_label.custom_minimum_size.x = maxf(48.0, natural - overflow)

func _set_margins(top_inset: float, bottom_inset: float) -> void:
	for side in ["left", "right"]:
		top_bar.add_theme_constant_override("margin_" + side, 16)
		bottom_bar.add_theme_constant_override("margin_" + side, 18)
		fishing_bar.add_theme_constant_override("margin_" + side, 24)
	top_bar.add_theme_constant_override("margin_top", 14 + int(top_inset))
	bottom_bar.add_theme_constant_override("margin_bottom", 22 + int(bottom_inset))
	fishing_bar.add_theme_constant_override("margin_bottom", 18 + int(bottom_inset))
	side_column.offset_top = 14 + top_inset + UiTheme.TOUCH_MIN_PX + 4
	side_column.offset_right = -16
	side_column.offset_left = -16 - UiTheme.TOUCH_MIN_PX

# --- clock and idle fade ---

func is_faded() -> bool:
	return _faded

func _process(delta: float) -> void:
	if top_bar.is_visible_in_tree():
		_clock_timer += delta
		if _clock_timer >= CLOCK_REFRESH_SEC:
			_clock_timer = 0.0
			clock_label.text = clock_text(TimeService.get_hours())
	if _faded or not _can_fade or not visible:
		return
	_idle += delta
	if _idle >= IDLE_FADE_SEC:
		fade_out()

func fade_out() -> void:
	if _faded:
		return
	_faded = true
	if _fade_tween != null:
		_fade_tween.kill()
	if reduced_motion:
		_set_alpha(0.0)
		_hide_if_faded()
		return
	_fade_tween = create_tween()
	_fade_tween.tween_method(_set_alpha, 1.0, 0.0, FADE_TIME)
	_fade_tween.tween_callback(_hide_if_faded)

func _set_alpha(alpha: float) -> void:
	modulate.a = alpha
	# The bars may live outside this node (see UIController), so they fade on their own.
	top_bar.modulate.a = alpha
	bottom_bar.modulate.a = alpha

func _hide_if_faded() -> void:
	# Invisible controls would still catch touches, so hide them for real.
	if _faded:
		apply_visibility()

## Brings the HUD back (any touch) and restarts the idle timer.
func wake() -> void:
	_idle = 0.0
	if not _faded:
		return
	_faded = false
	if _fade_tween != null:
		_fade_tween.kill()
	apply_visibility()
	if reduced_motion:
		_set_alpha(1.0)
	else:
		_fade_tween = create_tween()
		_fade_tween.tween_method(_set_alpha, modulate.a, 1.0, 0.2)

## The large round action button of the fishing row (the mockup's wooden "릴링" disc): its label and
## icon follow the state, and a ring around it fills as the fish comes in, so progress is a shape.
class ReelButton extends Button:
	var progress := 0.0
	var _icon_name := "reel"
	var _styles: Array[ReelStyle] = []

	func _init() -> void:
		theme_type_variation = "FlatButton"
		custom_minimum_size = Vector2(168, 168)
		# The disc is the button's style box, so Button paints the icon and label on top of it.
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			var style := ReelStyle.new()
			style.pressed = state == "pressed"
			style.dimmed = state == "disabled"
			style.focus_ring = state == "focus"
			style.content_margin_top = 34
			style.content_margin_bottom = 30
			_styles.append(style)
			add_theme_stylebox_override(state, style)
		focus_mode = Control.FOCUS_ALL
		vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		expand_icon = true
		add_theme_constant_override("icon_max_width", 64)
		add_theme_color_override("font_color", UiTheme.WOOD_TEXT)
		add_theme_color_override("font_pressed_color", UiTheme.WOOD_TEXT)
		add_theme_color_override("font_hover_color", UiTheme.WOOD_TEXT)
		add_theme_color_override("font_focus_color", UiTheme.WOOD_TEXT)
		add_theme_color_override("font_disabled_color", Color(UiTheme.WOOD_TEXT, 0.6))
		for color_name in ["icon_normal_color", "icon_pressed_color", "icon_hover_color", "icon_focus_color"]:
			add_theme_color_override(color_name, UiTheme.WOOD_TEXT)
		add_theme_color_override("icon_disabled_color", Color(UiTheme.WOOD_TEXT, 0.55))
		icon = UiIcons.texture("reel")

	func set_action(text_value: String, icon_name: String, enabled: bool) -> void:
		text = text_value
		disabled = not enabled
		if icon_name != _icon_name:
			_icon_name = icon_name
			icon = UiIcons.texture(icon_name)
		queue_redraw()

	func set_progress(value: float) -> void:
		var clamped := clampf(value, 0.0, 1.0)
		if absf(clamped - progress) > 0.002:
			progress = clamped
			for style in _styles:
				style.progress = clamped
			queue_redraw()

## The wooden disc with its glow and the landing-progress ring.
class ReelStyle extends StyleBox:
	var progress := 0.0
	var pressed := false
	var dimmed := false
	var focus_ring := false

	func _draw(to_canvas_item: RID, rect: Rect2) -> void:
		var center := rect.get_center()
		var radius := minf(rect.size.x, rect.size.y) * 0.5 - 6.0
		if focus_ring:
			RenderingServer.canvas_item_add_polyline(to_canvas_item, _arc(center, radius + 4.0, 0.0, TAU), PackedColorArray([UiTheme.GOLD]), 4.0, true)
			return
		RenderingServer.canvas_item_add_circle(to_canvas_item, center, radius + 4.0, Color(UiTheme.GOLD, 0.12 if dimmed else 0.35))
		var wood := UiTheme.WOOD_PRESSED if pressed else UiTheme.WOOD
		if dimmed:
			wood = UiTheme.WOOD.lerp(UiTheme.DISABLED, 0.5)
		RenderingServer.canvas_item_add_circle(to_canvas_item, center, radius - 8.0, UiTheme.WOOD_BORDER)
		RenderingServer.canvas_item_add_circle(to_canvas_item, center, radius - 12.0, wood)
		for i in 4:
			var grain := _arc(center, radius * (0.25 + i * 0.16), deg_to_rad(200 + i * 25), deg_to_rad(320 + i * 20))
			RenderingServer.canvas_item_add_polyline(to_canvas_item, grain, PackedColorArray([Color(0.25, 0.14, 0.07, 0.25)]), 2.0, true)
		# Track and landing progress: a ring that fills clockwise from the top.
		RenderingServer.canvas_item_add_polyline(to_canvas_item, _arc(center, radius - 1.0, 0.0, TAU), PackedColorArray([Color(1, 1, 1, 0.3)]), 6.0, true)
		if progress > 0.0:
			RenderingServer.canvas_item_add_polyline(to_canvas_item, _arc(center, radius - 1.0, -PI / 2.0, -PI / 2.0 + TAU * progress),
				PackedColorArray([UiTheme.GOLD]), 8.0, true)

	static func _arc(center: Vector2, radius: float, from: float, to: float) -> PackedVector2Array:
		var points := PackedVector2Array()
		var steps := maxi(8, int(absf(to - from) / TAU * 64.0))
		for s in steps + 1:
			var angle := lerpf(from, to, float(s) / steps)
			points.append(center + Vector2(cos(angle), sin(angle)) * radius)
		return points
