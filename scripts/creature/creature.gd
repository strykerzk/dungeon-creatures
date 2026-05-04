class_name Creature extends CharacterBody2D

@export var stat_config: CreatureData

enum AttackStyle { TACKLE, MELEE, RANGED }

# --- EQUIPMENT SLOTS & MARKERS ---
@export_group("Equipment Markers")
@export var head_marker: Marker2D
@export var body_marker: Marker2D
@export var weapon_marker: Marker2D 
@export var boots_marker: Marker2D
@export var back_marker: Marker2D

@export_group("Equipment Settings")
@export var current_attack_style: AttackStyle = AttackStyle.TACKLE
@export var body_hitbox: Area2D 
@export var projectile_scene: PackedScene 

# --- AI & INTERNAL LOGIC ---
@export_group("AI & Logic")
@export var target: Creature 
@export var nav_agent: NavigationAgent2D
@export var nav_timer: Timer
@export var los_ray: RayCast2D

# --- SIGNALS ---
signal attack_started(attacker: Creature, defender: Creature)
signal health_changed(current: float, total: float)
signal died()

# --- CORE STATS ---
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
var equipment: Dictionary = {}
var weapon_node: Weapon = null 

# --- SKILL TRACKING ---
@export_group("Skill System")
@export var skill_container: Node2D # Container for instantiated skill nodes
var skill_directory = {
	"major": null,         # Single BaseSkill node
	"utility": [],        # Array of BaseSkill nodes
	"passive": []         # Array of BaseSkill nodes
}

# The action the creature is currently trying to get in range for
var current_intended_action: Dictionary = {}

# --- INTERNAL STATE ---
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

func _enter_tree() -> void:
	y_sort_enabled = true
	set_collision_layer_value(1, false)
	set_collision_layer_value(3, true)
	set_collision_mask_value(1, true)

func _ready() -> void:
	_initialize_base_stats()
	recalculate_stats()
	if nav_timer: nav_timer.timeout.connect(_on_nav_timer_timeout)
	if body_hitbox: body_hitbox.monitoring = false
	setup_physics_layers()
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
	
	if override_health != 0: max_health = override_health
	if override_speed != 0: speed = override_speed
	if override_IQ != 0: IQ = override_IQ
	if override_aggression != 0: aggression = override_aggression
	if override_dexterity != 0: dexterity = override_dexterity
	if override_size != 0: size = override_size
	if override_precision != 0: precision = override_precision
	current_health = max_health

func _physics_process(delta: float) -> void:
	# ONLY for Host
	if not multiplayer.is_server(): return
	
	if not is_instance_valid(target) or target.is_queued_for_deletion() or target.current_health <= 0:
		target = null
		if not is_attacking: search_for_target()
		return
	
	if not is_attacking:
		look_direction = global_position.direction_to(target.global_position)
	
	if los_ray:
		los_ray.target_position = los_ray.to_local(target.global_position)

	if is_attacking:
		if not is_dashing:
			velocity = velocity.lerp(Vector2.ZERO, acceleration * delta)
		move_and_slide()
		return
		
	_update_behavior_timer(delta)
	movement(delta)

func _process(delta: float) -> void:
	if not is_attacking:
		if weapon_node and weapon_node.has_method("look_at_direction"):
			weapon_node.look_at_direction(look_direction)

func setup_physics_layers() -> void:
	set_collision_layer_value(1, false)
	set_collision_layer_value(3, true)
	set_collision_mask_value(1, true)

func set_mutation(data: MutationData) -> void:
	if not data: return
	match data.mutation_type:
		"major": active_major_mutation = data
		"minor": active_minor_mutations.append(data)
	recalculate_stats()

func equip(data: EquipmentData) -> void:
	if not data: return
	var slot = data.slot
	if equipment.has(slot):
		equipment[slot].queue_free()
		equipment.erase(slot)
	
	var new_item = data.visual_scene.instantiate()
	var marker = _get_marker_for_slot(slot)
	if marker:
		if marker == weapon_marker and new_item.has_method("reposition_visual"):
			add_child(new_item)
			new_item.reposition_visual(marker)
		else:
			marker.add_child(new_item)
			new_item.position = Vector2.ZERO
	else:
		add_child(new_item)
		
	if new_item.has_method("setup"): new_item.setup(data)
	
	equipment[slot] = new_item
	if slot == "weapon":
		weapon_node = new_item
		base_cooldown = weapon_node.attack_cd
		current_attack_style = weapon_node.attack_style
	recalculate_stats()

func _get_marker_for_slot(slot: String) -> Node2D:
	match slot:
		"head": return head_marker
		"body": return body_marker
		"weapon": return weapon_marker
		"boots": return boots_marker
		"back": return back_marker
	return null

