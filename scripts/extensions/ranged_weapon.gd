class_name RangedWeapon extends Weapon

@export_group("Ranged Settings")
@export var projectile_scene: PackedScene
@export var muzzle: Marker2D

func activate(base_damage: float, p_attacker: Creature) -> void:
	super(base_damage, p_attacker)
	
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
		proj.launch(direction, base_damage, attacker)

func look_at_direction(look_direction: Vector2) -> void:
	var look_angle = look_direction.angle()
	rotation = look_angle
	sprite.flip_h = look_direction.x > 0
