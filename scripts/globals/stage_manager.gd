extends Node

signal stage_changed(new_state: GameState)
signal dungeon_time_updated(time_left: int)
signal escape_portal_opened()
signal screen_shake_requested(intensity: float)

enum GameState { MENU, SELECTION, COMBAT, DUNGEON, EDITOR }
enum DungeonEvent { NORMAL, MINOR_MIX, MAJOR_ALTARS, MAJOR_COOP }

@export_category("Round Progression")
var round_config: Dictionary = {
	1: {"size": 5, "event": DungeonEvent.NORMAL, "timer": 0}, # 0 = Disabled
	2: {"size": 5, "event": DungeonEvent.MINOR_MIX, "timer": 100},
	3: {"size": 5, "event": DungeonEvent.MAJOR_ALTARS, "timer": 100}, 
	4: {"size": 7, "event": DungeonEvent.NORMAL, "timer": 120},
	5: {"size": 7, "event": DungeonEvent.MINOR_MIX, "timer": 140},
	6: {"size": 7, "event": DungeonEvent.MAJOR_COOP, "timer": 140},
	7: {"size": 9, "event": DungeonEvent.MINOR_MIX, "timer": 180},
	8: {"size": 9, "event": DungeonEvent.MAJOR_ALTARS, "timer": 180},
	9: {"size": 11, "event": DungeonEvent.MINOR_MIX, "timer": 240}
}

var current_state: GameState = GameState.MENU
var current_round: int = 0
var current_dungeon_event: DungeonEvent = DungeonEvent.NORMAL

# --- MUTATION INFO ---
var mutation_dictionary: Dictionary = {
}

# --- TIMER & EXTRACTION LOGIC ---
var dungeon_time_limit: int = 30
var current_time_left: float = 0.0
var is_timer_active: bool = false
var has_portal_opened: bool = false
var extracted_players: Array[int] = [] # Tracks who is safe
var is_transitioning: bool = false

var state_scenes: Dictionary = {
	GameState.MENU: "res://scenes/menu.tscn",
	GameState.SELECTION: "res://scenes/stages/selection.tscn",
	GameState.COMBAT: "res://scenes/stages/arena.tscn",
	GameState.DUNGEON: "res://scenes/stages/dungeon.tscn",
	GameState.EDITOR: "res://scenes/stages/editor.tscn"
}

func _ready() -> void:
	current_state = GameState.MENU

func _process(delta: float) -> void:
	if current_state == GameState.DUNGEON and is_timer_active:
		if multiplayer.is_server():
			current_time_left -= delta
			
			if int(current_time_left + delta) != int(current_time_left):
				rpc("sync_dungeon_time", int(current_time_left))
			
			if current_time_left <= (dungeon_time_limit * 0.4) and not has_portal_opened:
				has_portal_opened = true
				rpc("rpc_open_escape_portal")
			
			# Timeout Check
			if current_time_left <= 0:
				is_timer_active = false
				_force_dungeon_timeout()

func get_round_settings() -> Dictionary:
	if round_config.has(current_round):
		return round_config[current_round]
	
	# Infinite scaling fallback for rounds 6+
	return {
		"size": 11, 
		"event": DungeonEvent.MINOR_MIX, 
		"timer": max(60, 120 - (current_round * 5))
	}

@rpc("authority", "call_local", "unreliable")
func sync_dungeon_time(time_left: int) -> void:
	dungeon_time_updated.emit(time_left)

@rpc("authority", "call_local", "reliable")
func rpc_open_escape_portal() -> void:
	print("[StageManager] Escape portal is now open in the center!")
	escape_portal_opened.emit()

# --- EARLY EXTRACTION LOGIC ---

@rpc("any_peer", "call_local", "reliable")
func server_player_extracted(peer_id: int) -> void:
	if not multiplayer.is_server(): return
	if is_transitioning: return
	
	if not peer_id in extracted_players:
		extracted_players.append(peer_id)
		print("[StageManager] Player ", peer_id, " is safe. (", extracted_players.size(), "/", NetworkManager.players.size(), ")")
		
		# If everyone is safe, end the dungeon early!
		if extracted_players.size() >= NetworkManager.players.size():
			print("[StageManager] All players safely extracted! Ending phase early.")
			is_timer_active = false
			is_transitioning = true
			# Give players 1.5 seconds to read the "Extracted" feedback
			await get_tree().create_timer(1.5).timeout
			rpc("rpc_transition_to_editor")

