extends Area2D
class_name MajorAltar

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body.name.to_int() == multiplayer.get_unique_id():
		if body.has_method("register_interactable"):
			body.register_interactable(self)

func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D and body.name.to_int() == multiplayer.get_unique_id():
		if body.has_method("unregister_interactable"):
			body.unregister_interactable(self)

@rpc("any_peer", "call_local", "reliable")
func rpc_deactivate() -> void:
	# 1. Disable the collision so no one else can trigger it
	var col = get_node_or_null("CollisionShape2D")
	if col:
		col.set_deferred("disabled", true)
		
	# 2. Provide visual feedback that it's dead (dim it to dark gray)
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(0.5, 0.5, 0.5, 1.0), 0.5)
	
	$Sprite2D.frame = 1
	
	print("[Dungeon] Major Altar deactivated.")
