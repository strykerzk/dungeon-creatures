class_name Creature extends CharacterBody2D

@export var stat_config: CreatureData

enum AttackStyle { MELEE_TACKLE, MELEE_SWING, RANGED } # MELEE_TACKLE is default

# --- EQUIPMENT SLOTS & MARKERS ---
@export_group("Equipment Markers")
@export var head_marker: Marker2D
@export var body_marker: Marker2D
@export var weapon_marker: Marker2D # Also serves as the "hand/weapon" marker
@export var boots_marker: Marker2D
@export var back_marker: Marker2D

@export_group("Equipment Settings")
@export var current_attack_style: AttackStyle = AttackStyle.MELEE_TACKLE
@export var body_hitbox: Area2D # Creature's internal tackle hitbox
@export var projectile_scene: PackedScene # Fallback/Default projectile

# --- TEST OVERRIDES ---
@export_group("Test Overrides")
@export var override_health: float = 0.0
@export var override_speed: float = 0.0
@export var override_IQ: int = 0
@export var override_aggression: float = 0.0
@export var override_dexterity: float = 0.0
@export var override_size: float = 0.0
@export var override_precision: float = 0.0
@export var override_attack_range: float = 0.0

# --- SIGNALS ---
signal attack_started(attacker: Creature, defender: Creature)
signal health_changed(current: float, total: float)
signal died()

# --- CORE STATS (Final calculated values) ---
var max_health: float = 100.0
var current_health: float = 100.0
var damage: float = 10.0
var speed: float = 200.0
var IQ: int = 5
var aggression: float = 0.5  
var dexterity: float = 1.0   
var size: float = 1.0        
var precision: float = 0.5   
var base_cooldown: float = 3.0

# --- MUTATIONS ---
var active_major_mutation: MutationData = null
var active_minor_mutations: Array[MutationData]

# --- EQUIPMENT TRACKING ---
# Stores Node references: { "head": Node, "weapon": Node, etc }
var equipment: Dictionary = {}
var weapon_node: Weapon = null # Shortcut for the current weapon

# --- AI & INTERNAL LOGIC ---
@export var target: Creature 
@export var nav_agent: NavigationAgent2D
@export var nav_timer: Timer
@export var los_ray: RayCast2D

var look_direction: Vector2 = Vector2.RIGHT
var attack_range: float = 150.0 
var retreat_threshold: float = 100.0 
var acceleration: float = 5.0 

var circle_direction: int = 1 
var is_circling: bool = true
var behavior_timer: float = 0.0
var next_behavior_change: float = 2.0
var speed_mult: float = 1.0 

var can_attack: bool = true
var is_attacking: bool = false
var is_dashing: bool = false 
var is_telegraphing: bool = false 
var is_recovering: bool = false 
var is_invulnerable: bool = false

func _ready() -> void:
	_initialize_base_stats()
	recalculate_stats()
	
	if nav_timer:
		nav_timer.timeout.connect(_on_nav_timer_timeout)
	
	if body_hitbox:
		body_hitbox.monitoring = false
	
	_randomize_behavior()

func _initialize_base_stats() -> void:
	if stat_config:
		max_health = stat_config.get("base_health") if stat_config.get("base_health") != null else 100.0
		damage = stat_config.get("damage") if stat_config.get("damage") != null else 10.0
		speed = stat_config.get("speed") if stat_config.get("speed") != null else 150.0
		IQ = stat_config.get("IQ") if stat_config.get("IQ") != null else 0.6
		aggression = stat_config.get("aggression") if stat_config.get("aggression") != null else 0.5
		dexterity = stat_config.get("dexterity") if stat_config.get("dexterity") != null else 1.0
		size = stat_config.get("size") if stat_config.get("size") != null else 1.0
		precision = stat_config.get("precision") if stat_config.get("precision") != null else 0.5
	
	# Apply Inspector Overrides to Base values
	if override_health > 0: max_health = override_health
	if override_speed > 0: speed = override_speed
	if override_IQ > 0: IQ = override_IQ
	if override_aggression > 0: aggression = override_aggression
	if override_dexterity > 0: dexterity = override_dexterity
	if override_size > 0: size = override_size
	if override_precision > 0: precision = override_precision
	
	current_health = max_health

