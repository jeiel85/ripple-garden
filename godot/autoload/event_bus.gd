extends Node

signal fish_encountered(payload: Dictionary)
signal fish_released(payload: Dictionary)
signal collection_changed(fish_id: String)
signal region_restoration_changed(region_id: String, level: int)
signal weather_changed(weather_id: String)
signal game_time_band_changed(time_band: String)
signal save_completed()
signal save_failed(message: String)

func emit_fish_released(payload: Dictionary) -> void:
    fish_released.emit(payload)
