extends Node2D

@export_group("Room Dimensions")
# The pixel size of your room including the walls. 
# Example: 20x15 tiles at 64px = 1280x960
@export var pixel_width: float = 960.0 
@export var pixel_height: float = 540.0

@onready var door_blockers: Node2D = $DoorBlockers
@onready var north_blocker: StaticBody2D = $DoorBlockers/NorthBlocker
@onready var south_blocker: StaticBody2D = $DoorBlockers/SouthBlocker
@onready var east_blocker: StaticBody2D = $DoorBlockers/EastBlocker
@onready var west_blocker: StaticBody2D = $DoorBlockers/WestBlocker
@onready var camera_trigger: Area2D = $CameraTrigger

signal player_entered_room(room_center_pos: Vector2)

func _ready() -> void:
	# Connect the camera tripwire
	if camera_trigger:
		camera_trigger.body_entered.connect(_on_camera_trigger_body_entered)

## Called by the Instantiator right after the room is spawned
func setup(blueprint: DungeonGenerator.RoomBlueprint) -> void:
	# If the blueprint says the door is open, delete the blocker!
	if !door_blockers: return
	
	if blueprint.doors[Vector2i.UP] and north_blocker: 
		north_blocker.queue_free()
	
	if blueprint.doors[Vector2i.DOWN] and south_blocker: 
		south_blocker.queue_free()
		
	if blueprint.doors[Vector2i.RIGHT] and east_blocker: 
		east_blocker.queue_free()
		
	if blueprint.doors[Vector2i.LEFT] and west_blocker: 
		west_blocker.queue_free()

## The Tripwire for the "Living Camera"
func _on_camera_trigger_body_entered(body: Node2D) -> void:
	# Replace "Player" with whatever your class_name is, or check collision layers
	if body.name == "Player" or body is CharacterBody2D: 
		player_entered_room.emit(global_position)
