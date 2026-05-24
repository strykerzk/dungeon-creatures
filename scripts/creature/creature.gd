class_name Creature extends CharacterBody2D

@export var stat_config: CreatureData
var species: String = "duck" # Default species
var id: int = 1

enum AttackStyle { TACKLE, MELEE, RANGED }

# --- EQUIPMENT SLOTS & PAPER DOLL REFS ---
@export_group("Paper Doll Sprites")
@onready var paper_doll: CanvasGroup = %PaperDoll
@onready var flip_container: Node2D = $FlipContainer
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@export var doll_back: Sprite2D
@export var doll_base: Sprite2D
@export var doll_boots: Sprite2D
@export var doll_armor: Sprite2D
@export var doll_head: Sprite2D
@export var weapon_marker: Marker2D

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
@export var whisker_front: RayCast2D
@export var whisker_left: RayCast2D
@export var whisker_right: RayCast2D
var is_combat_locked: bool = false
var is_dead: bool = false

# --- SIGNALS ---
signal attack_started(attacker: Creature, defender: Creature)
signal health_changed(current: float, total: float)
signal died()

# --- SFX REFS ---
@export_group("Sound Effects")
@export var sfx_hit: AudioStreamPlayer2D
@export var sfx_attack: AudioStreamPlayer2D
@export var sfx_dodge: AudioStreamPlayer2D

# --- VFX REFS ---
@export_group("Visual Effects")
@export var dmg_number_scene: PackedScene

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
@onready var skill_container: Node2D = $SkillContainer # Container for instantiated skill nodes
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
var is_dodging: bool = false

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
	setup()
	_initialize_base_stats()
	recalculate_stats()
	if nav_timer: nav_timer.timeout.connect(_on_nav_timer_timeout)
	if body_hitbox: body_hitbox.monitoring = false
	setup_physics_layers()
	_randomize_behavior()

func setup() -> void:
	id = int(name)

func _initialize_base_stats() -> void:
	if stat_config:
		species = stat_config.name
		max_health = stat_config.get("base_health") if stat_config.get("base_health") != null else 100.0
		damage = stat_config.get("damage") if stat_config.get("damage") != null else 10.0
		speed = stat_config.get("speed") if stat_config.get("speed") != null else 250.0
		speed *= randf_range(0.9, 1.1) # Randomize for variance
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
	
	if is_combat_locked: return
	
	if not is_instance_valid(target) or target.is_queued_for_deletion() or target.current_health <= 0:
		target = null
		if not is_attacking: search_for_target()
		return
	
	if not is_attacking:
		look_direction = global_position.direction_to(target.global_position)
	
	if los_ray:
		los_ray.target_position = los_ray.to_local(target.global_position)

	if is_attacking or is_dodging:
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
	
	if flip_container:
		if look_direction.x < 0:
			flip_container.scale.x = -1
		else:
			flip_container.scale.x = 1

	# --- NEW: Procedural Animation Handling ---
	if animation_player:
		if is_telegraphing:
			animation_player.play("telegraph")
			
		elif is_dodging:
			if animation_player.current_animation != "dodge_forward" and animation_player.current_animation != "dodge_back":
				var dot_prod = velocity.normalized().dot(look_direction.normalized())
				if dot_prod >= -0.2: 
					animation_player.play("dodge_forward")
				else:
					animation_player.play("dodge_back")
					
		# Velocity Deadzone
		elif velocity.length() > 15.0:
			animation_player.play("run")
		else:
			animation_player.play("idle")


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
		equipment.erase(slot)
	
	equipment[slot] = data
	
	if slot == "weapon" and data.visual_scene:
		if weapon_node: weapon_node.queue_free()
		weapon_node = data.visual_scene.instantiate()
		add_child(weapon_node)
		weapon_node.global_position = weapon_marker.global_position
		if weapon_node.has_method("reposition_visual"):
			weapon_node.reposition_visual(weapon_marker)
		if weapon_node.has_method("setup"): weapon_node.setup(data)
		base_cooldown = weapon_node.attack_cd
		current_attack_style = weapon_node.attack_style
	elif slot != "weapon":
		var target_sprite = _get_sprite_for_slot(slot)
		if target_sprite and data.get("visual_id") and data.visual_id != "":
			var file_path = "res://art/equipment/"+slot+"/"+data.visual_id+"_"+species+".png"
			
			if ResourceLoader.exists(file_path):
				target_sprite.texture = load(file_path)
			else:
				push_warning("[PaperDoll] Missing art " + file_path)
	
	recalculate_stats()

