class_name RangedWeapon extends Weapon

@export_group("Ranged Settings")
@export var projectile_scene: PackedScene
@export var projectile_speed: float

func setup(equipment_resource: EquipmentData) -> void:
	super(equipment_resource)
	projectile_speed = data.projectile_speed

func activate(p_combat_data: CombatData) -> void:
	super(p_combat_data)
	
	if not projectile_scene: return
	
	var proj = projectile_scene.instantiate()
	proj.global_position = global_position
	var direction = owner_creature.look_direction if owner_creature else Vector2.RIGHT
	
	# Spawn in world space
	get_tree().current_scene.add_child(proj)
	
	if proj.has_method("launch"):
		proj.launch(direction, combat_data, projectile_speed)

func look_at_direction(look_direction: Vector2) -> void:
	var look_angle = look_direction.angle()
	rotation = look_angle
	sprite.flip_v = look_direction.x < 0