func set_mutation(data: MutationData) -> void:
	if not data or not ("type" in data):
		print("[Creature] Error: Invalid MutationData")
		return
	
	match data.mutation_type:
		"major":
			if active_major_mutation: active_major_mutation = null
			active_major_mutation = data
		"minor":
			active_minor_mutations.append(data)
	
	recalculate_stats()
	print("[Creature] Mutation ", data.mutation_name, " added!")

## Public method to equip items via EquipmentData Resource
func equip(data: EquipmentData) -> void:
	if not data or not ("slot" in data) or not ("visual_scene" in data):
		print("[Creature] Error: Invalid EquipmentData")
		return
		
	var slot = data.slot
	
	# 1. Remove old item in this slot
	if equipment.has(slot):
		equipment[slot].queue_free()
		equipment.erase(slot)
	
	# 2. Instantiate new visual/logic node
	var new_item = data.visual_scene.instantiate()
	
	# 3. Determine parent marker
	var marker = _get_marker_for_slot(slot)
	if marker:
		marker.add_child(new_item)
		new_item.position = Vector2.ZERO
	else:
		add_child(new_item)
		
	# 4. Initialize node (specifically for weapons)
	if new_item.has_method("setup"):
		new_item.setup(data)
	
	# 5. Register and Recalculate
	equipment[slot] = new_item
	if slot == "weapon":
		weapon_node = new_item
		base_cooldown = weapon_node.attack_cd
	recalculate_stats()
	print("[Creature] Equipped ", data.item_name, " to ", slot)

func _get_marker_for_slot(slot: String) -> Node2D:
	match slot:
		"head": return head_marker
		"body": return body_marker
		"weapon": return weapon_marker
		"boots": return boots_marker
		"back": return back_marker
	return null

## Loops through all equipment and recalculates final stats
func recalculate_stats() -> void:
	# Reset to base
	_initialize_base_stats()
	
	# Setup mod and bonus variables
	var speed_mod: float = 0.0
	var damage_bonus: float = 0.0
	var iq_bonus: int = 0
	var aggro_bonus: float = 0.0
	var dex_bonus: float = 0.0
	var precision_bonus: float = 0.0
	
	
	# Apply modifiers from all equipped items
	for slot: Weapon in equipment:
		var item_node = equipment[slot]
		# We check for a 'data' property on the node which usually holds its Resource
		if "data" in item_node and item_node.data:
			var d: EquipmentData = item_node.data
			max_health += d.health_bonus
			damage_bonus += d.damage_bonus
			speed_mod += d.speed_mod
			iq_bonus += d.IQ_bonus
			aggro_bonus += d.aggression_bonus
			dex_bonus += d.dexterity_mod
			precision_bonus += d.precision_bonus
	
	# Apply modifiers from all mutations
	# Major Mutation
	if active_major_mutation:
		max_health += active_major_mutation.health_mod
		damage_bonus += active_major_mutation.damage_bonus
		speed_mod += active_major_mutation.speed_mod
		iq_bonus += active_major_mutation.IQ_bonus
		aggro_bonus += active_major_mutation.aggression_bonus
		dex_bonus += active_major_mutation.dexterity_bonus
		precision_bonus += active_major_mutation.precision_bonus
	if !active_minor_mutations.is_empty():
		for m: MutationData in active_minor_mutations:
			max_health += m.health_bonus
			damage_bonus += m.damage_bonus
			speed_mod += m.speed_mod
			iq_bonus += m.IQ_bonus
			aggro_bonus += m.aggression_bonus
			dex_bonus += m.dexterity_bonus
			precision_bonus += m.precision_bonus
	
	# Finalize primary values
	var modded_speed = speed * (1.0 + speed_mod)
	var modded_damage = damage + damage_bonus
	if active_major_mutation:
		max_health *= active_major_mutation.health_mult
		modded_speed *= active_major_mutation.speed_mult
		modded_damage *= active_major_mutation.damage_mult
		size = clamp(size * active_major_mutation.size_mult, stat_config.min_size, stat_config.max_size)
	if max_health < stat_config.min_health: max_health = stat_config.min_health
	
	speed = clamp(modded_speed, stat_config.min_speed, stat_config.max_speed)
	damage = clamp(modded_damage, stat_config.min_damage, stat_config.max_damage)
	
	# Finalize secondary values
	IQ = clamp(IQ + iq_bonus, stat_config.min_IQ, stat_config.max_IQ)
	aggression = clamp(aggression + aggro_bonus, stat_config.min_aggression, stat_config.max_aggression)
	dexterity = clamp(dexterity + dex_bonus, stat_config.min_dexterity, stat_config.max_dexterity)
	precision = clamp(precision + precision_bonus,stat_config.min_precision, stat_config.max_precision)
	
	# Finalize internal values
	self.scale = Vector2.ONE * size
	acceleration = 10.0 / size 
	
	_update_attack_range_by_style()
	retreat_threshold = attack_range * (1.1 - aggression)
	
	if nav_agent:
		nav_agent.target_desired_distance = attack_range
	
	# Clamp current health to new max
	current_health = min(current_health, max_health)
	health_changed.emit(current_health, max_health)

