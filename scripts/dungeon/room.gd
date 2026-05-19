extends Node2D

@export_group("Room Dimensions")
@export var pixel_width: float = 1920.0 
@export var pixel_height: float = 1152.0

@onready var north_blocker = $DoorBlockers/NorthBlocker
@onready var south_blocker = $DoorBlockers/SouthBlocker
@onready var east_blocker = $DoorBlockers/EastBlocker
@onready var west_blocker = $DoorBlockers/WestBlocker
@onready var camera_trigger = $CameraTrigger
@onready var fog_of_war: ColorRect = get_node_or_null("FogOfWar")

signal player_entered_room(room_center_pos: Vector2)
signal room_discovered(grid_pos: Vector2i)

var grid_pos: Vector2i

func _enter_tree() -> void:
	y_sort_enabled = true

func _ready() -> void:
	if camera_trigger:
		camera_trigger.body_entered.connect(_on_camera_trigger_body_entered)
		
	# NEW: Initialize Fog Size and Color to perfectly cover the room
	if fog_of_war:
		fog_of_war.size = Vector2(pixel_width, pixel_height)
		# Assuming your room is built outwards from (0,0) in the center
		fog_of_war.position = Vector2(-pixel_width / 2.0, -pixel_height / 2.0)
		fog_of_war.color = Color.BLACK

func setup(blueprint: DungeonGenerator.RoomBlueprint) -> void:
	grid_pos = blueprint.grid_pos
	if blueprint.doors[Vector2i.UP] and north_blocker: north_blocker.queue_free()
	if blueprint.doors[Vector2i.DOWN] and south_blocker: south_blocker.queue_free()
	if blueprint.doors[Vector2i.RIGHT] and east_blocker: east_blocker.queue_free()
	if blueprint.doors[Vector2i.LEFT] and west_blocker: west_blocker.queue_free()

func _on_camera_trigger_body_entered(body: Node2D) -> void:
	# FIX: Only trigger the camera if the body is a Player AND it's our local player!
	if body is CharacterBody2D and body.name.to_int() == multiplayer.get_unique_id(): 
		player_entered_room.emit(global_position)
		
		if fog_of_war and fog_of_war.visible:
			room_discovered.emit(grid_pos)
			var tween = create_tween()
			tween.tween_property(fog_of_war, "modulate:a", 0.0, 0.4).set_ease(Tween.EASE_OUT)
			tween.tween_callback(fog_of_war.hide)
