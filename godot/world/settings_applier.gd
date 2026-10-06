class_name SettingsApplier
extends RefCounted

## Applies saved settings to the engine and to the nodes that react to them. GameState stores the
## values and announces changes; this is the one place that turns a setting into behaviour
## (frame cap, audio buses, motion flags, presenter quality). Called for every setting when a game is loaded and
## for the changed key afterwards.

## Settings -> audio bus.
const VOLUME_BUSES := {
	"volume_master": "Master", "volume_bgm": "BGM", "volume_water": "Water", "volume_wind": "Wind",
	"volume_wildlife": "Wildlife", "volume_weather": "Weather", "volume_fishing": "Fishing", "volume_camp": "Camp",
}
const BATTERY_SAVER_FPS := 30

var _state: Node
var _camera: CameraController
var _region: RegionRuntime

func _init(game_state: Node, camera: CameraController, region: RegionRuntime) -> void:
	_state = game_state
	_camera = camera
	_region = region

## Applies every setting (after a load or new game).
func apply_all() -> void:
	for key in SaveSchema.SETTING_SPECS:
		apply(key)

func apply(key: String) -> void:
	var value: Variant = _state.get_setting(key)
	if VOLUME_BUSES.has(key):
		AudioService.set_bus_volume_linear(VOLUME_BUSES[key], float(value))
		return
	match key:
		"fps_cap", "battery_saver":
			Engine.max_fps = effective_fps(int(_state.get_setting("fps_cap")), _state.get_setting("battery_saver") == true)
			if key == "battery_saver":
				_apply_presenters()  # fewer raindrops, fewer fish, slower AI
		"quality":
			# Quality scales rain density and the number of swimming fish; GL Compatibility has no 2D MSAA.
			_apply_presenters()
		"reduced_motion":
			_apply_presenters()
			_camera.reduced_motion = value == true
		"camera_shake":
			_camera.shake_enabled = value == true
		"visual_bite_cue":
			_region.fishing_view.visual_bite_cue = value == true
		"high_contrast_meter", "text_scale", "large_ui":
			pass  # applied by the UIController's theme

## The frame cap that results from the player's choice and Battery Saver (which forces 30 fps).
static func effective_fps(fps_cap: int, battery_saver: bool) -> int:
	return mini(fps_cap, BATTERY_SAVER_FPS) if battery_saver else fps_cap

func _apply_presenters() -> void:
	var reduced: bool = _state.get_setting("reduced_motion") == true
	var quality: String = _state.get_setting("quality")
	var battery: bool = _state.get_setting("battery_saver") == true
	_region.environment.set_reduced_motion(reduced)
	_region.weather_presenter.reduced_motion = reduced
	_region.weather_presenter.apply_quality(quality, battery)
	_region.fishing_view.reduced_motion = reduced
	_region.animals.reduced_motion = reduced
	_region.props.reduced_motion = reduced
	_region.fish_presenter.reduced_motion = reduced
	_region.fish_presenter.queue_refresh()
