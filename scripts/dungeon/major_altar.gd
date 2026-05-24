extends Area2D
class_name MajorAltar

@onready var sprite: Sprite2D = $Sprite2D
var grid_pos: Vector2i = Vector2i.ZERO

func _ready() -> void:
	grid_pos = get_parent().grid_pos

func set_highlight(active: bool) -> void:
	# Add any visual flair you want here (like glowing runes or an outline)
	if active:
		modulate = Color(1.5, 1.5, 1.5, 1.0) # Brighten slightly
	else:
		modulate = Color(1.0, 1.0, 1.0, 1.0) # Normal
	sprite.material.set_shader_parameter("is_outlined", active)

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
