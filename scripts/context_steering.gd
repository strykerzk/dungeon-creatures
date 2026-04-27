extends CharacterBody2D

@export_group("Movement Settings")
@export var max_speed = 200.0
@export var steer_force = 0.1
@export var look_ahead = 100.0
@export var num_rays = 16

@export_group("Combat Behavior")
## The distance the AI tries to maintain from the target.
@export var desired_distance = 300.0
## How strictly the AI cares about the exact distance (lower = more loose circling).
@export var distance_threshold = 30.0
## 1.0 for clockwise, -1.0 for counter-clockwise.
@export var orbit_direction = 1.0

# State
@export var target: Node2D = null # Node2D target
var context_directions = []
var interest = []
var danger = []

func _ready():
	# Initialize context maps
	context_directions.resize(num_rays)
	interest.resize(num_rays)
	danger.resize(num_rays)
	
	for i in range(num_rays):
		var angle = i * 2 * PI / num_rays
		context_directions[i] = Vector2.RIGHT.rotated(angle)

func _physics_process(delta):
	if not target:
		return
		
	_update_context_maps()
	_calculate_steering(delta)
	
	move_and_slide()

func _update_context_maps():
	# 1. Reset
	for i in range(num_rays):
		interest[i] = 0.0
		danger[i] = 0.0
	
	# 2. Populate Interest (RPG Combat Logic)
	var vec_to_target = target.global_position - global_position
	var dist_to_target = vec_to_target.length()
	var dir_to_target = vec_to_target.normalized()
	
	# Determine if we need to move forward, backward, or just circle
	var move_dir = dir_to_target
	
	if dist_to_target < desired_distance - distance_threshold:
		# Too close! Move away
		move_dir = -dir_to_target
	elif dist_to_target > desired_distance + distance_threshold:
		# Too far! Move closer
		move_dir = dir_to_target
	else:
		# Within range! Circle around the target
		# Perpendicular vector for orbiting
		move_dir = dir_to_target.rotated(( PI / 2 ) * orbit_direction)
	
	for i in range(num_rays):
		var d = context_directions[i].dot(move_dir)
		interest[i] = max(0, d)
	
	# 3. Populate Danger (Obstacle Avoidance)
	var space_state = get_world_2d().direct_space_state
	for i in range(num_rays):
		var ray_direction = context_directions[i]
		var query = PhysicsRayQueryParameters2D.create(
			global_position, 
			global_position + ray_direction * look_ahead,
			1 # Assuming layer 1 is obstacles
		)
		query.exclude = [get_rid()]
		
		var result = space_state.intersect_ray(query)
		if result:
			var dist = result.position.distance_to(global_position)
			danger[i] = 1.0 - (dist / look_ahead)

func _calculate_steering(delta):
	var final_dir = Vector2.ZERO
	for i in range(num_rays):
		var weight = interest[i] - danger[i]
		if weight > 0:
			final_dir += context_directions[i] * weight
	
	if final_dir != Vector2.ZERO:
		final_dir = final_dir.normalized()
		
	var desired_velocity = final_dir * max_speed
	velocity = velocity.lerp(desired_velocity, steer_force)
	
	if velocity.length() > 10:
		rotation = lerp_angle(rotation, velocity.angle(), 0.1)

# Helper to visualize in editor
func _draw():
	if not Engine.is_editor_hint() and not get_tree().debug_collisions_hint:
		return
		
	for i in range(num_rays):
		draw_line(Vector2.ZERO, context_directions[i] * (interest[i] * 40), Color.GREEN, 2.0)
		draw_line(Vector2.ZERO, context_directions[i] * (danger[i] * 40), Color.RED, 2.0)
