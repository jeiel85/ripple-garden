class_name ArtFrameStyle
extends StyleBox

## A drawn UI frame (D-029, ASSET_REQUESTS §5): the picture `ui/<frame>.png` stretched as a 9-slice, so its
## corners keep their shape at any size, or the coded `fallback` box when there is no picture. Either can
## carry decorations from the same request: leaf corners over the four corners and a binding strip down the
## left edge (the journal's rings). UiTheme only builds one when some picture exists, so without art the
## theme keeps its plain boxes.
##
## The picture is drawn scaled: `scale` design px per picture px, or, at 0, as large as the control's
## smaller side allows, so a big master never shows corners larger than the control. `slice` is the
## 9-slice border as fractions of the picture (left, top, right, bottom).

var texture: Texture2D = null
var fallback: StyleBox = null
var slice := Vector4(0.3, 0.3, 0.3, 0.3)
var scale := 0.0
var tint := Color.WHITE
## False leaves the middle of the 9-slice out (the tension meter's frame around the colour band).
var draw_center := true
## Top-left, top-right, bottom-left, bottom-right; null leaves a corner bare.
var corners: Array[Texture2D] = [null, null, null, null]
var corner_size := 56.0
var strip: Texture2D = null
var strip_width := 40.0

## The drawn frame `ui/<frame>.png` with its `slice` and `scale` from `art.json`, or null when not drawn.
static func from_art(frame: String) -> ArtFrameStyle:
	var picture := ArtLibrary.texture("ui", frame)
	if picture == null:
		return null
	var style := ArtFrameStyle.new()
	style.texture = picture
	var data := ArtLibrary.meta("ui", frame)
	var cut: Variant = data.get("slice")
	if typeof(cut) == TYPE_ARRAY and cut.size() == 4:
		style.slice = Vector4(float(cut[0]), float(cut[1]), float(cut[2]), float(cut[3]))
	style.scale = float(data.get("scale", 0.0))
	return style

## The picture's 9-slice border in picture pixels (left, top, right, bottom).
func slice_px() -> Vector4:
	return Vector4(slice.x * texture.get_width(), slice.y * texture.get_height(),
		slice.z * texture.get_width(), slice.w * texture.get_height())

## Design px per picture px when filling `size`: `scale`, but never so large that the slices overlap.
func scale_for(size: Vector2) -> float:
	var border := slice_px()
	var fit := minf(size.x / maxf(1.0, border.x + border.z), size.y / maxf(1.0, border.y + border.w))
	var wanted := scale if scale > 0.0 else minf(size.x / texture.get_width(), size.y / texture.get_height())
	return minf(wanted, fit)

func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	if texture != null:
		var s := scale_for(rect.size)
		if s <= 0.0:
			return
		var border := slice_px()
		# The 9-slice is drawn in picture pixels under a scaling transform, so its corners shrink with it.
		RenderingServer.canvas_item_add_set_transform(to_canvas_item, Transform2D(0.0, Vector2(s, s), 0.0, rect.position))
		RenderingServer.canvas_item_add_nine_patch(to_canvas_item, Rect2(Vector2.ZERO, rect.size / s), Rect2(Vector2.ZERO, texture.get_size()), texture.get_rid(),
			Vector2(border.x, border.y), Vector2(border.z, border.w), RenderingServer.NINE_PATCH_STRETCH, RenderingServer.NINE_PATCH_STRETCH, draw_center, tint)
		RenderingServer.canvas_item_add_set_transform(to_canvas_item, Transform2D.IDENTITY)
	elif fallback != null:
		fallback.draw(to_canvas_item, rect)
	if strip != null:
		var width := minf(strip_width, rect.size.x * 0.2)
		var height := width * strip.get_height() / maxf(1.0, strip.get_width())
		var y := rect.position.y + height * 0.5
		while y + height <= rect.end.y - height * 0.5:
			RenderingServer.canvas_item_add_texture_rect(to_canvas_item, Rect2(rect.position.x - width * 0.5, y, width, height), strip.get_rid(), false, tint)
			y += height
	for i in 4:
		var corner: Texture2D = corners[i]
		if corner == null:
			continue
		var size := Vector2(corner_size, corner_size * corner.get_height() / maxf(1.0, corner.get_width()))
		var at := Vector2(rect.position.x if i % 2 == 0 else rect.end.x, rect.position.y if i < 2 else rect.end.y)
		RenderingServer.canvas_item_add_texture_rect(to_canvas_item, Rect2(at - size * 0.5, size), corner.get_rid(), false, tint)