func _get_sprite_for_slot(slot: String) -> Node2D:
	match slot:
		"head": return doll_head
		"body": return doll_armor
		"weapon": return null
		"boots": return doll_boots
		"back": return doll_back
	return null

func recalculate_stats() -> void:
	_initialize_base_stats()
	
	if skill_container:
		for child in skill_container.get_children():
			skill_container.remove_child(child)
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
		if equipment[slot] is EquipmentData: sources.append(equipment[slot])
	
	
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
	acceleration = min(10.0 / size, 30.0) 
	_update_attack_range_by_style()
	retreat_threshold = attack_range * (1.1 - aggression)
	if nav_agent: nav_agent.target_desired_distance = attack_range
	current_health = min(current_health, max_health)
	health_changed.emit(current_health, max_health)

func _update_attack_range_by_style() -> void:
	match current_attack_style:
		AttackStyle.TACKLE: attack_range = weapon_node.attack_range if weapon_node else 350.0 * size
		AttackStyle.MELEE: attack_range = weapon_node.attack_range if weapon_node else 450.0 * size
		AttackStyle.RANGED: attack_range = weapon_node.attack_range if weapon_node else 1000.0

func take_damage(amount: float, attacker_ref: Creature = null) -> void:
	if not multiplayer.is_server(): return
	
	if is_invulnerable or current_health <= 0 or is_dead: return
	
	current_health -= amount
	health_changed.emit(current_health, max_health)
	
	rpc("client_spawn_damage_number", amount)
	
	sfx_hit.pitch_scale = randf_range(0.9, 1.1)
	sfx_hit.play()
	
	var shake_intensity: float = clamp(amount * 0.8, 3.0, 25.0)
	rpc("client_trigger_shake", shake_intensity)
	
	if current_health <= 0:
		is_dead = true
		die(attacker_ref)
	else:
		_trigger_hit_iframe()
		search_for_target(attacker_ref)

@rpc("authority", "call_local", "unreliable")
func client_spawn_damage_number(amount: float) -> void:
	if not dmg_number_scene: return
	
	var dmg_num = dmg_number_scene.instantiate()
	dmg_num.amount = amount
	
	# Add it to the Arena/Dungeon, NOT the Creature. 
	# If we add it to the creature, it will move with them while they run!
	get_tree().current_scene.add_child(dmg_num)
	
	# Spawn it slightly above their head, with a tiny bit of random jitter 
	# so multiple hits don't stack perfectly on top of each other
	var jitter = Vector2(randf_range(-15, 15), randf_range(-15, 15))
	dmg_num.global_position = global_position + jitter - Vector2(0, 40)

func _trigger_hit_iframe() -> void:
	is_invulnerable = true
	if paper_doll and paper_doll.material:
		paper_doll.material.set_shader_parameter("flash_modifier", 1.0)
		var tween = create_tween()
		tween.tween_method(
			func(val): paper_doll.material.set_shader_parameter("flash_modifier", val),
			1.0, 0.0, 0.2
		)
	
	await get_tree().create_timer(0.2).timeout
	is_invulnerable = false

func die(attacker_ref: Creature = null) -> void:
	died.emit()
	set_physics_process(false)
	
	var yeet_dir = Vector2(randf_range(-1, 1), -1).normalized() # Fallback
	if attacker_ref and is_instance_valid(attacker_ref):
		yeet_dir = attacker_ref.global_position.direction_to(global_position)
		yeet_dir = (yeet_dir + Vector2(0, -0.8)).normalized() # Arc it upwards
		
	rpc("client_play_death_animation", yeet_dir)
	
	await get_tree().create_timer(2.0).timeout
	queue_free()

@rpc("authority", "call_local", "unreliable")
func client_trigger_shake(intensity: float) -> void:
	if typeof(StageManager) != TYPE_NIL:
		StageManager.screen_shake_requested.emit(intensity)

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
	if defender != self or is_attacking or is_dodging: return
	var dodge_chance = 0.15 + (IQ * 0.07)
	if (current_health / max_health) < 0.3 and aggression > 0.5: dodge_chance *= 0.2 
	if randf() < dodge_chance: dodge(attacker_node)
	else: print("Dodge Failed!")

