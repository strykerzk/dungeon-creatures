extends Node2D

## Attach this to a "DungeonBuilder" node inside your main DungeonPhase.tscn

@export_group("Room Decks")
@export var center_room_scene: PackedScene
@export var inner_room_scenes: Array[PackedScene]
@export var outer_room_scenes: Array[PackedScene]

@export_group("Generation Settings")
@export var grid_size: int = 5
# Must match the pixel size you set in the room.gd script
@export var room_width: float = 1280.0 
@export var room_height: float = 960.0 

var generator = DungeonGenerator.new()

# This is the "Living Camera" that will slide around
@onready var living_camera = $"../LivingCamera" # Adjust path based on your scene tree

func _ready() -> void:
	build_dungeon()

func build_dungeon() -> void:
	# 1. Get the pure data blueprint from our generator
	var grid_blueprint = generator.generate_dungeon(grid_size)
	
	# 2. Iterate through every cell
	for x in range(grid_blueprint.size()):
		for y in range(grid_blueprint[x].size()):
			var blueprint = grid_blueprint[x][y]
			var scene_to_spawn: PackedScene = null
			
			# 3. Draw a card from the correct deck based on the Ring Level
			match blueprint.ring_level:
				0: 
					scene_to_spawn = center_room_scene
				1: 
					if inner_room_scenes.size() > 0:
						scene_to_spawn = inner_room_scenes.pick_random()
				_: 
					if outer_room_scenes.size() > 0:
						scene_to_spawn = outer_room_scenes.pick_random()
			
			# 4. Instantiate and Position
			if scene_to_spawn:
				var room_instance = scene_to_spawn.instantiate()
				add_child(room_instance)
				
				# Offset the position so the center room (2,2) spawns at world (0,0)
				var world_x = (x - generator.center_pos.x) * room_width
				var world_y = (y - generator.center_pos.y) * room_height
				room_instance.position = Vector2(world_x, world_y)
				
				# 5. Tell the room to open its doors
				room_instance.setup(blueprint)
				
				# 6. Hook up the camera signal
				room_instance.player_entered_room.connect(_on_room_entered)
				
				# If this is the center room, snap the camera and player here immediately
				if blueprint.ring_level == 0:
					if living_camera:
						living_camera.global_position = room_instance.global_position

func _on_room_entered(target_pos: Vector2) -> void:
	if not living_camera: return
	
	# Create a smooth tween to slide the camera to the new room
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(living_camera, "global_position", target_pos, 0.5)