func recalculate_stats() -> void:
	_initialize_base_stats()
	
	if skill_container:
		for child in skill_container.get_children():
			child.queue_free()
	
	skill_directory = {"major": null, "utility": [], "passive": []}
	
	var speed_mod: float = 0.0
	var damage_bonus: float = 0.0
	var iq_bonus: int = 0
	var aggro_bonus: float = 0.0
	var dex_bonus: float = 0.0
	var precision_bonus: float = 0.0
	
	# 1. Gather all Resources (Mutations + Equipment)
	var sources: Array[Resource] = []
	if active_major_mutation: sources.append(active_major_mutation)
	sources.append_array(active_minor_mutations)
	for slot in equipment: 
		if "data" in equipment[slot]: sources.append(equipment[slot].data)
	
	# 2. Accumulate stats and skills
	for data in sources:
		# Stats
		max_health += data.get("health_bonus") if data.get("health_bonus") else 0.0
		damage_bonus += data.get("damage_bonus") if data.get("damage_bonus") else 0.0
		speed_mod += data.get("speed_mod") if data.get("speed_mod") else 0.0
		iq_bonus += data.get("IQ_bonus") if data.get("IQ_bonus") else 0
		aggro_bonus += data.get("aggression_bonus") if data.get("aggression_bonus") else 0.0
		dex_bonus += data.get("dexterity_bonus") if data.get("dexterity_bonus") else 0.0
		precision_bonus += data.get("precision_bonus") if data.get("precision_bonus") else 0.0
		
		# Skills
		if "provided_skill" in data and data.provided_skill and skill_container:
			var skill_node = data.provided_skill.instantiate()
			skill_container.add_child(skill_node)
			if skill_node.has_method("setup"): skill_node.setup(self)
			
			# Categorize in directory
			if skill_node.get("is_passive"):
				skill_directory.passive.append(skill_node)
				if skill_node.has_method("activate_passive"): skill_node.activate_passive()
			elif data is MutationData and data.mutation_type == "major":
				skill_directory.major = skill_node
			else:
				skill_directory.utility.append(skill_node)
	
	# 3. Finalize math
	var modded_speed = speed * (1.0 + speed_mod)
	var modded_damage = damage + damage_bonus
	
	if active_major_mutation:
		max_health *= active_major_mutation.health_mult
		modded_speed *= active_major_mutation.speed_mult
		modded_damage *= active_major_mutation.damage_mult
		size = clamp(size * active_major_mutation.size_mult, stat_config.min_size, stat_config.max_size)
		
	max_health = max(max_health, stat_config.min_health)
	speed = clamp(modded_speed, stat_config.min_speed, stat_config.max_speed)
	damage = clamp(modded_damage, stat_config.min_damage, stat_config.max_damage)
	
	IQ = clamp(IQ + iq_bonus, stat_config.min_IQ, stat_config.max_IQ)
	aggression = clamp(aggression + aggro_bonus, stat_config.min_aggression, stat_config.max_aggression)
	dexterity = clamp(dexterity + dex_bonus, stat_config.min_dexterity, stat_config.max_dexterity)
	precision = clamp(precision + precision_bonus, stat_config.min_precision, stat_config.max_precision)
	
	self.scale = Vector2.ONE * size
	acceleration = 10.0 / size 
	_update_attack_range_by_style()
	retreat_threshold = attack_range * (1.1 - aggression)
	if nav_agent: nav_agent.target_desired_distance = attack_range
	current_health = min(current_health, max_health)
	health_changed.emit(current_health, max_health)

func _update_attack_range_by_style() -> void:
	match current_attack_style:
		AttackStyle.TACKLE: attack_range = weapon_node.attack_range if weapon_node else 150.0 * size
		AttackStyle.MELEE: attack_range = weapon_node.attack_range if weapon_node else 200.0 * size
		AttackStyle.RANGED: attack_range = weapon_node.attack_range if weapon_node else 500.0

func take_damage(amount: float, attacker_ref: Creature = null) -> void:
	if not multiplayer.is_server(): return
	
	if is_invulnerable or current_health <= 0: return
	current_health -= amount
	health_changed.emit(current_health, max_health)
	if current_health <= 0: die()
	else:
		_trigger_hit_iframe()
		search_for_target(attacker_ref)

func _trigger_hit_iframe() -> void:
	is_invulnerable = true
	await get_tree().create_timer(0.1).timeout
	is_invulnerable = false

func die() -> void:
	died.emit()
	set_physics_process(false)
	queue_free()