func _update_attack_range_by_style() -> void:
	match current_attack_style:
		AttackStyle.MELEE_TACKLE:
			if weapon_node and "attack_range" in weapon_node:
				attack_range = weapon_node.attack_range
			else:
				attack_range = 150.0 * size
		AttackStyle.MELEE_SWING:
			if weapon_node and "attack_range" in weapon_node:
				attack_range = weapon_node.attack_range
			else:
				attack_range = 200.0 * size
		AttackStyle.RANGED:
			if weapon_node and "attack_range" in weapon_node:
				attack_range = weapon_node.attack_range
			else:
				attack_range = 500.0

func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		target = null
		if not is_attacking: search_for_target()
		return
	
	if not is_attacking:
		look_direction = global_position.direction_to(target.global_position)
		if weapon_marker:
			weapon_marker.rotation = look_direction.angle()
		if weapon_node and weapon_node.has_method("look_at_direction"):
			weapon_node.look_at_direction(look_direction)
		
	if los_ray:
		los_ray.target_position = los_ray.to_local(target.global_position)

	if is_attacking:
		if not is_dashing:
			velocity = velocity.lerp(Vector2.ZERO, acceleration * delta)
		move_and_slide()
		return
		
	_update_behavior_timer(delta)
	movement(delta)

func take_damage(amount: float) -> void:
	if is_invulnerable or current_health <= 0:
		return
	
	# Apply flat defense if body armor is equipped (Example logic)
	current_health -= amount
	health_changed.emit(current_health, max_health)
	
	if current_health <= 0:
		die()
	else:
		_trigger_hit_iframe()

func _trigger_hit_iframe() -> void:
	is_invulnerable = true
	await get_tree().create_timer(0.1).timeout
	is_invulnerable = false

func die() -> void:
	died.emit()
	set_physics_process(false)
	queue_free()

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
		var should_switch = false
		if not is_instance_valid(target): should_switch = true
		elif nearest_node != target:
			var switch_threshold = 0.8 - (aggression * 0.3)
			if nearest_dist < global_position.distance_to(target.global_position) * switch_threshold:
				should_switch = true
		
		if should_switch:
			if is_instance_valid(target) and target.attack_started.is_connected(_on_target_attack_started):
				target.attack_started.disconnect(_on_target_attack_started)
			target = nearest_node
			target.attack_started.connect(_on_target_attack_started)

func _on_target_attack_started(attacker: Creature, defender: Creature) -> void:
	if defender != self or is_attacking: return
	var dodge_chance = 0.15 + (IQ * 0.07)
	if (current_health / max_health) < 0.3 and aggression > 0.5: dodge_chance *= 0.2 
	if randf() < dodge_chance: dodge(attacker)

