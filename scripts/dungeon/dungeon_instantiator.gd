extends Node2D

@export_group("Standard Room Decks")
@export var center_room_scene: PackedScene
@export var inner_room_scenes: Array[PackedScene]
@export var outer_room_scenes: Array[PackedScene]

@export_group("Event Room Decks")
@export var major_altar_scenes: Array[PackedScene]
@export var minor_altar_scenes: Array[PackedScene]
@export var coop_event_scenes: Array[PackedScene]

@export_group("Generation Settings")
@export var grid_size: int = 5
@export var room_width: float = 960.0 # Updated to your resolution
@export var room_height: float = 540.0 

var generator = DungeonGenerator.new()
@onready var living_camera = $"../LivingCamera" 

func _ready() -> void:
	StageManager.current_dungeon_event = StageManager.DungeonEvent.MAJOR_ALTARS
	build_dungeon()

func build_dungeon() -> void:
	var grid_blueprint = generator.generate_dungeon(grid_size)
	
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
				
				var world_x = (x - generator.center_pos.x) * room_width
				var world_y = (y - generator.center_pos.y) * room_height
				room_instance.position = Vector2(world_x, world_y)
				
				room_instance.setup(blueprint)
				room_instance.player_entered_room.connect(_on_room_entered)
				
				if blueprint.ring_level == 0:
					if living_camera:
						living_camera.global_position = room_instance.global_position

func _on_room_entered(target_pos: Vector2) -> void:
	if not living_camera: return
	var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(living_camera, "global_position", target_pos, 0.4)
