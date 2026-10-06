class_name UiTheme
extends RefCounted

## The look of every control (UI_UX §1, §9, §11, §13). One Theme is built from the accessibility
## settings and assigned to the UI root, so Text Scale, Large UI and High Contrast apply everywhere
## at once. The palette follows the design mockups (assets/design/mockups, D-018): cream paper cards
## with dark-brown text, wooden boards for the main action, forest green for "chosen" and dark
## translucent pills for the status shown over the scenery.
##
## Sizes are in design pixels of the 720-wide portrait viewport, where 1 dp = 2 px, so the
## 48 dp touch-target guideline is 96 px (120 px with Large UI).
##
## Type variations (set `theme_type_variation`):
##   Button:  PrimaryButton (wood), WaterButton (wood with water, the fishing CTA), GreenButton,
##            TabButton / TabSelected, RoundButton (dark circle over the scenery), PillButton,
##            FlatButton (no box)
##   Panel:   PaperPanel (default), PillPanel, WoodPanel, CardPanel, SelectedCard, NoteCard
##   Label:   DimLabel, TitleLabel, SignLabel (on wood), PillLabel (on dark pills), LightLabel (on scenery),
##            SmallLabel, BigLabel

const BASE_FONT_PX := 30
const TOUCH_MIN_PX := 96.0
const TOUCH_MIN_LARGE_PX := 120.0
const LARGE_UI_FONT_FACTOR := 1.15
## Side padding inside buttons: small enough that a four-button row still fits a word like "Journal".
const BUTTON_H_MARGIN := 12

const CREAM := Color("#f4ecdd")
const CREAM_HOVER := Color("#f9f3e8")
const CREAM_PRESSED := Color("#e6d8bf")
const CREAM_BORDER := Color("#d6c3a0")
const PAPER := Color("#f7f0e3")
const CARD := Color("#fbf6ec")
const INK := Color("#4a3826")
const INK_DIM := Color("#7c6a55")
const WOOD := Color("#8a5a36")
const WOOD_PRESSED := Color("#734a2b")
const WOOD_BORDER := Color("#5e3b22")
const WOOD_TEXT := Color("#fff4e0")
const GREEN := Color("#627d4c")
const GREEN_PRESSED := Color("#4f6a3c")
const GREEN_BORDER := Color("#455c35")
const GREEN_TEXT := Color("#f8f2e4")
const PILL := Color(0.12, 0.14, 0.11, 0.62)
const PILL_BORDER := Color(1.0, 0.96, 0.88, 0.42)
const PILL_TEXT := Color("#fbf4e6")
const GOLD := Color("#e3b24f")
const NOTICE := Color("#e2683f")
const WATER := Color("#7fc3b8")
const DISABLED := Color(0.5, 0.45, 0.38, 0.45)

## Kept for code that colours a single accent (sliders, highlights).
const ACCENT := GREEN
const TEXT := INK
const TEXT_DIM := INK_DIM
const TEXT_DARK := INK

static func touch_min(large_ui: bool) -> float:
	return TOUCH_MIN_LARGE_PX if large_ui else TOUCH_MIN_PX

static func font_px(text_scale: float, large_ui: bool) -> int:
	return roundi(BASE_FONT_PX * clampf(text_scale, 0.8, 1.6) * (LARGE_UI_FONT_FACTOR if large_ui else 1.0))

