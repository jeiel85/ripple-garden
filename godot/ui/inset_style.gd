class_name InsetStyle
extends StyleBox

## Draws another style box smaller than the control it decorates. The mockups' status pills and
## round buttons are visually small, but every tap target must stay at least 48 dp (UI_UX §11):
## the control keeps the full touch size and only the picture is inset. With `circle` the inner
## box is drawn as a centred circle (round buttons), whatever the control's aspect ratio.

var inner: StyleBox
var inset := Vector2.ZERO
var circle := false
## Largest diameter of the circle in design pixels (0 = as large as fits).
var max_diameter := 0.0

func _init(p_inner: StyleBox = null, p_inset: Vector2 = Vector2.ZERO, p_circle: bool = false) -> void:
	inner = p_inner
	inset = p_inset
	circle = p_circle

func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	if inner == null:
		return
	inner.draw(to_canvas_item, draw_rect_for(rect))

## The rectangle the picture occupies inside `rect`.
func draw_rect_for(rect: Rect2) -> Rect2:
	var shrunk := rect.grow_individual(-inset.x, -inset.y, -inset.x, -inset.y)
	if not circle:
		return shrunk
	var diameter := minf(shrunk.size.x, shrunk.size.y)
	if max_diameter > 0.0:
		diameter = minf(diameter, max_diameter)
	return Rect2(shrunk.get_center() - Vector2.ONE * diameter / 2.0, Vector2.ONE * diameter)
