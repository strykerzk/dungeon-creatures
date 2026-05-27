extends Camera2D

enum CameraMode { STARTUP, DYNAMIC, SPECTATOR }
var current_mode: CameraMode = CameraMode.STARTUP

@export_category("Camera Settings")
@export var creatures_container: Node2D
@export var margin: Vector2 = Vector2(250, 250) # Padding around the screen edges
@export var min_zoom: float = 0.3 # Farthest it can zoom out
@export var max_zoom: float = 1.5 # Closest it can zoom in
@export var follow_speed: float = 5.0
@export var zoom_speed: float = 3.0

var current_shake_strength: float = 0.0
var shake_decay_rate: float = 15.0

var spectate_index: int = 0
var alive_creatures: Array = []

func _ready() -> void:
	make_current()
	if typeof(StageManager) != TYPE_NIL:
		StageManager.screen_shake_requested.connect(_apply_shake)

func _process(delta: float) -> void:
	_update_alive_creatures()
	
	if not alive_creatures.is_empty():
		_handle_input()
		match current_mode:
			CameraMode.STARTUP: _lerp_camera(Vector2.ZERO, Vector2(min_zoom, min_zoom), delta)
			CameraMode.DYNAMIC: _process_dynamic_camera(delta)
			CameraMode.SPECTATOR: _process_spectator_camera(delta)
	
	if current_shake_strength > 0:
		current_shake_strength = lerpf(current_shake_strength, 0.0, shake_decay_rate * delta)
		var random_offset = Vector2(
			randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0) 
		).normalized() * current_shake_strength
		
		offset = random_offset
		
		if current_shake_strength < 0.5:
			current_shake_strength = 0.0
			offset = Vector2.ZERO


## Refreshes the list of active targets every frame
func _update_alive_creatures() -> void:
	if not creatures_container: return
	
	alive_creatures.clear()
	for child in creatures_container.get_children():
		# Assuming dead creatures are queue_freed. 
		# If you keep them around for death animations, add an `and child.current_health > 0` check!
		if child is Creature and child.current_health > 0: 
			alive_creatures.append(child)

## Listens for the player's spectator inputs
func _handle_input() -> void:
	# Cycle Spectator Targets
	if Input.is_action_just_pressed("right"):
		_cycle_spectator(1)
	elif Input.is_action_just_pressed("left"):
		_cycle_spectator(-1)
		
	# Return to Dynamic Mode (Press 'dodge' / Spacebar)
	elif Input.is_action_just_pressed("dodge") and current_mode == CameraMode.SPECTATOR:
		current_mode = CameraMode.DYNAMIC
		print("[Camera] Returned to Dynamic Action Cam")

func _cycle_spectator(direction: int) -> void:
	if alive_creatures.is_empty(): return
	
	current_mode = CameraMode.SPECTATOR
	spectate_index = (spectate_index + direction) % alive_creatures.size()
	
	# Wrap around backwards
	if spectate_index < 0:
		spectate_index = alive_creatures.size() - 1
		
	print("[Camera] Spectating: ", alive_creatures[spectate_index].name)

## The Smash Bros style bounding-box tracker
func _process_dynamic_camera(delta: float) -> void:
	# If only one creature is left, just focus on them
	if alive_creatures.size() == 1:
		_lerp_camera(alive_creatures[0].global_position, Vector2(max_zoom, max_zoom), delta)
		return
		
	# Calculate the bounding box containing all creatures
	var bounds = Rect2(alive_creatures[0].global_position, Vector2.ZERO)
	for i in range(1, alive_creatures.size()):
		bounds = bounds.expand(alive_creatures[i].global_position)
		
	var target_pos = bounds.get_center()
	
	# Calculate required zoom to fit the box
	var screen_size = get_viewport_rect().size
	var size_with_margin = bounds.size + (margin * 2.0)
	
	var zoom_x = screen_size.x / max(size_with_margin.x, 1.0)
	var zoom_y = screen_size.y / max(size_with_margin.y, 1.0)
	
	# Pick the most restrictive zoom, clamped to our limits
	var target_zoom_val = clamp(min(zoom_x, zoom_y), min_zoom, max_zoom)
	var target_zoom = Vector2(target_zoom_val, target_zoom_val)
	
	_lerp_camera(target_pos, target_zoom, delta)

## Locks onto a specific creature
func _process_spectator_camera(delta: float) -> void:
	# Safety check in case the spectated creature dies
	if spectate_index >= alive_creatures.size():
		spectate_index = 0
		
	var target_creature = alive_creatures[spectate_index]
	var target_pos = target_creature.global_position
	var target_zoom = Vector2(max_zoom, max_zoom) # Zoom in close for spectating
	
	_lerp_camera(target_pos, target_zoom, delta)

## Smoothly moves and zooms the camera
func _lerp_camera(target_pos: Vector2, target_zoom: Vector2, delta: float) -> void:
	global_position = global_position.lerp(target_pos, follow_speed * delta)
	zoom = zoom.lerp(target_zoom, zoom_speed * delta)

func _apply_shake(intensity: float) -> void:
	current_shake_strength = max(current_shake_strength, intensity)