func search_for_target(attacker_ref: Creature = null) -> void:
	var creatures = get_tree().get_nodes_in_group("creature")
	var best_score = INF
	var best_node = null
	
	for c in creatures:
		if c == self or not is_instance_valid(c) or c.current_health <= 0: continue
		var dist = global_position.distance_to(c.global_position)
		var health_factor = 0.9 + ((c.current_health / c.max_health) * 0.2)
		var score = pow(dist, 1.2) * health_factor
		if c == attacker_ref: score *= 0.8
		if score < best_score:
			best_score = score
			best_node = c
			
	if best_node and best_node != target:
		var current_score = INF
		if is_instance_valid(target) and target.current_health > 0:
			var dist_to_current = global_position.distance_to(target.global_position)
			current_score = pow(dist_to_current, 1.2) * (0.9 + ((target.current_health / target.max_health) * 0.2))
			
		var threshold = 0.7 + (IQ * 0.02) - (aggression * 0.2)
		if best_score < current_score * threshold:
			if is_instance_valid(target) and target.attack_started.is_connected(_on_target_attack_started):
				target.attack_started.disconnect(_on_target_attack_started)
			target = best_node
			if is_instance_valid(target): target.attack_started.connect(_on_target_attack_started)

func has_line_of_sight() -> bool:
	if not los_ray: return true
	los_ray.force_raycast_update()
	return !los_ray.is_colliding() or los_ray.get_collider() == target

func _on_target_attack_started(attacker_node: Creature, defender: Creature) -> void:
	if defender != self or is_attacking: return
	var dodge_chance = 0.15 + (IQ * 0.07)
	if (current_health / max_health) < 0.3 and aggression > 0.5: dodge_chance *= 0.2 
	if randf() < dodge_chance: dodge(attacker_node)

func dodge(attacker_node: Creature) -> void:
	is_attacking = true 
	is_dashing = true
	var attack_dir = attacker_node.global_position.direction_to(global_position)
	var dodge_dir = Vector2(-attack_dir.y, attack_dir.x) * (1 if randf() > 0.5 else -1)
	var dodge_distance = (150.0 + (speed * 0.2) + (20.0 * dexterity)) / max(0.5, size)
	velocity = dodge_dir * (dodge_distance / 0.2)
	await get_tree().create_timer(0.2).timeout
	is_dashing = false
	await get_tree().create_timer(0.1).timeout
	is_attacking = false

func _update_behavior_timer(delta: float) -> void:
	behavior_timer += delta
	var persistence_mod = (IQ * 0.15) + (aggression * -0.1)
	if behavior_timer >= next_behavior_change * (1.0 + persistence_mod):
		_randomize_behavior()
		behavior_timer = 0.0

func _randomize_behavior() -> void:
	next_behavior_change = randf_range(2.0, 5.0) * (1.5 - aggression)
	circle_direction = 1 if randf() > 0.5 else -1
	is_circling = randf() < aggression
	speed_mult = randf_range(0.8, 1.2)
	_pick_intended_action() # Determine what we WANT to do next

func _pick_intended_action() -> void:
	var choices = [] # Array of { "action": node/string, "weight": float, "range": float }
	
	# Fallback Weapon Attack (Base Weight influenced by Aggression)
	var weapon_range = attack_range # Uses the cached _update_attack_range_by_style value
	choices.append({"action": "weapon", "weight": 100.0 * (1.0 + aggression), "range": weapon_range})
	
	# Check Major Skill
	if skill_directory.major and skill_directory.major.has_method("can_use") and skill_directory.major.can_use(target):
		var weight = 250.0 * (1.0 + (IQ * 0.1))
		choices.append({"action": skill_directory.major, "weight": weight, "range": skill_directory.major.skill_range})
	
	# Check Utility Skills
	for skill in skill_directory.utility:
		if skill.has_method("can_use") and skill.can_use(target):
			var weight = 150.0 + (aggression * 50.0)
			choices.append({"action": skill, "weight": weight, "range": skill.skill_range})
			
	# Weighted Random Selection
	var total_weight = 0.0
	for c in choices: total_weight += c.weight
	
	var roll = randf() * total_weight
	var cursor = 0.0
	for c in choices:
		cursor += c.weight
		if roll <= cursor:
			current_intended_action = c
			break

