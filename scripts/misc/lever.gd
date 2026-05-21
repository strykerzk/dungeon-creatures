extends Area2D
class_name Lever

signal state_changed(lever_node: Lever, is_pulled: bool)

@export var reset_time: float = 4.0
var is_pulled: bool = false
var is_locked: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var reset_timer: Timer = Timer.new()

func _ready() -> void:
	# Create the reset timer dynamically
	add_child(reset_timer)
	reset_timer.one_shot = true
	reset_timer.timeout.connect(_on_timer_timeout)

func set_highlight(active: bool) -> void:
	if is_pulled or is_locked:
		return
	sprite.material.set_shader_parameter("is_outlined", active)

@rpc("any_peer", "call_local", "reliable")
func rpc_pull_lever() -> void:
	if is_locked or is_pulled: return
	
	is_pulled = true
	sprite.frame = 1
	reset_timer.start(reset_time)
	state_changed.emit(self, true)
	print("[Puzzle] Lever pulled!")

func _on_timer_timeout() -> void:
	if is_locked: return
	
	is_pulled = false
	sprite.frame = 0
	state_changed.emit(self, false)
	print("[Puzzle] Lever reset!")

@rpc("authority", "call_local", "reliable")
func rpc_lock_lever() -> void:
	is_locked = true
	reset_timer.stop()
