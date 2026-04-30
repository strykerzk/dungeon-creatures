extends Node

signal stage_changed(new_state: GameState)

enum GameState { MENU, SELECTION, COMBAT, DUNGEON, EDITOR }

var current_state: GameState = GameState.MENU
var current_round: int = 0

var state_scenes: Dictionary = {
	GameState.MENU: "res://scenes/menu.tscn",
	GameState.SELECTION: "res://scenes/stages/selection.tscn",
	GameState.COMBAT: "res://scenes/stages/arena.tscn",
	GameState.DUNGEON: "res://scenes/stages/dungeon.tscn",
	GameState.EDITOR: "res://scenes/stages/editor.tscn"
}

func _ready() -> void:
	current_state = GameState.MENU

func change_stage(new_state: GameState) -> void:
	current_state = new_state
	if current_state == GameState.COMBAT:
		current_round += 1
		print("[StageManager] Starting Round ", current_round)
	
	# Coordinate with other Autoloads
	_prepare_data_for_state(new_state)
	
	if state_scenes.has(new_state):
		get_tree().change_scene_to_file(state_scenes[new_state])
		stage_changed.emit(new_state)
		print("[StageManager] Switched to ", GameState.keys()[new_state])
	else:
		push_error("[StageManager] Scene path not found for state: " + str(new_state))

func _prepare_data_for_state(state: GameState) -> void:
	match state:
		GameState.COMBAT:
			print("Stage Manager: Loading data for Arena...")
		GameState.DUNGEON:
			print("Stage Manager: Loading Dungeon...")
			CreatureManager.update_round_limits(current_round)
		GameState.EDITOR:
			print("Stage Manager: Preparing Creature Lab...")

# Helper to move to the next step in core loop
func advance_loop() -> void:
	match current_state:
		GameState.MENU:
			change_stage(GameState.SELECTION)
		GameState.SELECTION:
			change_stage(GameState.COMBAT)
		GameState.COMBAT:
			change_stage(GameState.DUNGEON)
		GameState.DUNGEON:
			change_stage(GameState.EDITOR)
		GameState.EDITOR:
			change_stage(GameState.COMBAT)

func set_current_state(new_state: GameState) -> void:
	current_state = new_state

func get_current_state() -> GameState:
	return current_state
