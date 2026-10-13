class_name ForegroundLayer
extends Node2D

## The blurred flowers and grass framing the bottom and sides of the screen in the main-world mockup,
## drawn over the fish, the angler and the line (D-029). It exists only as drawn art
## (`world/<art>_foreground.png`); without that picture the layer draws nothing.
##
## The flowers follow the restoration like the scene behind them: at a barren stage they are dulled
## towards WITHERED_TINT and they regain their colour as the region is restored (the environment's
## restored share, eased with its palette), so a withered pond is never framed by fresh blossoms.

## How the frame looks at restoration stage 0 (multiplied into the picture).
const WITHERED_TINT := Color(0.66, 0.58, 0.46)

var _texture: Texture2D = null
var _design := Vector2(720, 1280)
var _environment: RegionEnvironment = null
var _share := -1.0

func setup(layout: Dictionary, environment: RegionEnvironment = null) -> void:
	_environment = environment
	_follow_restoration()
	var viewport: Array = layout["viewport"]
	_design = Vector2(float(viewport[0]), float(viewport[1]))
	var art_prefix := String(layout.get("art", ""))
	_texture = null if art_prefix.is_empty() else ArtLibrary.texture("world", art_prefix + "_foreground")
	queue_redraw()

func has_art() -> bool:
	return _texture != null

## The tint for a restored share 0..1 (0 = barren, 1 = fully restored).
static func tint_for(share: float) -> Color:
	return WITHERED_TINT.lerp(Color.WHITE, clampf(share, 0.0, 1.0))

func _process(_delta: float) -> void:
	_follow_restoration()

func _follow_restoration() -> void:
	if _environment == null:
		return
	var share := _environment.scene_restored_share()
	if absf(share - _share) > 0.002:
		_share = share
		self_modulate = tint_for(share)

func _draw() -> void:
	if _texture != null:
		draw_texture_rect(_texture, ArtLibrary.scene_rect(_texture, _design), false)
