extends Area2D
class_name MinorOrb

@export var mutation_data: MutationData
@onready var sprite: Sprite2D = $Sprite2D

var hover_time: float = 0.0
var base_y: float = 0.0

func _ready() -> void:
	if sprite: base_y = sprite.position.y

func _process(delta: float) -> void:
	if not sprite: return
	hover_time += delta * 2.0
	sprite.position.y = base_y + sin(hover_time) * 5.0

func setup() -> void:
	if mutation_data and mutation_data.icon:
		sprite.texture = mutation_data.icon

func set_highlight(active: bool) -> void:
	if not sprite: return
	
	if active:
		create_tween().tween_property(sprite, "scale", Vector2(1.2, 1.2), 0.1)
	else:
		create_tween().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.1)
	sprite.material.set_shader_parameter("is_outlined", active)
