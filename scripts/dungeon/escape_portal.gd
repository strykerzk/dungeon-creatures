extends Area2D
class_name EscapePortal

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	# Optional: Play a spawn animation or sound here
	var tween = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	scale = Vector2.ZERO
	tween.tween_property(self, "scale", Vector2.ONE, 0.8)
	$AnimatedSprite2D.play("default")

func set_highlight(active: bool) -> void:
	sprite.material.set_shader_parameter("is_outlined", active)
