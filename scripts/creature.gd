class_name Creature extends CharacterBody2D

@export var stat_config: CreatureData

# --- CORE STATS ---
var base_health: float = 100.0
var current_health: float = 100.0
var damage: float = 10.0
var speed: float = 200.0
var IQ: int = 5

# --- BEHAVIORAL STATS ---
var aggression: float = 0.5  # High = stays close, retreats less, circles less
var dexterity: float = 1.0   # High = fast telegraph, fast cooldown, faster lunge
var size: float = 1.0        # High = big, heavy momentum, slow acceleration
var precision: float = 0.5   # High = predicts target movement during lunge

# --- AI MOVEMENT & TARGETING ---
@export var target: Node2D
@export var nav_agent: NavigationAgent2D
@export var nav_timer: Timer
@export var los_ray: RayCast2D
var look_direction: Vector2 = Vector2.ZERO

# --- INTERNAL LOGIC ---
var attack_range: float = 150.0 
var retreat_threshold: float = 100.0 
var acceleration: float = 5.0 

var circle_direction: int = 1 
var is_circling: bool = true
var behavior_timer: float = 0.0
var next_behavior_change: float = 2.0
var speed_multiplier: float = 1.0 

var can_attack: bool = true
var is_attacking: bool = false
var is_dashing: bool = false # New: specifically to prevent friction during the lunge

func _ready() -> void:
	if stat_config:
		base_health = stat_config.base_health
		current_health = base_health
		damage = stat_config.damage
		speed = stat_config.speed
		IQ = stat_config.IQ
		
		# Safer property access for Resources
		aggression = stat_config.get("aggression") if stat_config.get("aggression") != null else 0.5
		dexterity = stat_config.get("dexterity") if stat_config.get("dexterity") != null else 1.0
		size = stat_config.get("size") if stat_config.get("size") != null else 1.0
		precision = stat_config.get("precision") if stat_config.get("precision") != null else 0.5
	
	# Math: Size affects Scale and Acceleration (Inversely)
	self.scale = Vector2.ONE * size
	acceleration = 10.0 / size 
	
	# Math: Retreat Threshold tied to Aggression
	retreat_threshold = attack_range * (1.1 - aggression)
	
	nav_agent.path_desired_distance = 20.0
	nav_agent.target_desired_distance = attack_range
	
	if nav_timer:
		nav_timer.timeout.connect(_on_nav_timer_timeout)
	
	_randomize_behavior()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		target = null
		if not is_attacking: search_for_target()
		return
		
	if los_ray:
		los_ray.target_position = los_ray.to_local(target.global_position)

	if is_attacking:
		# Momentum: Only decay velocity if we aren't in the active burst phase
		if not is_dashing:
			velocity = velocity.lerp(Vector2.ZERO, acceleration * delta)
		
		move_and_slide()
		return
		
	_update_behavior_timer(delta)
	movement(delta)

func search_for_target() -> void:
	var creatures = get_tree().get_nodes_in_group("creature")
	var nearest_dist = INF
	var nearest_node = null
	for c in creatures:
		if c == self: continue
		var dist = global_position.distance_to(c.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest_node = c
	if nearest_node: target = nearest_node

func _update_behavior_timer(delta: float) -> void:
	behavior_timer += delta
	# Math: Decision persistence. 
	var persistence_mod = (IQ * 0.1) + (aggression * 0.5)
	if behavior_timer >= next_behavior_change / (1.0 + persistence_mod):
		_randomize_behavior()
		behavior_timer = 0.0

func _randomize_behavior() -> void:
	next_behavior_change = randf_range(1.5, 4.0)
	circle_direction = 1 if randf() > 0.5 else -1
	is_circling = randf() < aggression
	speed_multiplier = randf_range(0.8, 1.2)

func has_line_of_sight() -> bool:
	if not los_ray: return true 
	los_ray.force_raycast_update()
	return !los_ray.is_colliding() or los_ray.get_collider() == target

func movement(delta: float) -> void:
	var distance_to_target = global_position.distance_to(target.global_position)
	var dir_to_target = global_position.direction_to(target.global_position)
	var has_los = has_line_of_sight()
	
	# Math: Willpower/Threshold Logic
	var effective_retreat = retreat_threshold
	var health_pct = current_health / base_health
	if health_pct < 0.3:
		if aggression > 0.5: effective_retreat = 0.0 # Berserk
		else: effective_retreat *= 2.0 # Panic

	if distance_to_target > attack_range + 20.0 or not has_los:
		var move_dir = global_position.direction_to(nav_agent.get_next_path_position())
		velocity = velocity.lerp(move_dir * (speed * speed_multiplier), acceleration * delta)
	elif distance_to_target < effective_retreat:
		velocity = velocity.lerp(-dir_to_target * (speed * 0.8), acceleration * delta)
	else:
		if can_attack and distance_to_target <= attack_range + 15.0:
			attack()
			return 
		elif is_circling:
			if get_slide_collision_count() > 0: circle_direction *= -1
			var side_dir = Vector2(-dir_to_target.y, dir_to_target.x) * circle_direction
			var range_correction = (distance_to_target - attack_range) * 0.05
			var circle_vector = (side_dir + (dir_to_target * range_correction)).normalized()
			velocity = velocity.lerp(circle_vector * (speed * 0.6 * speed_multiplier), acceleration * delta)
		else:
			velocity = velocity.lerp(Vector2.ZERO, acceleration * delta)
	
	move_and_slide()

func attack() -> void:
	if is_attacking: return
	is_attacking = true
	can_attack = false
	
	# 1. Telegraph (Wind-up)
	velocity = Vector2.ZERO
	await get_tree().create_timer(max(0.05, 0.3 / dexterity)).timeout 
	
	# 2. Dash Calculation
	# We travel (attack_range * 1.3) to ensure we overshoot the center slightly for impact
	var dash_duration = 0.25
	var target_distance = attack_range * 1.3
	var required_speed = target_distance / dash_duration
	
	# Prediction logic
	var target_vel = Vector2.ZERO
	if target is CharacterBody2D: target_vel = target.velocity
	var lead_factor = precision * 0.5
	var predicted_pos = target.global_position + (target_vel * lead_factor)
	var dash_dir = global_position.direction_to(predicted_pos)
	
	# Apply Dash Burst
	velocity = dash_dir * required_speed
	is_dashing = true
	await get_tree().create_timer(dash_duration).timeout
	is_dashing = false
	
	# Small recovery pause before returning to movement logic
	await get_tree().create_timer(0.1).timeout
	
	is_attacking = false 
	_on_attack_cooldown_finished()

func _on_attack_cooldown_finished() -> void:
	# Math: Dexterity reduces recovery time
	var cooldown_base = 2.0
	var cooldown = cooldown_base / (1.0 + (dexterity * 0.5))
	await get_tree().create_timer(cooldown).timeout
	can_attack = true

func _on_nav_timer_timeout() -> void:
	if target: nav_agent.target_position = target.global_position