func _force_dungeon_timeout() -> void:
	if is_transitioning: return
	print("[StageManager] Dungeon time expired! Forcing extraction...")
	rpc("rpc_execute_timeout_extraction")

@rpc("authority", "call_local", "reliable")
func rpc_execute_timeout_extraction() -> void:
	var my_id = multiplayer.get_unique_id()
	
	# Only penalize players who HAVEN'T extracted yet
	if not my_id in extracted_players:
		var dungeon_root = get_tree().current_scene
		var player_node = dungeon_root.get_node_or_null("Players/" + str(my_id))
		
		if player_node and player_node.has_method("extract_from_dungeon"):
			player_node.extract_from_dungeon(true) 
			
	if multiplayer.is_server():
		await get_tree().create_timer(1.5).timeout
		rpc("rpc_transition_to_editor")

@rpc("authority", "call_local", "reliable")
func rpc_transition_to_editor() -> void:
	change_stage(GameState.EDITOR)

func change_stage(new_state: GameState) -> void:
	current_state = new_state
	
	# Coordinate with other Autoloads
	_prepare_data_for_state(new_state)
	
	if state_scenes.has(new_state):
		get_tree().change_scene_to_file(state_scenes[new_state])
		stage_changed.emit(new_state)
		print("[StageManager] Switched to ", GameState.keys()[new_state])
	else:
		push_error("[StageManager] Scene path not found for state: " + str(new_state))

func _prepare_data_for_state(state: GameState) -> void:
	is_transitioning = false
	match state:
		GameState.MENU:
			current_round = 0
			if typeof(CreatureManager) != TYPE_NIL:
				CreatureManager.reset_session()
			print("Stage Manager: Returned to Main Menu. Session reset.")
		GameState.COMBAT:
			print("Stage Manager: Loading data for Arena...")
			if typeof(CreatureManager) != TYPE_NIL:
				CreatureManager.update_round_limits(current_round)
		GameState.DUNGEON:
			current_round += 1
			print("Stage Manager: Loading Dungeon... Round: ", current_round)
			
			if typeof(CreatureManager) != TYPE_NIL:
				CreatureManager.update_round_limits(current_round)
			
			has_portal_opened = false
			extracted_players.clear()
			_apply_round_settings()
		GameState.EDITOR:
			print("Stage Manager: Preparing Creature Lab...")

func _apply_round_settings() -> void:
	var settings = get_round_settings()
	current_dungeon_event = settings["event"]
	if settings["event"] == DungeonEvent.MINOR_MIX:
		CreatureManager.minor_slot_limit += 1
	
	print("[StageManager] Round ", current_round, " Event: ", DungeonEvent.keys()[current_dungeon_event])
	
	if settings["timer"] > 0:
		is_timer_active = true
		dungeon_time_limit = settings["timer"]
		current_time_left = dungeon_time_limit
		print("[StageManager] Timer ENABLED (", dungeon_time_limit, "s)")
	else:
		is_timer_active = false
		print("[StageManager] Timer DISABLED.")

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


func update_mutation_dictionary(grid_pos: Vector2i, array: Array[MutationData]) -> void:
	if mutation_dictionary.has(grid_pos):
		mutation_dictionary.erase(grid_pos)
	mutation_dictionary[grid_pos] = array
	var safe_paths: Array[String] = []
	for mut in array:
		safe_paths.append(mut.resource_path)
	rpc("sync_mutation_dictionary", grid_pos, safe_paths)

@rpc("any_peer","call_remote","reliable")
func sync_mutation_dictionary(grid_pos: Vector2i, safe_paths: Array[String]) -> void:
	var loaded_mutations: Array[MutationData] = []
	for path in safe_paths:
		loaded_mutations.append(load(path))
	
	mutation_dictionary[grid_pos] = loaded_mutations
