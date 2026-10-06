extends Node2D

func _ready() -> void:
	GameState.ensure_initialized()
	SaveService.load_game()