## !!! DYNAMIC RANGE CHECKING HIGHLIGHT !!!
## The creature now moves according to the range of its PICKED action (Skill or Weapon).
func movement(delta: float) -> void:
	if not current_intended_action: _pick_intended_action()
	
	var target_range = current_intended_action.range
	var distance_to_target = global_position.distance_to(target.global_position)
	var dir_to_target = global_position.direction_to(target.global_position)
	var has_los = has_line_of_sight()
	
	if nav_agent:
		nav_agent.target_desired_distance = target_range if has_los else 10.0
	
	# 1. Navigation: If too far for the INTENDED action or no LOS
	if distance_to_target > target_range + 20.0 or not has_los:
		# Add a small safety check so we don't jitter when arriving
		if not nav_agent.is_navigation_finished():
			var move_dir = global_position.direction_to(nav_agent.get_next_path_position())
			velocity = velocity.lerp(move_dir * (speed * speed_mult), acceleration * delta)
		else:
			if not has_los:
				velocity = velocity.lerp(dir_to_target * (speed * 0.5), acceleration * delta)
			else:
				velocity = velocity.lerp(Vector2.ZERO, acceleration * delta)
	else:
		# 2. Execution: If in range for the intended action
		if can_attack:
			attack()
			return 
		else:
			# 3. Combat Spacing (Kiting/Circling)
			var eff_retreat = retreat_threshold
			if (current_health / max_health) < 0.3: 
				eff_retreat = 0.0 if aggression > 0.5 else eff_retreat * 2.0
			
			if distance_to_target < eff_retreat:
				var r_speed = 0.3
				if current_attack_style == AttackStyle.RANGED: r_speed = 0.9 if not can_attack else 0.1
				
				var target_vel = -dir_to_target * (speed * r_speed)
				
				if get_slide_collision_count() > 0:
					var normal = get_last_slide_collision().get_normal()
					# NEW: Explicitly repel from the wall! (Slide + Push Outward)
					target_vel = target_vel.slide(normal) + (normal * speed * 0.5)
					
					if get_real_velocity().length() < 15.0:
						var escape_dir = Vector2(-dir_to_target.y, dir_to_target.x) * circle_direction
						target_vel = escape_dir * (speed * r_speed)
						
				velocity = velocity.lerp(target_vel, acceleration * delta)
					
			elif is_circling:
				var side_dir = Vector2(-dir_to_target.y, dir_to_target.x) * circle_direction
				var range_correction = (distance_to_target - target_range) * 0.05
				var circle_vector = (side_dir + (dir_to_target * range_correction)).normalized()
				
				var target_vel = circle_vector * (speed * 0.6 * speed_mult)
				
				if get_slide_collision_count() > 0:
					var normal = get_last_slide_collision().get_normal()
					# NEW: Explicitly repel from the wall! (Slide + Push Outward)
					target_vel = target_vel.slide(normal) + (normal * speed * 0.5)
					
					# Reverse direction if we hit a wall relatively hard
					if velocity.normalized().dot(normal) < -0.2: 
						circle_direction *= -1
				
				velocity = velocity.lerp(target_vel, acceleration * delta)
			else:
				velocity = velocity.lerp(Vector2.ZERO, acceleration * delta)
				
	move_and_slide()

## Refactored to execute either a skill or a standard weapon attack
func attack() -> void:
	if is_attacking or not current_intended_action: return
	is_attacking = true
	can_attack = false
	is_telegraphing = true
	velocity = Vector2.ZERO
	
	# Dexterity influences wind-up time
	await get_tree().create_timer(max(0.05, 0.3 / dexterity)).timeout 
	is_telegraphing = false
	
	var base_dir = look_direction
	var jitter = PI/9 if current_attack_style == AttackStyle.RANGED else PI/12
	var attack_dir = base_dir.rotated(randf_range(-jitter, jitter) * (1.0 - precision))
	attack_started.emit(self, target)
	
	# EXECUTION PHASE
	if current_intended_action.action is String and current_intended_action.action == "weapon":
		_execute_weapon_attack(attack_dir)
	elif current_intended_action.action is Node and current_intended_action.action.has_method("execute"):
		await current_intended_action.action.execute(target, attack_dir)
	
	is_recovering = true 
	await get_tree().create_timer(0.3).timeout
	is_recovering = false
	is_attacking = false 
	current_intended_action = {} # Clear intent after attack
	_on_attack_cooldown_finished()

func _execute_weapon_attack(dir: Vector2) -> void:
	match current_attack_style:
		AttackStyle.TACKLE, AttackStyle.MELEE:
			var dash_dur = 0.25
			velocity = dir * ((attack_range * 2.0) / dash_dur)
			is_dashing = true
			rpc("rpc_play_weapon_effects", damage, dir)
			await get_tree().create_timer(dash_dur).timeout
			is_dashing = false
		AttackStyle.RANGED:
			rpc("rpc_play_weapon_effects", damage, dir)
			await get_tree().create_timer(0.2).timeout

@rpc("authority", "call_local", "reliable")
func rpc_play_weapon_effects(dmg: float, _dir: Vector2) -> void:
	if weapon_node: 
		weapon_node.activate(dmg, self)
	elif current_attack_style == AttackStyle.RANGED:
		_fire_projectile(_dir)
	elif body_hitbox:
		_manual_hitbox_activate(body_hitbox, dmg)

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
