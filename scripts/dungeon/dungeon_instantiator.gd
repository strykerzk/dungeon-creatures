extends Node2D

@export_group("UI")
@export var minimap_scene: PackedScene
@export var event_ui_scene: PackedScene
var minimap_instance = null

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

@export_group("Mutations")
var minor_mutation_pool: Array[MutationData] = []
var mutation_draw_deck: Array[MutationData] = []

@export_group("Player Spawning")
@export var player_scene: PackedScene
@export var escape_portal_scene: PackedScene

@export_group("Generation Settings")
@export var grid_size: int = 5
@export var room_width: float = 1920.0 
@export var room_height: float = 1152.0 

var generator = DungeonGenerator.new()
@onready var dungeon_camera: Camera2D = $"../DungeonCamera" 
@onready var players_container: Node2D = $"../Players" # A new Node2D we will create
@onready var bgm_player: AudioStreamPlayer = $"../BGMPlayer"

func _ready() -> void:
	# Ref setup
	var raw_res = FileUtils.load_resources_from_folder("res://resources/mutations/minor/")
	for res in raw_res:
		if res is MutationData:
			minor_mutation_pool.append(res)
	
	
	if typeof(StageManager) != TYPE_NIL:
		StageManager.escape_portal_opened.connect(_on_escape_portal_opened)
		grid_size = StageManager.get_round_settings()["size"]
	
	# Only the Host decides the seed and spawns the players
	if multiplayer.is_server():
		randomize() # Create a truly random seed based on system time
		var dungeon_seed = randi()
		
		# Tell all clients (including the host) to build the dungeon using this exact seed
		rpc("rpc_build_synced_dungeon", dungeon_seed)
		
		# Give the dungeon a frame to physically build, then spawn players
		call_deferred("_spawn_players")
	
	if event_ui_scene:
		var ui_inst = event_ui_scene.instantiate()
		add_child(ui_inst)
	
@rpc("authority", "call_local", "reliable")
func rpc_build_synced_dungeon(dungeon_seed: int) -> void:
	print("[Dungeon] Generating map with synced seed: ", dungeon_seed)
	# Force Godot's RNG to this specific timeline
	seed(dungeon_seed) 
	
	build_dungeon()

func build_dungeon() -> void:
	var grid_blueprint = generator.generate_dungeon(grid_size)
	var spawned_rooms: Array[Node2D] = []
	
	if minimap_scene:
		minimap_instance = minimap_scene.instantiate()
		add_child(minimap_instance)
		minimap_instance.setup(grid_blueprint, generator.center_pos)
	
	for x in range(grid_blueprint.size()):
		for y in range(grid_blueprint[x].size()):
			var blueprint = grid_blueprint[x][y]
			var scene_to_spawn: PackedScene = null
			
			match blueprint.template_type:
				"MajorAltar": if major_altar_scenes.size() > 0: scene_to_spawn = major_altar_scenes.pick_random()
				"MinorAltar": if minor_altar_scenes.size() > 0: scene_to_spawn = minor_altar_scenes.pick_random()
				"CoopRoom": if coop_event_scenes.size() > 0: scene_to_spawn = coop_event_scenes.pick_random()
			
			if scene_to_spawn == null:
				match blueprint.ring_level:
					0: scene_to_spawn = center_room_scene
					1: if inner_room_scenes.size() > 0: scene_to_spawn = inner_room_scenes.pick_random()
					_: if outer_room_scenes.size() > 0: scene_to_spawn = outer_room_scenes.pick_random()
			
			if scene_to_spawn:
				var room_instance = scene_to_spawn.instantiate()
				room_instance.name = "Room_" + str(x) + "_" + str(y)
				add_child(room_instance)
				spawned_rooms.append(room_instance)
				
				var world_x = (x - generator.center_pos.x) * room_width
				var world_y = (y - generator.center_pos.y) * room_height
				room_instance.position = Vector2(world_x, world_y)
				
				room_instance.setup(blueprint)
				room_instance.player_entered_room.connect(_on_room_entered)
				
				if minimap_instance:
					room_instance.room_discovered.connect(minimap_instance.discover_room)

	_scatter_loot(spawned_rooms)
	_assign_minor_orbs()

