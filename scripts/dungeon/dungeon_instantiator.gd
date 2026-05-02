extends Node2D

@export_group("Standard Room Decks")
@export var center_room_scene: PackedScene
@export var inner_room_scenes: Array[PackedScene]
@export var outer_room_scenes: Array[PackedScene]

@export_group("Event Room Decks")
@export var major_altar_scenes: Array[PackedScene]
@export var minor_altar_scenes: Array[PackedScene]
@export var coop_event_scenes: Array[PackedScene]

@export_group("Loot & Spawning")
@export var loot_item_scene: PackedScene
@export var loot_pool: Array[EquipmentData]

@export_group("Generation Settings")
@export var grid_size: int = 5
@export var room_width: float = 960.0 # Updated to your resolution
@export var room_height: float = 540.0 

var generator = DungeonGenerator.new()
@onready var living_camera = $"../LivingCamera" 

func _ready() -> void:
	build_dungeon()

func build_dungeon() -> void:
	var grid_blueprint = generator.generate_dungeon(grid_size)
	var spawned_rooms: Array[Node2D] = []
	
	for x in range(grid_blueprint.size()):
		for y in range(grid_blueprint[x].size()):
			var blueprint = grid_blueprint[x][y]
			var scene_to_spawn: PackedScene = null
			
			# 1. Check if the blueprint specifically requested an Event Room
			match blueprint.template_type:
				"MajorAltar":
					if major_altar_scenes.size() > 0: scene_to_spawn = major_altar_scenes.pick_random()
				"MinorAltar":
					if minor_altar_scenes.size() > 0: scene_to_spawn = minor_altar_scenes.pick_random()
				"CoopRoom":
					if coop_event_scenes.size() > 0: scene_to_spawn = coop_event_scenes.pick_random()
			
			# 2. If it wasn't an event room (or the event decks were empty), fall back to Standard logic
			if scene_to_spawn == null:
				match blueprint.ring_level:
					0: scene_to_spawn = center_room_scene
					1: if inner_room_scenes.size() > 0: scene_to_spawn = inner_room_scenes.pick_random()
					_: if outer_room_scenes.size() > 0: scene_to_spawn = outer_room_scenes.pick_random()
			
			# 3. Instantiate
			if scene_to_spawn:
				var room_instance = scene_to_spawn.instantiate()
				add_child(room_instance)
				spawned_rooms.append(room_instance)
				
				var world_x = (x - generator.center_pos.x) * room_width
				var world_y = (y - generator.center_pos.y) * room_height
				room_instance.position = Vector2(world_x, world_y)
				
				room_instance.setup(blueprint)
				room_instance.player_entered_room.connect(_on_room_entered)
				
				if blueprint.ring_level == 0:
					if living_camera:
						living_camera.global_position = room_instance.global_position

	# 4. Scatter loot now that the physical dungeon is built
	_scatter_loot(spawned_rooms)

func _scatter_loot(rooms: Array[Node2D]) -> void:
	if not loot_item_scene or loot_pool.is_empty():
		push_warning("[DungeonInstantiator] Loot scene or pool is empty. Skipping drops.")
		return
		
	# 1. Map out which rooms have available markers
	# We store dictionaries containing the room and its specific markers
	var eligible_rooms: Array[Dictionary] = []
	var total_markers = 0
	
	for room in rooms:
		var spawns_container = room.get_node_or_null("LootSpawns")
		if spawns_container:
			var markers = []
			for child in spawns_container.get_children():
				if child is Marker2D:
					markers.append(child)
					total_markers += 1
			
			if not markers.is_empty():
				eligible_rooms.append({"room": room, "markers": markers})
					
	if eligible_rooms.is_empty(): 
		return
	
	# 2. Determine target drops based on Round limits
	var current_round = 1
	if typeof(StageManager) != TYPE_NIL:
		current_round = StageManager.current_round
		
	var drop_percentage = 0.20
	if current_round == 2: drop_percentage = 0.50
	elif current_round >= 3: drop_percentage = 0.80
	
	var target_drops = max(1, int(total_markers * drop_percentage))
	var drops_remaining = target_drops
	
	print("[DungeonInstantiator] Target drops: ", target_drops, " across ", eligible_rooms.size(), " eligible rooms.")
	
	# 3. The "Card Dealer" Distribution Loop
	# Deal 1 item to each room before giving any room a 2nd item.
	while drops_remaining > 0 and eligible_rooms.size() > 0:
		# Shuffle the rooms so we don't always favor the top-left of the dungeon
		eligible_rooms.shuffle()
		var rooms_to_remove = []
		
		# Do one pass across all currently eligible rooms
		for i in range(eligible_rooms.size()):
			if drops_remaining <= 0:
				break # We ran out of loot to give!
				
			var room_data = eligible_rooms[i]
			var markers: Array = room_data["markers"]
			
			# Pick a random marker in THIS room and remove it from the array
			markers.shuffle()
			var chosen_marker = markers.pop_back()
			
			# Spawn the loot
			var loot_instance = loot_item_scene.instantiate() as LootItem
			loot_instance.item_data = loot_pool.pick_random()
			chosen_marker.add_child(loot_instance)
			loot_instance.position = Vector2.ZERO
			
			drops_remaining -= 1
			
			# If this room has no more markers, mark it to be ignored on the next pass
			if markers.is_empty():
				rooms_to_remove.append(room_data)
				
		# Clean up full rooms before the next while-loop pass
		for full_room in rooms_to_remove:
			eligible_rooms.erase(full_room)

func _on_room_entered(target_pos: Vector2) -> void:
	if not living_camera: return
	var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(living_camera, "global_position", target_pos, 0.4)
