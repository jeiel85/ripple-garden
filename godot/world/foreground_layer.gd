class_name ForegroundLayer
extends Node2D

## The blurred flowers and grass framing the bottom and sides of the screen in the main-world mockup,
## drawn over the fish, the angler and the line (D-029). It exists only as drawn art
## (`world/<art>_foreground.png`); without that picture the layer draws nothing.

var _texture: Texture2D = null
var _design := Vector2(720, 1280)

func setup(layout: Dictionary) -> void:
	var viewport: Array = layout["viewport"]
	_design = Vector2(float(viewport[0]), float(viewport[1]))
	var art_prefix := String(layout.get("art", ""))
	_texture = null if art_prefix.is_empty() else ArtLibrary.texture("world", art_prefix + "_foreground")
	queue_redraw()

func has_art() -> bool:
	return _texture != null

func _draw() -> void:
	if _texture != null:
		draw_texture_rect(_texture, ArtLibrary.scene_rect(_texture, _design), false)
