extends Node

## CreatureManager: The persistent data hub for the entire playthrough.
## Stores creature profiles, accumulated stashes, and round-based limits.

class CreatureProfile:
	var player_id: int
	var species: String = "duck" # Selection happens later
	var major_mutation: MutationData = null
	var minor_mutations: Array[MutationData] = []
	var equipped_items: Dictionary = {} # slot_name: EquipmentData
	var stash: Array[EquipmentData] = [] # All accumulated items from dungeons

# key: player_id (int), value: CreatureProfile
var profiles: Dictionary = {}

# Current round constraints
var current_round: int = 0
var inv_total_limit: int = 3
var inv_type_limit: int = 3

func _ready() -> void:
	update_round_limits(1)

## Sets the constraints for the upcoming Dungeon phase based on the round number
func update_round_limits(round_num: int) -> void:
	current_round = round_num
	match current_round:
		1:
			inv_total_limit = 3
			inv_type_limit = 3 
		2:
			inv_total_limit = 5
			inv_type_limit = 1
		_:
			inv_total_limit = 8
			inv_type_limit = 2

## Creates a new profile for a player joining the game.
## Species is omitted here as it is handled during the SELECTION phase.
func register_player(id: int) -> void:
	var new_profile = CreatureProfile.new()
	new_profile.player_id = id
	profiles[id] = new_profile

func commit_dungeon_loot(id: int, new_loot: Array[EquipmentData]) -> void:
	# FIX: Auto-register the player if they don't exist yet!
	if not profiles.has(id):
		register_player(id)
		
	profiles[id].stash.append_array(new_loot)
	print("[CreatureManager] Player ", id, " stash updated. Total items: ", profiles[id].stash.size())

func get_profile(id: int) -> CreatureProfile:
	# FIX: Ensure a profile exists before trying to return it
	if not profiles.has(id):
		register_player(id)
	return profiles.get(id)
