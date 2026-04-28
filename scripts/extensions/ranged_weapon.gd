extends Weapon
class_name RangedWeapon

@export_group("Ranged Settings")
@export var projectile_scene: PackedScene
@export var muzzle: Marker2D

func _physics_process(delta: float) -> void:
	look_at(look_direction)

func activate(base_damage: float, attacker: CharacterBody2D) -> void:
	if not projectile_scene: return
	
	var proj = projectile_scene.instantiate()
	# Spawn in world space
	get_tree().root.add_child(proj)
	
	proj.global_position = muzzle.global_position if muzzle else global_position
	
	# Direction towards current target
	var direction = Vector2.RIGHT
	if attacker.target:
		direction = attacker.global_position.direction_to(attacker.target.global_position)
	
	if proj.has_method("launch"):
		proj.launch(direction, base_damage * damage_mult, attacker)
