extends Node

# A profile represents one player's creature and their vault of items
class CreatureProfile:
	var player_id: int
	var species: String = "none"
	var major_mutation: MutationData = null
	var minor_mutations: Array[MutationData] = []
	var equipped_items: Dictionary = {} # slot_name: EquipmentData
	var stash: Array[EquipmentData] = [] # All accumulated items from dungeons

# player_id (int): CreatureProfile
var profiles: Dictionary = {}

# Current round constraints
var current_round: int = 1
var inv_total_limit: int = 3
var inv_type_limit: int = 3 # Round 1 has no type limit per user request

func _ready() -> void:
	# Initializing round 1 limits
	update_round_limits(1)

## Sets the constraints for the upcoming Dungeon phase based on the round number
func update_round_limits(round_num: int) -> void:
	current_round = round_num
	match current_round:
		1:
			inv_total_limit = 3
			inv_type_limit = 3 # Effectively "no limit" for the 3 slots
		2:
			inv_total_limit = 5
			inv_type_limit = 1
		_:
			inv_total_limit = 8
			inv_type_limit = 2

func register_player(id: int) -> void:
	var new_profile = CreatureProfile.new()
	new_profile.player_id = id
	profiles[id] = new_profile

func commit_dungeon_loot(id: int, new_loot: Array[EquipmentData]) -> void:
	if profiles.has(id):
		profiles[id].stash.append_array(new_loot)
		var array: Array[EquipmentData]
		print("[CreatureManager] Player ", id, " stash updated. Total items: ", profiles[id].stash.size())

func get_profile(id: int) -> CreatureProfile:
	return profiles.get(id)
