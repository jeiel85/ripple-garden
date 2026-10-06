class_name FightSimulation
extends RefCounted

## Line-tension fight (GDD §7 FIGHT, BALANCE §1). Pure simulation: no nodes, no clock, no global
## state. The caller feeds it time and whether the player is reeling; all randomness comes from
## the RandomNumberGenerator it is given, so a seed reproduces a fight exactly.
##
## Model:
##  - Holding (reeling) pulls the tension towards `hold_target`, letting go towards
##    `release_target`; the fish adds a temporary pull to that target (strength x behaviour
##    scale, damped by the rod's tension assist). Tension follows its target with a lag, so
##    the player steers rather than twitches.
##  - Inside the safe band the catch progresses at 1 / (duration x duration_scale) per second,
##    so a perfectly played fight takes roughly the fish's `duration_sec`. Outside the band the
##    fish gains a little ground. Progress never fails the fight on its own.
##  - The fight is lost only when the line stays slack or overtight for a grace period; nothing
##    is ever lost permanently (GDD "Failure").

enum Result { ONGOING, LANDED, SLACK, SNAPPED }

var tension := 0.5
var progress := 0.0
var result: Result = Result.ONGOING
## The fish's current contribution to the tension target (+ pulls tighter, - slackens); for views.
var pull_offset := 0.0
var elapsed := 0.0

var _config: Dictionary
var _behavior: Dictionary
var _amplitude: float
var _duration_sec: float
var _rng: RandomNumberGenerator
var _next_pull_in := 0.0
var _pull_left := 0.0
var _pull_sign := 1.0
var _slack_time := 0.0
var _snap_time := 0.0

## `fight_config` is balance.json fishing.fight, `behavior` a behaviors.json entry, `fish_def`
## a fish_catalog entry and `rod_assist` the rod's tension_assist (0..1).
func _init(fish_def: Dictionary, behavior: Dictionary, fight_config: Dictionary,
		rod_assist: float, rng: RandomNumberGenerator) -> void:
	_config = fight_config
	_behavior = behavior
	_rng = rng
	_duration_sec = float(fish_def["fight"]["duration_sec"])
	_amplitude = float(fish_def["fight"]["strength"]) * float(behavior["pull_scale"]) * (1.0 - clampf(rod_assist, 0.0, 1.0))
	progress = float(fight_config["start_progress"])
	_next_pull_in = _roll(behavior["pull_interval_sec"])

func band_min() -> float:
	return float(_config["band"]["min"])

func band_max() -> float:
	return float(_config["band"]["max"])

func in_band() -> bool:
	return tension >= band_min() and tension <= band_max()

## Advances the fight by `delta` seconds. Does nothing once it has ended.
func step(delta: float, holding: bool) -> void:
	if result != Result.ONGOING or delta <= 0.0:
		return
	elapsed += delta
	_update_pull(delta)

	var target := (float(_config["hold_target"]) if holding else float(_config["release_target"])) + pull_offset
	tension = clampf(tension + (target - tension) * (1.0 - exp(-float(_config["response_per_sec"]) * delta)), 0.0, 1.0)

	if in_band():
		progress += delta / (_duration_sec * float(_config["duration_scale"]))
	elif tension > band_max():
		progress -= float(_config["regress_above_band_per_sec"]) * delta
	else:
		progress -= float(_config["regress_below_band_per_sec"]) * delta
	progress = clampf(progress, 0.0, 1.0)

	_slack_time = _slack_time + delta if tension <= float(_config["slack_threshold"]) else maxf(0.0, _slack_time - delta)
	_snap_time = _snap_time + delta if tension >= float(_config["snap_threshold"]) else maxf(0.0, _snap_time - delta)

	if progress >= 1.0:
		result = Result.LANDED
	elif _snap_time >= float(_config["snap_grace_sec"]):
		result = Result.SNAPPED
	elif _slack_time >= float(_config["slack_grace_sec"]):
		result = Result.SLACK

func _update_pull(delta: float) -> void:
	if _pull_left > 0.0:
		_pull_left -= delta
		if _pull_left <= 0.0:
			pull_offset = 0.0
			_next_pull_in = _roll(_behavior["pull_interval_sec"])
		return
	_next_pull_in -= delta
	if _next_pull_in <= 0.0:
		_pull_left = _roll(_behavior["pull_duration_sec"])
		if _behavior["alternate"]:
			_pull_sign = -_pull_sign
		pull_offset = _pull_sign * _amplitude

func _roll(range_def: Dictionary) -> float:
	return _rng.randf_range(float(range_def["min"]), float(range_def["max"]))
