extends Area2D
class_name MinorOrb

@export var mutation_data: MutationData
@onready var sprite: Sprite2D = $Sprite2D

var hover_time: float = 0.0
var base_y: float = 0.0

func _ready() -> void:
	if sprite: base_y = sprite.position.y
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(delta: float) -> void:
	if not sprite: return
	hover_time += delta * 2.0
	sprite.position.y = base_y + sin(hover_time) * 5.0

func setup() -> void:
	if mutation_data and mutation_data.icon:
		sprite.texture = mutation_data.icon

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body.name.to_int() == multiplayer.get_unique_id():
		if body.has_method("register_interactable"):
			body.register_interactable(self)
		create_tween().tween_property(sprite, "scale", Vector2(1.2, 1.2), 0.1)

func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D and body.name.to_int() == multiplayer.get_unique_id():
		if body.has_method("unregister_interactable"):
			body.unregister_interactable(self)
		create_tween().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.1)
