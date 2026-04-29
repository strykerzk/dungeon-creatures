extends Node

signal stage_changed(new_state: GameState)

enum GameState { MENU, SELECTION, COMBAT, DUNGEON, EDITOR }

var current_state: GameState = GameState.MENU

var state_scenes: Dictionary = {
	GameState.MENU: "res://scenes/menu.tscn",
	GameState.SELECTION: "res://scenes/stages/selection.tscn",
	GameState.COMBAT: "res://scenes/stages/arena.tscn",
	GameState.DUNGEON: "res://scenes/stages/dungeon.tscn",
	GameState.EDITOR: "res://scenes/stages/editor.tscn"
}

func change_stage(new_state: GameState) -> void:
	current_state = new_state
	
	# Coordinate with other Autoloads
	_prepare_data_for_state(new_state)
	
	if state_scenes.has(new_state):
		get_tree().change_scene_to_file(state_scenes[new_state])
	
	# Notify the rest of the game
	stage_changed.emit(new_state)

func _prepare_data_for_state(state: GameState) -> void:
	match state:
		GameState.COMBAT:
			print("Stage Manager: Loading data for Arena...")
		GameState.DUNGEON:
			print("Stage Manager: Loading Dungeon...")
		GameState.EDITOR:
			print("Stage Manager: Preparing Creature Lab...")

func set_current_state(new_state: GameState) -> void:
	current_state = new_state

func get_current_state() -> GameState:
	return current_state
