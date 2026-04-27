class_name Creature extends CharacterBody2D

@export var stat_config: CreatureData

# Stats
var base_health: float
var damage: float
var speed: float
var IQ: int

# AI
@export var target: Node2D
var look_direction: Vector2 = Vector2.ZERO

# Movement
@export var acceleration: float = 10.0
var distance_to_keep: float = 100.0 # Min distance from target

func _ready() -> void:
	base_health = stat_config.base_health
	damage = stat_config.damage
	speed = stat_config.speed
	IQ = stat_config.IQ

func _physics_process(delta: float) -> void:
	
	# Basic movement
	if target:
		var dir = (target.global_position - global_position).normalized()
		look_direction = dir
		
		var distance = global_position.distance_to(target.global_position)
		
		if distance > distance_to_keep:
			velocity = velocity.lerp(dir * speed, acceleration * delta)
		else:
			velocity = Vector2.ZERO
		
		move_and_slide()
	
	# Sprite flipping
	if is_instance_valid($Sprite2D):
		$Sprite2D.flip_h = look_direction.x > 0