static func build(text_scale: float, large_ui: bool, high_contrast: bool) -> Theme:
	var theme := Theme.new()
	var font := font_px(text_scale, large_ui)
	theme.default_font_size = font
	var border_width := 4 if high_contrast else 2
	var ink := Color.BLACK if high_contrast else INK

	# --- panels ---
	var paper := _box(PAPER if not high_contrast else Color.WHITE, Color.BLACK if high_contrast else CREAM_BORDER, border_width, 30)
	paper.bg_color.a = 1.0 if high_contrast else 0.97
	_shadow(paper, 10)
	theme.set_stylebox("panel", "PanelContainer", paper)
	theme.set_stylebox("panel", "Panel", paper)
	theme.set_type_variation("PaperPanel", "PanelContainer")
	theme.set_type_variation("CardPanel", "PanelContainer")
	var card := _box(CARD, Color.BLACK if high_contrast else CREAM_BORDER, border_width, 22)
	_shadow(card, 4)
	theme.set_stylebox("panel", "CardPanel", card)
	theme.set_type_variation("SelectedCard", "PanelContainer")
	var selected := _box(Color("#f2f6e6"), GOLD if not high_contrast else Color.BLACK, 4 if not high_contrast else 6, 22)
	_shadow(selected, 4)
	theme.set_stylebox("panel", "SelectedCard", selected)
	theme.set_type_variation("NoteCard", "PanelContainer")
	theme.set_stylebox("panel", "NoteCard", _box(Color("#efe7c9"), Color("#cdbd8f"), border_width, 6))
	theme.set_type_variation("PillPanel", "PanelContainer")
	var pill := _box(Color.BLACK if high_contrast else PILL, Color.WHITE if high_contrast else PILL_BORDER, border_width, 40, 12, 20)
	theme.set_stylebox("panel", "PillPanel", pill)
	theme.set_type_variation("WoodPanel", "PanelContainer")
	var wood_panel := WoodStyle.new(WOOD, WOOD_BORDER, 4 if high_contrast else 3, 26)
	wood_panel.set_margins(26, 14)
	theme.set_stylebox("panel", "WoodPanel", wood_panel)

	# --- buttons: cream card by default ---
	_button_states(theme, "Button", CREAM, CREAM_HOVER, CREAM_PRESSED, Color.BLACK if high_contrast else CREAM_BORDER, border_width, 24, true)
	_font_colors(theme, "Button", ink)
	theme.set_color("icon_normal_color", "Button", ink)
	theme.set_color("icon_hover_color", "Button", ink)
	theme.set_color("icon_pressed_color", "Button", ink)
	theme.set_color("icon_focus_color", "Button", ink)
	theme.set_color("icon_disabled_color", "Button", Color(ink, 0.4))
	theme.set_constant("h_separation", "Button", 10)

	# Wood: the emphasised action on a screen (casting, releasing, "done").
	theme.set_type_variation("PrimaryButton", "Button")
	_wood_states(theme, "PrimaryButton", high_contrast, false)
	_font_colors(theme, "PrimaryButton", WOOD_TEXT)
	_icon_colors(theme, "PrimaryButton", WOOD_TEXT)
	theme.set_type_variation("WaterButton", "Button")
	_wood_states(theme, "WaterButton", high_contrast, true)
	_font_colors(theme, "WaterButton", WOOD_TEXT)
	_icon_colors(theme, "WaterButton", WOOD_TEXT)
	theme.set_font_size("font_size", "WaterButton", roundi(font * 1.35))

	# Green: "this is chosen" (equipped, selected tab, confirm).
	theme.set_type_variation("GreenButton", "Button")
	_button_states(theme, "GreenButton", GREEN, GREEN.lightened(0.08), GREEN_PRESSED, Color.BLACK if high_contrast else GREEN_BORDER, border_width, 24, true)
	_font_colors(theme, "GreenButton", GREEN_TEXT)
	_icon_colors(theme, "GreenButton", GREEN_TEXT)

	# A chosen card in a list (journal fish, equipped item): pale green with a gold-green rim.
	theme.set_type_variation("CardSelected", "Button")
	_button_states(theme, "CardSelected", Color("#f0f5e1"), Color("#f4f8e8"), Color("#e2ebcd"), Color.BLACK if high_contrast else Color("#9cc46a"),
		6 if high_contrast else 4, 24, true)
	_font_colors(theme, "CardSelected", ink)
	_icon_colors(theme, "CardSelected", ink)

	# Tabs: cream when idle, green when selected.
	theme.set_type_variation("TabButton", "Button")
	_button_states(theme, "TabButton", Color("#efe4cf"), CREAM_HOVER, CREAM_PRESSED, Color.BLACK if high_contrast else CREAM_BORDER, border_width, 18, false)
	_font_colors(theme, "TabButton", ink)
	_icon_colors(theme, "TabButton", ink)
	theme.set_type_variation("TabSelected", "Button")
	_button_states(theme, "TabSelected", GREEN, GREEN, GREEN_PRESSED, Color.BLACK if high_contrast else GREEN_BORDER, border_width + (2 if high_contrast else 0), 18, false)
	_font_colors(theme, "TabSelected", GREEN_TEXT)
	_icon_colors(theme, "TabSelected", GREEN_TEXT)

	# Round and pill buttons drawn over the scenery: full-size touch target, smaller picture.
	theme.set_type_variation("RoundButton", "Button")
	for state in ["normal", "hover", "pressed", "disabled"]:
		var color := Color.BLACK if high_contrast else PILL
		match state:
			"hover": color = color.lightened(0.08)
			"pressed": color = Color(0.05, 0.06, 0.05, 0.8)
			"disabled": color = Color(color, 0.3)
		var circle := _box(color, Color.WHITE if high_contrast else PILL_BORDER, border_width + 1, 999)
		var round_style := InsetStyle.new(circle, Vector2(6, 6), true)
		round_style.content_margin_left = 4
		round_style.content_margin_right = 4
		round_style.content_margin_top = 4
		round_style.content_margin_bottom = 4
		theme.set_stylebox(state, "RoundButton", round_style)
	theme.set_stylebox("focus", "RoundButton", InsetStyle.new(_focus_box(999), Vector2(2, 2), true))
	_font_colors(theme, "RoundButton", PILL_TEXT)
	_icon_colors(theme, "RoundButton", PILL_TEXT)
	theme.set_font_size("font_size", "RoundButton", roundi(font * 0.75))

	# Green circle: "done / confirm" floating over the world (camp slot, mockup 06).
	theme.set_type_variation("GreenCircle", "Button")
	for state in ["normal", "hover", "pressed", "disabled"]:
		var green := GREEN
		match state:
			"hover": green = GREEN.lightened(0.08)
			"pressed": green = GREEN_PRESSED
			"disabled": green = GREEN.lerp(DISABLED, 0.5)
		var green_disc := _box(green, Color.WHITE, border_width + 2, 999)
		_shadow(green_disc, 4)
		var green_style := InsetStyle.new(green_disc, Vector2(4, 4), true)
		for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
			green_style.set_content_margin(side, 4)
		theme.set_stylebox(state, "GreenCircle", green_style)
	theme.set_stylebox("focus", "GreenCircle", InsetStyle.new(_focus_box(999), Vector2(2, 2), true))
	_font_colors(theme, "GreenCircle", GREEN_TEXT)
	_icon_colors(theme, "GreenCircle", GREEN_TEXT)
	theme.set_font_size("font_size", "GreenCircle", roundi(font * 0.6))

	# Cream circle with a dark rim: "back" on full-screen pages.
	theme.set_type_variation("CircleButton", "Button")
	for state in ["normal", "hover", "pressed", "disabled"]:
		var color := CREAM
		match state:
			"hover": color = CREAM_HOVER
			"pressed": color = CREAM_PRESSED
			"disabled": color = CREAM.lerp(DISABLED, 0.5)
		var disc := _box(color, Color.BLACK if high_contrast else INK, border_width + 2, 999)
		_shadow(disc, 4)
		var circle_style := InsetStyle.new(disc, Vector2(6, 6), true)
		for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
			circle_style.set_content_margin(side, 4)
		theme.set_stylebox(state, "CircleButton", circle_style)
	theme.set_stylebox("focus", "CircleButton", InsetStyle.new(_focus_box(999), Vector2(2, 2), true))
	_font_colors(theme, "CircleButton", ink)
	_icon_colors(theme, "CircleButton", ink)

	theme.set_type_variation("PillButton", "Button")
	for state in ["normal", "hover", "pressed", "disabled"]:
		var color := Color.BLACK if high_contrast else PILL
		if state == "pressed":
			color = Color(0.05, 0.06, 0.05, 0.8)
		var inner := _box(color, Color.WHITE if high_contrast else PILL_BORDER, border_width, 40, 18, 6)
		var pill_style := InsetStyle.new(inner, Vector2(0, 14))
		pill_style.content_margin_left = 22
		pill_style.content_margin_right = 22
		pill_style.content_margin_top = 18
		pill_style.content_margin_bottom = 18
		theme.set_stylebox(state, "PillButton", pill_style)
	theme.set_stylebox("focus", "PillButton", InsetStyle.new(_focus_box(40), Vector2(0, 10)))
	_font_colors(theme, "PillButton", PILL_TEXT)
	_icon_colors(theme, "PillButton", PILL_TEXT)
	theme.set_font_size("font_size", "PillButton", roundi(font * 0.8))

	theme.set_type_variation("FlatButton", "Button")
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "disabled"]:
		theme.set_stylebox(state, "FlatButton", empty)
	_font_colors(theme, "FlatButton", ink)
	_icon_colors(theme, "FlatButton", ink)

	# --- labels ---
	theme.set_color("font_color", "Label", ink)
	theme.set_type_variation("DimLabel", "Label")
	theme.set_color("font_color", "DimLabel", Color.BLACK if high_contrast else INK_DIM)
	theme.set_type_variation("SmallLabel", "Label")
	theme.set_color("font_color", "SmallLabel", Color.BLACK if high_contrast else INK_DIM)
	theme.set_font_size("font_size", "SmallLabel", roundi(font * 0.8))
	theme.set_type_variation("TitleLabel", "Label")
	theme.set_font_size("font_size", "TitleLabel", roundi(font * 1.35))
	theme.set_type_variation("BigLabel", "Label")
	theme.set_font_size("font_size", "BigLabel", roundi(font * 1.7))
	theme.set_type_variation("SignLabel", "Label")
	theme.set_color("font_color", "SignLabel", WOOD_TEXT)
	theme.set_color("font_shadow_color", "SignLabel", Color(0.2, 0.1, 0.03, 0.6))
	theme.set_constant("shadow_offset_x", "SignLabel", 0)
	theme.set_constant("shadow_offset_y", "SignLabel", 2)
	theme.set_font_size("font_size", "SignLabel", roundi(font * 1.5))
	theme.set_type_variation("CtaLabel", "Label")
	theme.set_color("font_color", "CtaLabel", WOOD_TEXT)
	theme.set_color("font_shadow_color", "CtaLabel", Color(0.2, 0.1, 0.03, 0.55))
	theme.set_constant("shadow_offset_y", "CtaLabel", 2)
	theme.set_font_size("font_size", "CtaLabel", roundi(font * 1.45))
	theme.set_type_variation("PillLabel", "Label")
	theme.set_color("font_color", "PillLabel", PILL_TEXT)
	theme.set_font_size("font_size", "PillLabel", roundi(font * 0.8))
	theme.set_type_variation("LightLabel", "Label")
	theme.set_color("font_color", "LightLabel", PILL_TEXT)
	theme.set_color("font_shadow_color", "LightLabel", Color(0, 0, 0, 0.6))
	theme.set_constant("shadow_offset_x", "LightLabel", 1)
	theme.set_constant("shadow_offset_y", "LightLabel", 2)
	theme.set_constant("shadow_outline_size", "LightLabel", 4)

	# --- inputs ---
	theme.set_color("font_color", "CheckButton", ink)
	theme.set_color("font_hover_color", "CheckButton", ink)
	theme.set_color("font_pressed_color", "CheckButton", ink)
	theme.set_color("font_focus_color", "CheckButton", ink)
	theme.set_color("font_hover_pressed_color", "CheckButton", ink)
	theme.set_icon("checked", "CheckButton", UiIcons.theme_texture("theme_toggle_on"))
	theme.set_icon("unchecked", "CheckButton", UiIcons.theme_texture("theme_toggle_off"))
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		theme.set_stylebox(state, "CheckButton", _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 18, 0, 6))
	theme.set_stylebox("focus", "CheckButton", _focus_box(18))

	_button_states(theme, "OptionButton", CREAM, CREAM_HOVER, CREAM_PRESSED, Color.BLACK if high_contrast else CREAM_BORDER, border_width, 18, false)
	_font_colors(theme, "OptionButton", ink)
	theme.set_icon("arrow", "OptionButton", UiIcons.theme_texture("theme_arrow"))
	theme.set_stylebox("panel", "PopupMenu", _box(CARD, CREAM_BORDER, 2, 18))
	theme.set_stylebox("hover", "PopupMenu", _box(Color("#e9e0c9"), Color(0, 0, 0, 0), 0, 12))
	theme.set_color("font_color", "PopupMenu", ink)
	theme.set_color("font_hover_color", "PopupMenu", ink)
	# Rows of the drop-down list are touch targets too: 30 px text plus padding reaches ~96 px.
	theme.set_constant("v_separation", "PopupMenu", 48)

	theme.set_stylebox("slider", "HSlider", _box(Color("#dccdae"), Color(0, 0, 0, 0), 0, 8, 12))
	theme.set_stylebox("grabber_area", "HSlider", _box(GREEN, Color(0, 0, 0, 0), 0, 8, 12))
	theme.set_stylebox("grabber_area_highlight", "HSlider", _box(GREEN.lightened(0.12), Color(0, 0, 0, 0), 0, 8, 12))
	theme.set_stylebox("background", "ProgressBar", _box(Color("#e2d5bb"), CREAM_BORDER, 1, 12, 0, 0))
	theme.set_stylebox("fill", "ProgressBar", _box(GREEN, Color(0, 0, 0, 0), 0, 12, 0, 0))
	theme.set_color("font_color", "ProgressBar", ink)
	theme.set_color("font_color", "SpinBox", ink)
	theme.set_stylebox("normal", "LineEdit", _box(CARD, CREAM_BORDER, border_width, 14))
	theme.set_color("font_color", "LineEdit", ink)
	return theme

