extends Node

var data: Dictionary = {}

func new_game() -> void:
    data = {
        "save_version": 1,
        "profile": {
            "created_at": int(Time.get_unix_time_from_system()),
            "last_session_at": int(Time.get_unix_time_from_system())
        },
        "economy": {"ripple": 0, "memory": 0},
        "regions": {},
        "collection": {},
        "inventory": {"rods": ["rod_bamboo"], "baits": ["bait_bread"]},
        "settings": {
            "relaxed_hook": false,
            "auto_hook": false,
            "reduced_motion": false,
            "haptics": true,
            "battery_saver": false
        },
        "entitlement_cache": {"full_game": false}
    }

func ensure_initialized() -> void:
    if data.is_empty():
        new_game()
