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

func _unhandled_input(event: InputEvent) -> void:
	if player_in_range and event.is_action_pressed("interact"):
		if player_in_range.has_method("extract_from_dungeon"):
			
			# Trigger the extraction instantly (no delay!)
			player_in_range.extract_from_dungeon(false)
			
			# Tell the Host we made it out
			if typeof(StageManager) != TYPE_NIL:
				StageManager.rpc_id(1, "server_player_extracted", multiplayer.get_unique_id())

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body.name.to_int() == multiplayer.get_unique_id():
		player_in_range = body

func _on_body_exited(body: Node2D) -> void:
	if body == player_in_range:
		player_in_range = null
