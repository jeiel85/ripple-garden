class_name GameRoot
extends Node

## The main scene (TECH_SPEC §2): loads the save, builds the region for the vertical slice, wires the
## controllers and presenters together and hands the UI what it needs. Nothing here holds game
## state; it connects things and forwards events (restoration -> world change, release -> a
## fish appears in the pond, settings -> engine behaviour).

## Tests and tools turn this off: the scene then starts from whatever GameState already holds
## (a new game if none) and never touches the player's save file.
var load_save := true

var region_id := ""
var restoration: RestorationService
var journal: JournalModel
var debug: DebugService = null
var settings: SettingsApplier
var loadout: LoadoutService
var hints: TutorialHints

@onready var region: RegionRuntime = $World/RegionRuntime
@onready var fishing: FishingController = $FishingController
@onready var feedback: FishingFeedback = $FishingFeedback
@onready var ambient_audio: AmbientAudio = $AmbientAudio
@onready var camera: CameraController = $CameraController
@onready var ui: UIController = $UIController

func _ready() -> void:
	_pick_language()
	region_id = ContentDB.balance["vertical_slice"]["region_id"]
	if load_save:
		SaveService.load_game()
	else:
		GameState.ensure_initialized()
	restoration = RestorationService.new(GameState, ContentDB.progression["restoration_points"], ContentDB.balance["vertical_slice"])
	journal = JournalModel.new(ContentDB.balance["journal"]["reveal_at_encounters"])
	loadout = LoadoutService.new(GameState)
	hints = TutorialHints.new(GameState, region_id)

	if not region.setup(region_id, GameState.get_restoration_level(region_id), TimeService.get_time_band()):
		return
	fishing.region_id = region_id
	fishing.loadout = loadout
	fishing.context_provider = _fishing_context
	if load_save:
		# A landed fish and its release reach the disk at once (tests and tools leave this unset).
		fishing.save_hook = SaveService.save_if_dirty
	region.fishing_view.setup(fishing, region.rod_origin(), region.angler_position())
	ambient_audio.setup(region_id, region.weather)
	fishing.state_changed.connect(_on_fishing_state_changed)

	if BuildProfile.debug_tools_enabled():
		debug = DebugService.new(fishing, region.weather, TimeService, GameState, SaveService, restoration)
	settings = SettingsApplier.new(GameState, camera, region)
	settings.apply_all()

	ui.setup({
		"fishing": fishing, "region": region, "restoration": restoration, "journal": journal,
		"loadout": loadout, "hints": hints, "debug": debug, "region_id": region_id,
	})

	EventBus.settings_changed.connect(settings.apply)
	EventBus.game_state_replaced.connect(_on_state_replaced)
	EventBus.region_restoration_changed.connect(_on_restoration_changed)
	EventBus.fish_released.connect(_on_fish_released)
	EventBus.fish_escaped.connect(_on_fish_escaped)
	# Keepsakes whose moment came while an older build was running arrive now.
	loadout.grant_keepsakes()
	# A fish caught but not released before the last exit is waiting to be inspected.
	fishing.resume_pending_catch()

## KO and EN are translated; any other system language falls back to English until JA arrives (P1-013).
func _pick_language() -> void:
	var language := OS.get_locale_language()
	TranslationServer.set_locale(language if language in ["ko", "en"] else "en")

func _fishing_context() -> Dictionary:
	return {"time_band": TimeService.get_time_band(), "weather_id": region.weather.current_id}

func _on_fishing_state_changed(_previous: int, current: int) -> void:
	var line_out := current in [FishingController.State.CAST, FishingController.State.WAIT, FishingController.State.BITE_HINT,
		FishingController.State.HOOK, FishingController.State.FIGHT]
	region.fish_presenter.focus = fishing.landing if line_out else Vector2(-100000, -100000)

func _on_state_replaced() -> void:
	settings.apply_all()
	region.apply_level(GameState.get_restoration_level(region_id), false)

func _on_restoration_changed(changed_region: String, level: int) -> void:
	if changed_region != region_id:
		return
	region.apply_level(level, true)
	camera.restoration_pulse()
	loadout.grant_keepsakes()  # a restored stage may be the moment a keepsake was waiting for

## A snapped line gives the camera a small jolt (Camera Shake setting and Reduced Motion are
## honoured by the camera itself). Slack or a missed hook is quiet: failure stays gentle.
func _on_fish_escaped(_fish_id: String, reason: String) -> void:
	if reason == "line_snapped":
		camera.shake()

func _on_fish_released(fish_id: String, released_region: String, _size_cm: float) -> void:
	if released_region == region_id:
		region.fish_presenter.welcome_released_fish(fish_id, fishing.landing)