func dodge(attacker_node: Creature) -> void:
	is_dodging = true 
	is_dashing = true
	sfx_dodge.play()
	var attack_dir = attacker_node.global_position.direction_to(global_position)
	var dodge_dir = Vector2(-attack_dir.y, attack_dir.x) * (1 if randf() > 0.5 else -1)
	var dodge_distance = (250.0 + (speed * 0.2) + (40.0 * dexterity)) / max(0.5, size)
	velocity = dodge_dir * (dodge_distance / 0.2)
	await get_tree().create_timer(0.2).timeout
	is_dashing = false
	await get_tree().create_timer(0.1).timeout
	is_dodging = false

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
	var choices = [] # Array of { "action": node/string, "weight": float, "range": float, "requires_los": bool }
	
	# Fallback Weapon Attack (Base Weight influenced by Aggression)
	var weapon_range = attack_range # Uses the cached _update_attack_range_by_style value
	choices.append({"action": "weapon", "weight": 100.0 * (1.0 + aggression), "range": weapon_range, "requires_los": true})
	
	# Check Major Skill
	if skill_directory.major and skill_directory.major.has_method("can_use") and skill_directory.major.can_use(target):
		var weight = 250.0 * (1.0 + (IQ * 0.1))
		var req_los = skill_directory.major.requires_los if "requires_los" in skill_directory.major else true
		choices.append({"action": skill_directory.major, "weight": weight, "range": skill_directory.major.skill_range, "requires_los": req_los})
	
	# Check Utility Skills
	for skill in skill_directory.utility:
		if skill.has_method("can_use") and skill.can_use(target):
			var weight = 200.0 + (aggression * 50.0)
			var req_los = skill.requires_los if "requires_los" in skill else true
			choices.append({"action": skill, "weight": weight, "range": skill.skill_range, "requires_los": req_los})
			
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

func movement(delta: float) -> void:
	if not current_intended_action: _pick_intended_action()
	
	var target_range = current_intended_action.range
	var distance_to_target = global_position.distance_to(target.global_position)
	var dir_to_target = global_position.direction_to(target.global_position)
	if dir_to_target == Vector2.ZERO:
		dir_to_target = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	
	var has_los = has_line_of_sight()
	
	var requires_los = current_intended_action.get("requires_los", true)
	var action_ready = has_los or not requires_los
	
	if nav_agent:
		nav_agent.target_desired_distance = target_range if action_ready else 10.0
	
	# 1. Navigation: If too far for the INTENDED action or no LOS
	if distance_to_target > target_range + 20.0 or not action_ready:
		if not nav_agent.is_navigation_finished():
			var move_dir = global_position.direction_to(nav_agent.get_next_path_position())
			var target_vel = move_dir * (speed * speed_mult)
			target_vel = _apply_whisker_avoidance(target_vel) # NEW: Steer away from corners!
			velocity = velocity.lerp(target_vel, acceleration * delta)
		else:
			if not action_ready:
				var target_vel = dir_to_target * (speed * 0.5)
				target_vel = _apply_whisker_avoidance(target_vel)
				velocity = velocity.lerp(target_vel, acceleration * delta)
			else:
				velocity = velocity.lerp(Vector2.ZERO, acceleration * delta)
	else:
		# 2. Execution
		if can_attack:
			await get_tree().create_timer(randf_range(0.1, 0.5)).timeout
			attack()
			return 
		else:
			# 3. Combat Spacing (Kiting/Circling)
			var eff_retreat = retreat_threshold
			if (current_health / max_health) < 0.3: 
				eff_retreat = 0.0 if aggression > 0.5 else eff_retreat * 2.0
			
			var target_vel = Vector2.ZERO
			
			if distance_to_target < eff_retreat:
				var r_speed = 0.3
				if current_attack_style == AttackStyle.RANGED: r_speed = 0.9 if not can_attack else 0.1
				
				target_vel = -dir_to_target * (speed * r_speed)
					
			elif is_circling:
				var side_dir = Vector2(-dir_to_target.y, dir_to_target.x) * circle_direction
				var range_correction = (distance_to_target - target_range) * 0.05
				var circle_vector = (side_dir + (dir_to_target * range_correction)).normalized()
				
				target_vel = circle_vector * (speed * 0.6 * speed_mult)
			else:
				target_vel = dir_to_target * (speed * 0.2)
			
			# Apply steering to spacing/circling so they smoothly slide along walls instead of jittering!
			target_vel = _apply_whisker_avoidance(target_vel)
			velocity = velocity.lerp(target_vel, acceleration * delta)
			
	move_and_slide()