func dodge(attacker: Creature) -> void:
	is_attacking = true 
	is_dashing = true
	var attack_dir = attacker.global_position.direction_to(global_position)
	var dodge_dir = Vector2(-attack_dir.y, attack_dir.x) * (1 if randf() > 0.5 else -1)
	var dodge_duration = 0.2
	var dodge_distance = (140.0 + (speed * 0.2) + (40.0 * dexterity)) / max(0.5, size)
	velocity = dodge_dir * (dodge_distance / dodge_duration)
	await get_tree().create_timer(dodge_duration).timeout
	is_dashing = false
	await get_tree().create_timer(0.1).timeout
	is_attacking = false

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
	speed_mult = randf_range(0.8, 1.2)
	if not is_attacking: search_for_target()

func movement(delta: float) -> void:
	var distance_to_target = global_position.distance_to(target.global_position)
	var dir_to_target = global_position.direction_to(target.global_position)
	
	var effective_retreat = retreat_threshold
	if (current_health / max_health) < 0.3:
		effective_retreat = 0.0 if aggression > 0.5 else effective_retreat * 2.0 

	if distance_to_target > attack_range + 20.0:
		var move_dir = global_position.direction_to(nav_agent.get_next_path_position())
		velocity = velocity.lerp(move_dir * (speed * speed_mult), acceleration * delta)
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
				velocity = velocity.lerp(circle_vector * (speed * 0.6 * speed_mult), acceleration * delta)
			else:
				velocity = velocity.lerp(Vector2.ZERO, acceleration * delta)
	move_and_slide()

func attack() -> void:
	if is_attacking: return
	is_attacking = true
	can_attack = false
	is_telegraphing = true
	velocity = Vector2.ZERO
	await get_tree().create_timer(max(0.05, 0.3 / dexterity)).timeout 
	is_telegraphing = false
	
	var base_dir = look_direction
	var dash_dir = base_dir.rotated(randf_range(-PI/6, PI/6) * (1.0 - precision)) # min/max 30'
	attack_started.emit(self, target)
	
	match current_attack_style:
		AttackStyle.MELEE_TACKLE, AttackStyle.MELEE_SWING:
			var dash_duration = 0.25
			velocity = dash_dir * ((attack_range * 1.3) / dash_duration)
			is_dashing = true
			if weapon_node: _trigger_weapon_action()
			elif current_attack_style == AttackStyle.MELEE_TACKLE and body_hitbox:
				_manual_hitbox_activate(body_hitbox, damage)
			await get_tree().create_timer(dash_duration).timeout
			is_dashing = false
		AttackStyle.RANGED:
			_fire_projectile(dash_dir)
			await get_tree().create_timer(0.2).timeout
	
	is_recovering = true 
	await get_tree().create_timer(0.15).timeout
	is_recovering = false
	is_attacking = false 
	_on_attack_cooldown_finished()

func _trigger_weapon_action() -> void:
	if weapon_node.has_method("activate"):
		weapon_node.activate(damage, self)

func _manual_hitbox_activate(hb: Area2D, dmg: float) -> void:
	if hb is Hitbox:
		hb.damage_value = dmg
		hb.attacker = self
	hb.monitoring = true
	await get_tree().create_timer(0.2).timeout
	hb.monitoring = false

func _fire_projectile(direction: Vector2) -> void:
	if not projectile_scene: return
	var proj = projectile_scene.instantiate()
	get_parent().add_child(proj)
	proj.global_position = global_position
	if proj.has_method("launch"): proj.launch(direction, damage, self)

func _on_attack_cooldown_finished() -> void:
	if not is_inside_tree(): return
	var cooldown = base_cooldown / max(0.1, (1.0 + (dexterity * 0.5)))
	await get_tree().create_timer(cooldown).timeout
	can_attack = true

func _on_nav_timer_timeout() -> void:
	if target: nav_agent.target_position = target.global_position
