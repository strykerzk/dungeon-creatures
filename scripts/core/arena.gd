extends Node2D

@export_category("Creature Roster")
@export var creature_roster: Dictionary

@onready var spawn_points: Node2D = $SpawnPoints
@onready var creatures_container: Node2D = $Creatures

var alive_creatures_count: int = 0

func _ready() -> void:
	# Only the Host handles the spawning of fighters
	if multiplayer.is_server():
		call_deferred("_spawn_creatures")

func _spawn_creatures() -> void:
	var peer_ids = CreatureManager.profiles.keys()
	var spawn_markers = spawn_points.get_children()
	
	# NEW: Keep track of loadouts to send to clients
	var all_loadouts: Dictionary = {} 
	
	for i in range(peer_ids.size()):
		var p_id = peer_ids[i]
		var profile: CreatureManager.CreatureProfile = CreatureManager.get_profile(p_id)
		
		var species_key = profile.species
		if not creature_roster.has(species_key):
			push_warning("[Arena] Missing species " + species_key + " in roster! Defaulting to duck")
			species_key = "duck"
		
		# Instantiate the creature
		var scene_to_spawn = creature_roster[species_key] as PackedScene
		var creature_inst = scene_to_spawn.instantiate() as Creature
		
		# Edit the creature
		creature_inst.name = str(p_id) 
		creature_inst.died.connect(_on_creature_died.bind(p_id))
		alive_creatures_count += 1
		
		# Add to the container (The MultiplayerSpawner will automatically replicate this to clients)
		creatures_container.add_child(creature_inst)
		
		# Move them to a spawn marker
		if i < spawn_markers.size():
			creature_inst.global_position = spawn_markers[i].global_position
			
		# Equip the items locally on the Host, and record the paths for the clients
		var serialized_loadout = {}
		for slot in profile.equipped_items:
			var item_data = profile.equipped_items[slot]
			creature_inst.equip(item_data)
			serialized_loadout[slot] = item_data.resource_path
			
		all_loadouts[str(p_id)] = serialized_loadout
		print("[Arena] Spawned creature for Player: ", p_id)

	# Broadcast equipment loadouts to clients so they don't have naked ducks!
	await get_tree().create_timer(0.5).timeout
	rpc("rpc_sync_equipment", all_loadouts)

@rpc("authority", "call_local", "reliable")
func rpc_sync_equipment(all_loadouts: Dictionary) -> void:
	for p_id_str in all_loadouts.keys():
		var creature = creatures_container.get_node_or_null(p_id_str)
		if creature and creature.has_method("equip"):
			var loadout = all_loadouts[p_id_str]
			for slot in loadout.keys():
				var item_data = load(loadout[slot])
				if item_data:
					creature.equip(item_data)

func _on_creature_died(player_id: int) -> void:
	if not multiplayer.is_server(): return
	
	alive_creatures_count -= 1
	print("[Arena] Player ", player_id, "'s creature died! Remaining: ", alive_creatures_count)
	
	# If 1 or 0 creatures are left, the match is over!
	if alive_creatures_count <= 1:
		_end_arena_match()

func _end_arena_match() -> void:
	print("[Arena] Match Over! Transitioning to next round...")
	
	var is_game_over: bool = false
	var overall_winner_id: int = -1
	var max_wins_to_end: int = 3
	
	# 1. Find the survivor and grant them a win
	for child in creatures_container.get_children():
		if child is Creature and child.current_health > 0:
			var winner_id = child.name.to_int()
			
			if typeof(CreatureManager) != TYPE_NIL:
				var profile = CreatureManager.get_profile(winner_id)
				profile.wins += 1
				print("[Arena] Player ", winner_id, " wins the round! Total Wins: ", profile.wins)
				
				# Check the Endgame Condition!
				if profile.wins >= max_wins_to_end:
					is_game_over = true
					overall_winner_id = winner_id
			break 

	# 2. Sync the profiles to all clients
	if typeof(CreatureManager) != TYPE_NIL:
		CreatureManager.sync_all_profiles()

	# 3. Branch the game flow based on the endgame check
	if is_game_over:
		print("[Arena] 👑 PLAYER ", overall_winner_id, " HAS WON THE ENTIRE GAME! 👑")
		await get_tree().create_timer(6.0).timeout
		rpc("rpc_transition_to_menu")
	else:
		await get_tree().create_timer(4.0).timeout
		rpc("rpc_transition_to_dungeon")

@rpc("authority", "call_local", "reliable")
func rpc_transition_to_dungeon() -> void:
	if typeof(StageManager) != TYPE_NIL:
		StageManager.change_stage(StageManager.GameState.DUNGEON)

@rpc("authority", "call_local", "reliable")
func rpc_transition_to_menu() -> void:
	if typeof(StageManager) != TYPE_NIL:
		StageManager.change_stage(StageManager.GameState.MENU)