func _apply_whisker_avoidance(desired_velocity: Vector2) -> Vector2:
	if desired_velocity.length() < 1.0 or not whisker_front: 
		return desired_velocity
		
	var avoidance = Vector2.ZERO
	var hit_count = 0
	var angle = desired_velocity.angle()
	
	# FIX 1: Narrowed the whisker spread (0.5 rad is ~28 degrees)
	whisker_front.global_rotation = angle
	whisker_left.global_rotation = angle - 0.5
	whisker_right.global_rotation = angle + 0.5
	
	whisker_front.force_raycast_update()
	whisker_left.force_raycast_update()
	whisker_right.force_raycast_update()
	
	if whisker_front.is_colliding():
		avoidance += whisker_front.get_collision_normal() * 2.0
		hit_count += 1
	if whisker_left.is_colliding():
		avoidance += whisker_left.get_collision_normal()
		hit_count += 1
	if whisker_right.is_colliding():
		avoidance += whisker_right.get_collision_normal()
		hit_count += 1
		
	if hit_count > 0:
		var avg_normal = avoidance.normalized()
		
		# FIX 2: Use Godot's built-in slide math to deflect momentum ALONG the wall
		var steered_vel = desired_velocity.slide(avg_normal)
		
		# FIX 3: The Stalemate Breaker. 
		# If we hit the wall dead-on, slide() returns (0,0).
		# We calculate a sideways (tangent) vector to force the creature to "pick a side" and slide!
		if steered_vel.length() < (desired_velocity.length() * 0.1):
			var tangent = Vector2(-avg_normal.y, avg_normal.x)
			
			# Pick the tangent side closest to where they want to go
			if tangent.dot(desired_velocity) < 0:
				tangent = -tangent
				
			# If perfectly perpendicular, force a consistent side based on their internal circling logic
			if tangent.dot(desired_velocity) == 0:
				tangent = tangent * circle_direction 
				
			steered_vel = tangent * desired_velocity.length()
			
		# Smoothly blend the current velocity into the new sliding velocity
		return desired_velocity.lerp(steered_vel.normalized() * desired_velocity.length(), 0.8)
		
	return desired_velocity

## Refactored to execute either a skill or a standard weapon attack
func attack() -> void:
	if is_attacking or is_dodging or not current_intended_action: return
	is_attacking = true
	can_attack = false
	is_telegraphing = true
	velocity = Vector2.ZERO
	
	# Dexterity influences wind-up time
	await get_tree().create_timer(randf_range(0.05, 0.3 / dexterity)).timeout 
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
	
	sfx_attack.pitch_scale = randf_range(0.9, 1.1)
	sfx_attack.play()

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

@rpc("authority", "call_local", "reliable")
func client_play_death_animation(yeet_dir: Vector2) -> void:
	# 1. Stop processing standard visuals
	set_process(false) 
	if animation_player:
		animation_player.stop()
		
	# 2. Time Stop (Smash Bros hit-stop)
	Engine.time_scale = 0.1
	
	# Ignore time scale for this specific timer (the 'true' flag at the end) 
	# so it reliably restores speed after 0.15 real-time seconds!
	var timer = get_tree().create_timer(1.0, true, false, true)
	timer.timeout.connect(func(): Engine.time_scale = 1.0)
	
	# 3. Super Screen Shake
	if typeof(StageManager) != TYPE_NIL:
		StageManager.screen_shake_requested.emit(30.0)
		
	# 4. The Yeet (Smash Bros Launch)
	var tween = create_tween().set_parallel(true)
	
	# Spin wildly
	tween.tween_property(self, "rotation_degrees", 1080.0 * (1 if randf() > 0.5 else -1), 1.5)
	
	# Launch way off screen
	var launch_pos = global_position + (yeet_dir * 1500.0)
	tween.tween_property(self, "global_position", launch_pos, 1.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	
	# Fade Out
	tween.tween_property(self, "modulate:a", 0.0, 1.0).set_delay(0.5)

func _on_attack_cooldown_finished() -> void:
	if not is_inside_tree(): return
	var cooldown = base_cooldown / max(0.1, (1.0 + (dexterity * 0.5)))
	cooldown *= randf_range(0.85, 1.15) # Randomize for variance
	await get_tree().create_timer(cooldown).timeout
	can_attack = true

func _on_nav_timer_timeout() -> void:
	if target: nav_agent.target_position = target.global_position
