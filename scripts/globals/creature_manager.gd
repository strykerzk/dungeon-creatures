extends Node

class CreatureProfile:
	var player_id: int
	var species: String = "duck" 
	var major_mutation: MutationData = null
	var minor_mutations: Array[MutationData] = []
	var equipped_items: Dictionary = {} 
	var stash: Array[EquipmentData] = [] 
	var wins: int = 0 
	var custom_sounds: Dictionary = {} # String -> AudioStreamWAV
	var sound_pitches: Dictionary = { # String -> float (pitch_scale)
		"hurt": 1.0,
		"attack": 1.0,
		"dodge": 1.0,
		"death": 1.0
	}
	var player_color: Color = Color.WHITE
	
	func has_custom_sound(sound_name: String) -> bool:
		return custom_sounds.has(sound_name) and custom_sounds[sound_name] != null
	
	func set_custom_sound(sound_name: String, stream: AudioStreamWAV, pitch: float = 1.0) -> void:
		custom_sounds[sound_name] = stream
		sound_pitches[sound_name] = clamp(pitch, 0.5, 2.0)
	
	func clear_custom_sounds() -> void:
		custom_sounds.clear()
		sound_pitches = {"hurt": 1.0, "attack": 1.0, "dodge": 1.0, "death": 1.0}

var profiles: Dictionary = {}
var claimed_colors: Dictionary = {}

var default_species: String = "duck"

var current_round: int = 0
var inv_total_limit: int = 3
var inv_type_limit: int = 3
var minor_slot_limit: int = 0

func _ready() -> void:
	update_round_limits(1)

func update_round_limits(round_num: int) -> void:
	current_round = round_num
	match current_round:
		0, 1:
			inv_total_limit = 3
			inv_type_limit = 1 
			minor_slot_limit = 0
		2, 3:
			inv_total_limit = 5
			inv_type_limit = 2
		_:
			inv_total_limit = 8
			inv_type_limit = 3

func get_player_inv_limit(id: int) -> int:
	var base_limit = inv_total_limit
	if not profiles.has(id): return base_limit
	
	var my_wins = profiles[id].wins
	var min_wins = my_wins
	for p_id in profiles:
		if profiles[p_id].wins < min_wins:
			min_wins = profiles[p_id].wins
			
	var win_diff = my_wins - min_wins
	return max(1, base_limit - win_diff) 

func register_player(id: int) -> void:
	var new_profile = CreatureProfile.new()
	new_profile.player_id = id
	profiles[id] = new_profile

func commit_dungeon_loot(id: int, new_loot: Array[EquipmentData]) -> void:
	if not profiles.has(id):
		register_player(id)
		
	var profile = profiles[id]
	
	# NEW: Filter out items the player already has!
	for item in new_loot:
		if item.original_path == "":
			item.original_path = item.resource_path
		
		profile.stash.append(item)
	
	print("[CreatureManager] Player ", id, " stash updated. Total items: ", profiles[id].stash.size())
	
	_auto_fuse_stash(id)

func _auto_fuse_stash(id: int) -> void:
	var profile = profiles[id]
	var stash = profile.stash
	var fused_something = false
	
	# Dictionary to count items by their original path AND star level
	# Format: {"res://item.tres_1": [item1, item2, item3]}
	var groupings = {}
	
	for item in stash:
		var key = item.original_path + "_" + str(item.star_level)
		if not groupings.has(key):
			groupings[key] = []
		groupings[key].append(item)
		
	# Check for triplets
	for key in groupings.keys():
		var identical_items: Array = groupings[key]
		
		# If we have 3 of the exact same item at the exact same star level (and it's not maxed)
		if identical_items.size() >= 3 and identical_items[0].star_level < 3 and not identical_items[0].is_corrupted:
			
			# 1. Remove the 3 base items from the stash
			stash.erase(identical_items[0])
			stash.erase(identical_items[1])
			stash.erase(identical_items[2])
			
			# 2. Create the upgraded item
			var upgraded_item = identical_items[0].duplicate(true)
			upgraded_item.star_level += 1
			
			# 3. Add it to the stash
			stash.append(upgraded_item)
			fused_something = true
			
			print("[Forge] Fused 3x into a Level ", upgraded_item.star_level, " ", upgraded_item.item_name, "!")
			
	# If we fused something, run it again recursively in case we just made three 2-stars!
	if fused_something:
		_auto_fuse_stash(id)

func get_profile(id: int) -> CreatureProfile:
	if not profiles.has(id):
		register_player(id)
	return profiles.get(id)

# --- NEW: ROBUST NETWORK SYNCING ---

## The Host calls this to bundle everyone's basic data into a safe Dictionary
func sync_all_profiles() -> void:
	if not multiplayer.is_server(): return
	
	var sync_data: Dictionary = {}
	for p_id in profiles.keys():
		sync_data[p_id] = {
			"species": profiles[p_id].species,
			"wins": profiles[p_id].wins
		}
		
	# Beam the safe dictionary to all clients
	rpc("client_receive_profiles", sync_data)

## Clients unpack the dictionary and update their local profiles
@rpc("authority", "call_local", "reliable")
func client_receive_profiles(sync_data: Dictionary) -> void:
	for p_id in sync_data.keys():
		var profile = get_profile(p_id) # Creates it if it doesn't exist!
		profile.species = sync_data[p_id]["species"]
		profile.wins = sync_data[p_id]["wins"]
		print("[CreatureManager] Synced Player ", p_id, " | Species: ", profile.species, " | Wins: ", profile.wins)

@rpc("any_peer", "call_local", "reliable")
func rpc_receive_peer_sound(player_id: int, slot: String, 
							 raw: PackedByteArray, pitch: float) -> void:
	var profile = get_profile(player_id)
	if not profile:
		push_warning("[CreatureManager] No profile for player ", player_id,
					 " when receiving sound.")
		return
	var stream = AudioRecorder.bytes_to_wav(raw, AudioRecorder.sample_rate)
	profile.set_custom_sound(slot, stream, pitch)
	print("[Audio] Received '", slot, "' for player ", player_id,
		  " (", raw.size() / 1024, " KB)")

func is_color_claimed(color_index: int) -> bool:
	return color_index in claimed_colors.values()

func claim_color(player_id: int, color_index: int, color: Color) -> void:
	# Release any previous claim this player held
	claimed_colors.erase(player_id)
	claimed_colors[player_id] = color_index
	var profile = get_profile(player_id)
	if profile:
		profile.player_color = color

func release_color(player_id: int) -> void:
	claimed_colors.erase(player_id)

# Call this inside your existing reset_session()
func reset_colors() -> void:
	claimed_colors.clear()
	for id in profiles:
		profiles[id].player_color = Color.WHITE

func reset_session() -> void:
	profiles.clear()
	for id in profiles:
		profiles[id].clear_custom_sounds()
	update_round_limits(1)
	print("[CreatureManager] Session data completely cleared.")
