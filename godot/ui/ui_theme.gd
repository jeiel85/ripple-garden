class_name UiTheme
extends RefCounted

## The look of every control (UI_UX §1, §9, §11). One Theme is built from the accessibility
## settings and assigned to the UI root, so Text Scale, Large UI and High Contrast apply
## everywhere at once. Colours are placeholder art direction (calm teal panels over the scene).
##
## Sizes are in design pixels of the 720-wide portrait viewport, where 1 dp = 2 px, so the
## 48 dp touch-target guideline is 96 px (120 px with Large UI).

const BASE_FONT_PX := 30
const TOUCH_MIN_PX := 96.0
const TOUCH_MIN_LARGE_PX := 120.0
const LARGE_UI_FONT_FACTOR := 1.15
## Side padding inside buttons: small enough that a four-button row still fits a word like "Journal".
const BUTTON_H_MARGIN := 12

const PANEL := Color(0.07, 0.14, 0.16, 0.86)
const PANEL_HC := Color(0.0, 0.0, 0.0, 0.94)
const BUTTON := Color(0.17, 0.31, 0.33, 0.94)
const BUTTON_HOVER := Color(0.23, 0.40, 0.42, 0.97)
const BUTTON_PRESSED := Color(0.11, 0.22, 0.24, 1.0)
const BUTTON_DISABLED := Color(0.17, 0.25, 0.26, 0.55)
const ACCENT := Color("#e9b44c")
const ACCENT_PRESSED := Color("#c99530")
const TEXT := Color("#f2f7f6")
const TEXT_DIM := Color("#b6c9c8")
const TEXT_DARK := Color("#2a2110")

static func touch_min(large_ui: bool) -> float:
	return TOUCH_MIN_LARGE_PX if large_ui else TOUCH_MIN_PX

static func font_px(text_scale: float, large_ui: bool) -> int:
	return roundi(BASE_FONT_PX * clampf(text_scale, 0.8, 1.6) * (LARGE_UI_FONT_FACTOR if large_ui else 1.0))

static func build(text_scale: float, large_ui: bool, high_contrast: bool) -> Theme:
	var theme := Theme.new()
	theme.default_font_size = font_px(text_scale, large_ui)
	var border := Color.WHITE if high_contrast else Color(1, 1, 1, 0.14)
	var border_width := 3 if high_contrast else 1

	theme.set_stylebox("panel", "PanelContainer", _box(PANEL_HC if high_contrast else PANEL, border, border_width, 28))
	theme.set_stylebox("panel", "Panel", _box(PANEL_HC if high_contrast else PANEL, border, border_width, 28))

	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var color := BUTTON
		match state:
			"hover": color = BUTTON_HOVER
			"pressed": color = BUTTON_PRESSED
			"disabled": color = BUTTON_DISABLED
		var style := _box(color, Color.WHITE if (state == "focus" or high_contrast) else border, 4 if state == "focus" else border_width, 22, 0, BUTTON_H_MARGIN)
		if state == "focus":
			style.bg_color = Color(0, 0, 0, 0)
			style.draw_center = false
		theme.set_stylebox(state, "Button", style)
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", TEXT)
	theme.set_color("font_pressed_color", "Button", TEXT)
	theme.set_color("font_disabled_color", "Button", TEXT_DIM)

	# "primary" is the emphasised action on a screen (e.g. releasing a fish).
	theme.set_type_variation("PrimaryButton", "Button")
	for state in ["normal", "hover", "pressed", "disabled"]:
		var color := ACCENT
		match state:
			"hover": color = ACCENT.lightened(0.12)
			"pressed": color = ACCENT_PRESSED
			"disabled": color = Color(ACCENT, 0.35)
		theme.set_stylebox(state, "PrimaryButton", _box(color, Color.WHITE if high_contrast else Color(1, 1, 1, 0.25), border_width, 22, 0, BUTTON_H_MARGIN))
	for color_name in ["font_color", "font_hover_color", "font_pressed_color"]:
		theme.set_color(color_name, "PrimaryButton", TEXT_DARK)
	theme.set_color("font_disabled_color", "PrimaryButton", Color(TEXT_DARK, 0.55))

	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.55))
	theme.set_constant("shadow_offset_x", "Label", 1)
	theme.set_constant("shadow_offset_y", "Label", 2)
	theme.set_type_variation("DimLabel", "Label")
	theme.set_color("font_color", "DimLabel", TEXT_DIM)
	theme.set_type_variation("TitleLabel", "Label")
	theme.set_font_size("font_size", "TitleLabel", roundi(theme.default_font_size * 1.35))

	theme.set_color("font_color", "CheckButton", TEXT)
	theme.set_color("font_color", "OptionButton", TEXT)
	theme.set_stylebox("normal", "OptionButton", _box(BUTTON, border, border_width, 18))
	theme.set_stylebox("hover", "OptionButton", _box(BUTTON_HOVER, border, border_width, 18))
	theme.set_stylebox("pressed", "OptionButton", _box(BUTTON_PRESSED, border, border_width, 18))
	theme.set_stylebox("slider", "HSlider", _box(Color(1, 1, 1, 0.18), Color(0, 0, 0, 0), 0, 6, 10))
	theme.set_stylebox("grabber_area", "HSlider", _box(ACCENT, Color(0, 0, 0, 0), 0, 6, 10))
	theme.set_stylebox("grabber_area_highlight", "HSlider", _box(ACCENT.lightened(0.15), Color(0, 0, 0, 0), 0, 6, 10))
	return theme

static func _box(color: Color, border: Color, border_width: int, radius: int, height: int = 0, h_margin: int = 20) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = h_margin
	style.content_margin_right = h_margin
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	if height > 0:
		style.content_margin_top = height / 2.0
		style.content_margin_bottom = height / 2.0
	return style