static func _button_states(theme: Theme, type: String, normal: Color, hover: Color, pressed: Color, border: Color,
		border_width: int, radius: int, shadow: bool) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var color := normal
		match state:
			"hover": color = hover
			"pressed": color = pressed
			"disabled": color = normal.lerp(DISABLED, 0.5)
		var style := _box(color, border, border_width, radius, 0, BUTTON_H_MARGIN)
		if shadow and state != "pressed":
			_shadow(style, 4)
		theme.set_stylebox(state, type, style)
	theme.set_stylebox("focus", type, _focus_box(radius))

static func _wood_states(theme: Theme, type: String, high_contrast: bool, water: bool) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var color := WOOD
		match state:
			"hover": color = WOOD.lightened(0.07)
			"pressed": color = WOOD_PRESSED
			"disabled": color = WOOD.lerp(DISABLED, 0.55)
		var style := WoodStyle.new(color, Color.BLACK if high_contrast else WOOD_BORDER, 4 if high_contrast else 3, 28)
		style.water = water and state != "disabled"
		style.water_color = WATER
		style.set_margins(BUTTON_H_MARGIN + 6, 14)
		if water:
			style.content_margin_bottom = 22  # keep the label above the water band
		theme.set_stylebox(state, type, style)
	theme.set_stylebox("focus", type, _focus_box(28))

