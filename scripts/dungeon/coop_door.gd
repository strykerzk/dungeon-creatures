extends StaticBody2D
class_name CoopDoor

# In the editor, you will add elements to this array and assign the specific levers!
@export var connected_levers: Array[Lever]

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var is_open: bool = false

func _ready() -> void:
	# Only the Host needs to listen to the math of the puzzle
	if not multiplayer.is_server(): return
	
	for lever in connected_levers:
		if lever:
			lever.state_changed.connect(_on_lever_state_changed)

func _on_lever_state_changed(_lever: Lever, _is_pulled: bool) -> void:
	if is_open: return
	
	# Check if ALL connected levers are currently pulled
	var all_pulled = true
	for l in connected_levers:
		if not l.is_pulled:
			all_pulled = false
			break
			
	if all_pulled:
		is_open = true
		print("[Puzzle] Puzzle Solved! Opening Door.")
		
		# Lock all levers permanently so they don't flip back up
		for l in connected_levers:
			if l: l.rpc("rpc_lock_lever")
			
		# Tell all clients to open the door
		rpc("rpc_open_door")

@rpc("authority", "call_local", "reliable")
func rpc_open_door() -> void:
	sprite.play("open")
	await sprite.animation_finished
	
	# Disable collision safely
	var col = get_node_or_null("CollisionShape2D")
	if col: col.set_deferred("disabled", true)
