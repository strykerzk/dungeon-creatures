extends Area2D
class_name LootItem

## Represents a piece of equipment sitting on the dungeon floor.

@export var item_data: EquipmentData
@onready var sprite: Sprite2D = $Sprite2D

var hover_time: float = 0.0
var base_y: float = 0.0

func _ready() -> void:
	base_y = sprite.position.y
	
	# Optional: If your EquipmentData has a texture variable, assign it automatically
	if item_data and item_data.sprite_texture:
		sprite.texture = item_data.sprite_texture

func _process(delta: float) -> void:
	# Simple hovering animation (Sine wave)
	hover_time += delta * 3.0
	sprite.position.y = base_y + sin(hover_time) * 4.0

func set_highlight(active: bool) -> void:
	if not sprite: return
	
	if active:
		create_tween().tween_property(sprite, "scale", Vector2(1.2, 1.2), 0.1)
	else:
		create_tween().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.1)
	sprite.material.set_shader_parameter("is_outlined", active)
