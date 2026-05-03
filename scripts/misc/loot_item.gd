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
	
	# Optional: If your EquipmentData has a texture variable, assign it automatically
	if item_data and item_data.sprite_texture:
		sprite.texture = item_data.sprite_texture

func _process(delta: float) -> void:
	# Simple hovering animation (Sine wave)
	hover_time += delta * 3.0
	sprite.position.y = base_y + sin(hover_time) * 4.0

func _on_body_entered(body: Node2D) -> void:
	# FIX: Only react visually and mechanically if the body is OUR local player
	if body is CharacterBody2D and body.name.to_int() == multiplayer.get_unique_id():
		if body.has_method("register_interactable"):
			body.register_interactable(self)
		create_tween().tween_property(sprite, "scale", Vector2(1.2, 1.2), 0.1)

func _on_body_exited(body: Node2D) -> void:
	if body == player_in_range:
		if body.has_method("unregister_interactable"):
			body.unregister_interactable(self)
		create_tween().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.1)
