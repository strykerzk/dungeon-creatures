extends Node2D

@export_group("Room Dimensions")
@export var pixel_width: float = 960.0 
@export var pixel_height: float = 540.0

@onready var north_blocker = $DoorBlockers/NorthBlocker
@onready var south_blocker = $DoorBlockers/SouthBlocker
@onready var east_blocker = $DoorBlockers/EastBlocker
@onready var west_blocker = $DoorBlockers/WestBlocker
@onready var camera_trigger = $CameraTrigger

signal player_entered_room(room_center_pos: Vector2)

func _ready() -> void:
	if camera_trigger:
		camera_trigger.body_entered.connect(_on_camera_trigger_body_entered)

func setup(blueprint: DungeonGenerator.RoomBlueprint) -> void:
	if blueprint.doors[Vector2i.UP] and north_blocker: north_blocker.queue_free()
	if blueprint.doors[Vector2i.DOWN] and south_blocker: south_blocker.queue_free()
	if blueprint.doors[Vector2i.RIGHT] and east_blocker: east_blocker.queue_free()
	if blueprint.doors[Vector2i.LEFT] and west_blocker: west_blocker.queue_free()

func _on_camera_trigger_body_entered(body: Node2D) -> void:
	# FIX: Only trigger the camera if the body is a Player AND it's our local player!
	if body is CharacterBody2D and body.name.to_int() == multiplayer.get_unique_id(): 
		player_entered_room.emit(global_position)
