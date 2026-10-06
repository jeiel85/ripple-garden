class_name WorldInput
extends Control

## Touch / mouse on the scenery itself (UI_UX §4):
##   READY      press and drag aims, release casts; a tap is a quick cast; dragging back onto the rod cancels
##   BITE/HOOK  a tap sets the hook
##   FIGHT      holding the screen reels, letting go relaxes the line
## It sits underneath the HUD, so buttons keep their own presses. While the HUD is faded, the first
## touch only wakes it (so waking the screen never casts by accident).
##
## Pointer positions are converted into world coordinates for the aim geometry and the habitat map.

var fishing: FishingController
var region: RegionRuntime
var hud: Hud
var enabled := true
## Last place a line landed, reused by the quick cast and the fishing button.
var last_landing: Variant = null

var _aim: CastAim
var _dragging := false
var _press_world := Vector2.ZERO

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

func setup(p_fishing: FishingController, p_region: RegionRuntime, p_hud: Hud) -> void:
	fishing = p_fishing
	region = p_region
	hud = p_hud
	refresh_aim()
	EventBus.settings_changed.connect(func(_key: String) -> void: refresh_aim())
	EventBus.inventory_changed.connect(refresh_aim)
	EventBus.game_state_replaced.connect(refresh_aim)

## Rebuilds the aim geometry for the equipped rod (reach depends on the rod).
func refresh_aim() -> void:
	var rod := ContentDB.get_rod(GameState.get_equipped_rod())
	_aim = region.cast_aim_for(float(rod.get("range", 0.5)))

func aim() -> CastAim:
	return _aim

func _to_world(screen_position: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_position

func _gui_input(event: InputEvent) -> void:
	if not enabled or not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT:
		if enabled and event is InputEventMouseMotion and _dragging:
			_update_aim(_to_world(event.position))
		return
	if event.pressed:
		_on_press(_to_world(event.position))
	else:
		_on_release(_to_world(event.position))

func _on_press(world_position: Vector2) -> void:
	if hud.is_faded():
		hud.wake()
		return
	hud.wake()
	match fishing.state:
		FishingController.State.READY, FishingController.State.AIM:
			_dragging = true
			_press_world = world_position
			fishing.begin_aim()
			_update_aim(world_position)
		FishingController.State.BITE_HINT, FishingController.State.HOOK:
			fishing.tap()
		FishingController.State.FIGHT:
			fishing.set_reeling(true)

func _on_release(world_position: Vector2) -> void:
	if fishing.state == FishingController.State.FIGHT:
		fishing.set_reeling(false)
	if not _dragging:
		return
	_dragging = false
	region.fishing_view.hide_aim()
	if fishing.state != FishingController.State.AIM:
		return
	if CastAim.is_tap(_press_world, world_position):
		cast_quick()
	elif _aim.is_cancel(world_position):
		fishing.cancel()
	else:
		_cast_at(_aim.landing_for(world_position))

func _update_aim(world_position: Vector2) -> void:
	var landing := _aim.landing_for(world_position)
	var cancelling := _aim.is_cancel(world_position)
	region.fishing_view.show_aim(landing, not cancelling and region.habitat_map.habitat_at(landing) != "")

## The fishing button and a screen tap: cast at the last landing spot, or straight ahead.
func cast_quick() -> bool:
	return _cast_at(_aim.quick_cast_point(last_landing))

func _cast_at(landing: Vector2) -> bool:
	var habitat := region.habitat_map.habitat_at(landing)
	var cast_ok := fishing.cast(landing, habitat)
	if cast_ok:
		last_landing = landing
	return cast_ok