static func _font_colors(theme: Theme, type: String, color: Color) -> void:
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		theme.set_color(color_name, type, color)
	theme.set_color("font_disabled_color", type, Color(color, 0.5))

static func _icon_colors(theme: Theme, type: String, color: Color) -> void:
	for color_name in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color", "icon_hover_pressed_color"]:
		theme.set_color(color_name, type, color)
	theme.set_color("icon_disabled_color", type, Color(color, 0.45))

## Keyboard / game-pad focus: a clear ring, never a fill, so it reads on every background.
static func _focus_box(radius: int) -> StyleBoxFlat:
	var style := _box(Color(0, 0, 0, 0), GOLD, 5, radius)
	style.draw_center = false
	style.expand_margin_left = 3
	style.expand_margin_right = 3
	style.expand_margin_top = 3
	style.expand_margin_bottom = 3
	return style

static func _shadow(style: StyleBoxFlat, size: int) -> void:
	style.shadow_color = Color(0.2, 0.13, 0.05, 0.22)
	style.shadow_size = size
	style.shadow_offset = Vector2(0, size * 0.5)

static func _box(color: Color, border: Color, border_width: int, radius: int, height: int = 0, h_margin: int = 20) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.anti_aliasing = true
	style.content_margin_left = h_margin
	style.content_margin_right = h_margin
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	if height > 0:
		style.content_margin_top = height / 2.0
		style.content_margin_bottom = height / 2.0
	return style
