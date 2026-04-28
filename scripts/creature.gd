class_name Creature extends CharacterBody2D

@export var stat_config: CreatureData

# --- TEST OVERRIDES (Inspector) ---
@export_group("Test Overrides")
@export var override_health: float = 0.0
@export var override_speed: float = 0.0
@export var override_IQ: int = 0
@export var override_aggression: float = 0.0
@export var override_dexterity: float = 0.0
@export var override_size: float = 0.0
@export var override_precision: float = 0.0

# --- SIGNALS ---
signal attack_started(attacker: Creature)

# --- CORE STATS ---
var base_health: float = 100.0
var current_health: float = 100.0
var damage: float = 10.0
var speed: float = 200.0
var IQ: int = 5

# --- BEHAVIORAL STATS ---
var aggression: float = 0.5  
var dexterity: float = 1.0   
var size: float = 1.0        
var precision: float = 0.5   

# --- AI MOVEMENT & TARGETING ---
@export var target: Creature 
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
var is_dashing: bool = false 
var is_telegraphing: bool = false 
var is_recovering: bool = false 

func _ready() -> void:
	if stat_config:
		base_health = stat_config.base_health
		damage = stat_config.damage
		speed = stat_config.speed
		IQ = stat_config.IQ
		aggression = stat_config.get("aggression") if stat_config.get("aggression") != null else 0.5
		dexterity = stat_config.get("dexterity") if stat_config.get("dexterity") != null else 1.0
		size = stat_config.get("size") if stat_config.get("size") != null else 1.0
		precision = stat_config.get("precision") if stat_config.get("precision") != null else 0.5
	
	if override_health > 0: base_health = override_health
	if override_speed > 0: speed = override_speed
	if override_IQ > 0: IQ = override_IQ
	if override_aggression > 0: aggression = override_aggression
	if override_dexterity > 0: dexterity = override_dexterity
	if override_size > 0: size = override_size
	if override_precision > 0: precision = override_precision
	
	current_health = base_health
	self.scale = Vector2.ONE * size
	acceleration = 10.0 / size 
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
			
	if nearest_node and nearest_node is Creature:
		if target and target.attack_started.is_connected(_on_target_attack_started):
			target.attack_started.disconnect(_on_target_attack_started)
		target = nearest_node
		target.attack_started.connect(_on_target_attack_started)

func _on_target_attack_started(attacker: Creature) -> void:
	if is_attacking: 
		print("[", name, "] Ignoring attack from ", attacker.name, " (already busy)")
		return
	
	var dodge_chance = 0.15 + (IQ * 0.07)
	var health_pct = current_health / base_health
	if health_pct < 0.3 and aggression > 0.5:
		dodge_chance *= 0.2 
	
	var roll = randf()
	print("[", name, "] Reaction Check vs ", attacker.name, ": Roll ", snapped(roll, 0.01), " < Chance ", snapped(dodge_chance, 0.01))
		
	if roll < dodge_chance:
		print("[", name, "] Reaction SUCCESS: Initiating Dodge")
		dodge(attacker)
	else:
		print("[", name, "] Reaction FAILED: Taking incoming strike")

func dodge(attacker: Creature) -> void:
	is_attacking = true 
	is_dashing = true
	
	var attack_dir = attacker.global_position.direction_to(global_position)
	var dodge_dir = Vector2(-attack_dir.y, attack_dir.x) * (1 if randf() > 0.5 else -1)
	
	var dodge_duration = 0.2
	var dodge_distance = (140.0 + (speed * 0.2) + (40.0 * dexterity)) / max(0.5, size)
	var dodge_speed = dodge_distance / dodge_duration
	
	velocity = dodge_dir * dodge_speed
	await get_tree().create_timer(dodge_duration).timeout
	
	is_dashing = false
	await get_tree().create_timer(0.1).timeout
	is_attacking = false
	print("[", name, "] Dodge sequence finished")

func _update_behavior_timer(delta: float) -> void:
	behavior_timer += delta
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
	
	var effective_retreat = retreat_threshold
	var health_pct = current_health / base_health
	if health_pct < 0.3:
		if aggression > 0.5: effective_retreat = 0.0 
		else: effective_retreat *= 2.0 

	if distance_to_target > attack_range + 20.0 or not has_los:
		var move_dir = global_position.direction_to(nav_agent.get_next_path_position())
		velocity = velocity.lerp(move_dir * (speed * speed_multiplier), acceleration * delta)
	else:
		if can_attack and distance_to_target <= attack_range + 25.0:
			attack()
			return 
		else:
			if distance_to_target < effective_retreat:
				velocity = velocity.lerp(-dir_to_target * (speed * 0.3), acceleration * delta)
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
	
	print("[", name, "] ATTACK: Starting Windup")
	is_attacking = true
	can_attack = false
	is_telegraphing = true
	
	# 1. TELEGRAPH (Windup)
	velocity = Vector2.ZERO
	var telegraph_time = max(0.05, 0.3 / dexterity)
	await get_tree().create_timer(telegraph_time).timeout 
	
	is_telegraphing = false
	
	# Accuracy logic
	var base_dir = global_position.direction_to(target.global_position)
	var max_deviation = deg_to_rad(45.0)
	var actual_deviation = randf_range(-max_deviation, max_deviation) * (1.0 - precision)
	var dash_dir = base_dir.rotated(actual_deviation)
	
	# 2. LUNGE (Dash)
	var dash_duration = 0.25
	var target_distance = attack_range * 1.3
	var required_speed = target_distance / dash_duration
	
	print("[", name, "] ATTACK: Launching Lunge")
	attack_started.emit(self)
	
	velocity = dash_dir * required_speed
	is_dashing = true
	await get_tree().create_timer(dash_duration).timeout
	
	# 3. RECOVERY
	print("[", name, "] ATTACK: Recovery Phase")
	is_dashing = false
	is_recovering = true 
	await get_tree().create_timer(0.15).timeout
	
	is_recovering = false
	is_attacking = false 
	
	_on_attack_cooldown_finished()

func _on_attack_cooldown_finished() -> void:
	var cooldown_base = 3.0
	var cooldown = cooldown_base / (1.0 + (dexterity * 0.5))
	await get_tree().create_timer(cooldown).timeout
	can_attack = true
	print("[", name, "] Cooldown Finished: Ready to strike")

func _on_nav_timer_timeout() -> void:
	if target: nav_agent.target_position = target.global_position
