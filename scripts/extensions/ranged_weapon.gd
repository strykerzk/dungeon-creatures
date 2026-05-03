class_name RangedWeapon extends Weapon

@export_group("Ranged Settings")
@export var projectile_scene: PackedScene
@export var muzzle: Marker2D
@export var projectile_speed: float
var muzzle_y: float

func _ready() -> void:
	super()
	
	muzzle_y = muzzle.position.y

func setup(equipment_resource: EquipmentData) -> void:
	super(equipment_resource)
	projectile_speed = data.projectile_speed

func activate(base_damage: float, p_attacker: Creature) -> void:
	super(base_damage, p_attacker)
	
	if not projectile_scene: return
	
	var proj = projectile_scene.instantiate()
	
	proj.global_position = muzzle.global_position if muzzle else global_position
	
	# Direction towards current target
	var direction = attacker.look_direction
	
	# Spawn in world space
	get_tree().current_scene.add_child(proj)
	
	if proj.has_method("launch"):
		proj.launch(direction, base_damage, attacker, projectile_speed)

func look_at_direction(look_direction: Vector2) -> void:
	var look_angle = look_direction.angle()
	rotation = look_angle
	sprite.flip_v = look_direction.x < 0
	var target_y = -muzzle_y if look_direction.x < 0 else muzzle_y
	if not is_equal_approx(muzzle.position.y, target_y):
		muzzle.position.y = target_y
