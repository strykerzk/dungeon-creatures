class_name Projectile extends Area2D

var combat_data: CombatData = null
var velocity: Vector2 = Vector2.ZERO

func _enter_tree() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _init():
	# Projectiles hit bodies such as Players and Environment
	set_collision_layer_value(6, true)
	set_collision_mask_value(1, true)
	set_collision_mask_value(3, true)

func _physics_process(delta: float) -> void:
	global_position += velocity * delta

func _on_body_entered(body: Node2D) -> void:
	queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area.name != "Hurtbox" or not multiplayer.is_server(): return
	var entity = area.get_parent()
	if not combat_data.is_enemy(entity): return
	if entity.has_method("take_damage"):
		entity.take_damage(combat_data.damage, combat_data.attacker_id)
	queue_free()

func launch(direction: Vector2, data: CombatData, p_speed: float = 1000.0) -> void:
	combat_data = data
	velocity = direction.normalized() * p_speed
	rotation = velocity.angle()
