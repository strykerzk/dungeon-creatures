extends Node

class CreatureProfile:
	var player_id: int
	var species: String = "duck" 
	var major_mutation: MutationData = null
	var minor_mutations: Array[MutationData] = []
	var equipped_items: Dictionary = {} 
	var stash: Array[EquipmentData] = [] 
	var wins: int = 0 

var profiles: Dictionary = {}

var current_round: int = 0
var inv_total_limit: int = 3
var inv_type_limit: int = 3
var minor_slot_limit: int = 0

func _ready() -> void:
	update_round_limits(1)

func update_round_limits(round_num: int) -> void:
	current_round = round_num
	match current_round:
		1:
			inv_total_limit = 3
			inv_type_limit = 3 
			minor_slot_limit = 0
		2:
			inv_total_limit = 5
			inv_type_limit = 1
		_:
			inv_total_limit = 8
			inv_type_limit = 2

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
	var items_added = 0
	
	# NEW: Filter out items the player already has!
	for item in new_loot:
		var is_duplicate = false
		
		# 1. Check if it's already in the unequipped stash
		for stash_item in profile.stash:
			if stash_item.resource_path == item.resource_path:
				is_duplicate = true
				break
				
		# 2. Check if the creature is currently wearing it
		if not is_duplicate:
			for slot in profile.equipped_items:
				if profile.equipped_items[slot].resource_path == item.resource_path:
					is_duplicate = true
					break
				
		if not is_duplicate:
			profile.stash.append(item)
			items_added += 1
	print("[CreatureManager] Player ", id, " stash updated. Total items: ", profiles[id].stash.size())

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

func reset_session() -> void:
	profiles.clear()
	update_round_limits(1)
	print("[CreatureManager] Session data completely cleared.")