func _scatter_loot(rooms: Array[Node2D]) -> void:
	if not loot_item_scene or loot_pool.is_empty(): return
		
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
					
	if eligible_rooms.is_empty(): return
	
	var current_round = 1
	if typeof(StageManager) != TYPE_NIL:
		current_round = StageManager.current_round
		
	var drop_percentage = 0.20
	if current_round == 2: drop_percentage = 0.50
	elif current_round >= 3: drop_percentage = 0.80
	
	var target_drops = max(1, int(total_markers * drop_percentage))
	var drops_remaining = target_drops
	
	while drops_remaining > 0 and eligible_rooms.size() > 0:
		eligible_rooms.shuffle()
		var rooms_to_remove = []
		
		for i in range(eligible_rooms.size()):
			if drops_remaining <= 0: break
			var room_data = eligible_rooms[i]
			var markers: Array = room_data["markers"]
			
			markers.shuffle()
			var chosen_marker = markers.pop_back()
			
			var loot_instance = loot_item_scene.instantiate() as LootItem
			loot_instance.item_data = loot_pool.pick_random()
			loot_instance.name = "LootItem"
			chosen_marker.add_child(loot_instance)
			loot_instance.position = Vector2.ZERO
			
			drops_remaining -= 1
			if markers.is_empty():
				rooms_to_remove.append(room_data)
				
		for full_room in rooms_to_remove:
			eligible_rooms.erase(full_room)

func _assign_minor_orbs() -> void:
	# Only the host decides what the orbs contain!
	if not multiplayer.is_server() or minor_mutation_pool.is_empty(): return
	
	# Wait exactly 1 frame to ensure all instantiated rooms have successfully registered their groups!
	await get_tree().process_frame
	
	# Fetch every orb in the entire dungeon via the group
	var orbs = get_tree().get_nodes_in_group("minor_orb")
	for orb in orbs:
		
		# If our draw deck is empty, refill and shuffle it!
		if mutation_draw_deck.is_empty():
			mutation_draw_deck = minor_mutation_pool.duplicate()
			mutation_draw_deck.shuffle()
			
		var chosen_mutation = mutation_draw_deck.pop_back()
		
		# Optional: Skip assignment if we didn't have enough mutations in the pool
		if not chosen_mutation: continue 
		
		orb.mutation_data = chosen_mutation
		orb.setup()
		
		# Tell clients to update this orb!
		rpc("client_sync_orb", orb.get_path(), chosen_mutation.resource_path)

@rpc("authority", "call_local", "reliable")
func client_sync_orb(orb_path: NodePath, mutation_path: String) -> void:
	var orb = get_node_or_null(orb_path)
	if orb is MinorOrb:
		orb.mutation_data = load(mutation_path)
		# Optional polish: Add logic here to tint the orb's sprite based on the mutation!


func _spawn_players() -> void:
	if not player_scene or not players_container: return
	
	# The host loops through all connected players in the lobby
	for peer_id in NetworkManager.players:
		var runner = player_scene.instantiate()
		runner.name = str(peer_id) # CRITICAL: Naming the node the Peer ID sets authority
		players_container.add_child(runner)
		
		# Center room is at (0,0), so we spawn them there
		runner.global_position = Vector2.ZERO 
		print("[Dungeon] Spawned player: ", peer_id)

func _on_room_entered(target_pos: Vector2) -> void:
	if not dungeon_camera: return
	var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(dungeon_camera, "global_position", target_pos, 0.4)

func _on_escape_portal_opened() -> void:
	if not escape_portal_scene:
		push_warning("[Dungeon] Escape Portal scene is missing!")
		return
		
	var portal_instance = escape_portal_scene.instantiate()
	add_child(portal_instance)
	bgm_player.pitch_scale = 1.1
	# Center Room is always built at Vector2.ZERO in our world space!
	portal_instance.global_position = Vector2.ZERO
