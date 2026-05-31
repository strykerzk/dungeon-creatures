class_name BaseSkill extends Node2D

## Base class for all modular creature abilities.
## Designed to be instantiated as a child of the Creature's skill_container.

@export_group("Skill Configuration")
@export var skill_name: String = "Generic Skill"
@export var skill_range: float = 200.0  
@export var cooldown_time: float = 5.0 
@export var is_passive: bool = false
@export var priority_weight: float = 200.0 ## Base weight used for the AI deliberation roll
@export var requires_los: bool = true

var creature: Creature = null
var current_cooldown: float = 0.0

## Called by Creature during recalculate_stats()
func setup(p_creature: Creature) -> void:
	creature = p_creature
	name = skill_name

func _physics_process(delta: float) -> void:
	if current_cooldown > 0:
		current_cooldown -= delta

func can_use(_target: Creature) -> bool:
	if is_passive or not creature or not is_instance_valid(creature):
		return false
	return current_cooldown <= 0

## Called during recalculate_stats if is_passive is true.
## Use this to connect signals or apply persistent buffs.
func activate_passive() -> void:
	pass

func build_combat_data(damage: float) -> CombatData:
	var data = CombatData.new()
	data.attacker_id = creature.player_id
	#data.team_id = creature.team_id
	data.damage = damage
	return data

## IMPORTANT: In creature.gd, this is called with 'await'.
## If your skill takes time (dashes, animations), use 'await get_tree().create_timer().timeout' inside.
func execute(target: Creature, attack_dir: Vector2) -> void:
	# 1. Trigger cooldown
	current_cooldown = cooldown_time
	
	# 2. Logic (To be overridden)
	# Example: Spawn a projectile, apply velocity to creature, etc.
	print("[Skill] Executed: ", skill_name)
	
	# 3. Finalization
	# If this function returns immediately, the creature moves to recovery (0.15s).
	# If you want a 1-second channel, add: await get_tree().create_timer(1.0).timeout
	return
