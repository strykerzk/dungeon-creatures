class_name Projectile extends Area2D

var damage_value: float = 0.0
var attacker: Creature = null

var velocity: Vector2 = Vector2.ZERO
var speed: float = 600.0

func _enter_tree() -> void:
	body_entered.connect(_on_body_entered)

func _init():
	# Projectiles hit bodies such as Players and Environment
	set_collision_layer_value(6, true)
	set_collision_mask_value(1, true)
	set_collision_mask_value(3, true)

func _physics_process(delta: float) -> void:
	global_position += velocity * delta

func _on_body_entered(body: Node2D) -> void:
	if body == attacker: return
	
	if multiplayer.is_server():
		if body.has_method("take_damage"):
			body.take_damage(damage_value, attacker)
			print("Damage dealt from projectile!")
	
	queue_free()

func launch(direction: Vector2, p_damage: float, p_attacker: Creature, p_speed: float) -> void:
	damage_value = p_damage
	attacker = p_attacker
	speed = p_speed
	
	velocity = direction.normalized() * speed
	rotation = velocity.angle()
