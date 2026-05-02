extends Area2D
class_name LootItem

## Represents a piece of equipment sitting on the dungeon floor.

@export var item_data: EquipmentData

@onready var sprite: Sprite2D = $Sprite2D

var player_in_range: Node2D = null
var hover_time: float = 0.0
var base_y: float = 0.0

func _ready() -> void:
	base_y = sprite.position.y
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	if item_data and item_data.sprite_texture:
		sprite.texture = item_data.sprite_texture

func _process(delta: float) -> void:
	# Simple hovering animation (Sine wave)
	hover_time += delta * 3.0
	sprite.position.y = base_y + sin(hover_time) * 4.0

func _unhandled_input(event: InputEvent) -> void:
	# Check if the player is standing over it and presses the 'interact' button
	if player_in_range and event.is_action_pressed("interact"):
		if not item_data:
			push_error("[LootItem] No item_data assigned to this loot!")
			return
			
		# The player's script handles the 0.5s delay and prevents spamming
		# by checking their own state, so we don't need to lock input here!
		if player_in_range.has_method("try_pickup_item"):
			player_in_range.try_pickup_item(item_data, self)

func _on_body_entered(body: Node2D) -> void:
	# Replace "Player" with whatever your class_name is, or check collision layers
	if body.name == "Player" or body is CharacterBody2D:
		player_in_range = body
		# Visual feedback: Pop scale up slightly when player is near
		create_tween().tween_property(sprite, "scale", Vector2(1.2, 1.2), 0.1)

func _on_body_exited(body: Node2D) -> void:
	if body == player_in_range:
		player_in_range = null
		# Visual feedback: Return to normal scale
		create_tween().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.1)
