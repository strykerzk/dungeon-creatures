extends Area2D
class_name EscapePortal

var player_in_range: Node2D = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Optional: Play a spawn animation or sound here
	var tween = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	scale = Vector2.ZERO
	tween.tween_property(self, "scale", Vector2.ONE, 0.8)
	$AnimatedSprite2D.play("default")

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body.name.to_int() == multiplayer.get_unique_id():
		if body.has_method("register_interactable"):
			body.register_interactable(self)

func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D and body.name.to_int() == multiplayer.get_unique_id():
		if body.has_method("unregister_interactable"):
			body.unregister_interactable(self)
