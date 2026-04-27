class_name Creature extends CharacterBody2D

@export var stat_config: CreatureData

# Stats
var base_health: float
var damage: float
var speed: float
var IQ: int

# AI Movement
@export var target: Node2D
@export var nav_agent: NavigationAgent2D
@export var nav_timer: Timer
var look_direction: Vector2 = Vector2.ZERO
var attack_range: float = 150.0 # Min distance from target
var acceleration: float = 50.0

# Attacking
var can_attack: bool = true
var is_attacking: bool = false

func _ready() -> void:
	base_health = stat_config.base_health
	damage = stat_config.damage
	speed = stat_config.speed
	IQ = stat_config.IQ
	
	# Navigation setup
	nav_agent.target_position = target.global_position
	nav_agent.target_desired_distance = attack_range
	nav_timer.connect("timeout", Callable(self, "_on_nav_timer_timeout"))

func _physics_process(delta: float) -> void:
	
	# Basic movement
	movement(delta)
	
	
	# Attacking
	
func movement(delta: float) -> void:
	if target:
		if !nav_agent.target_position == target.global_position:
			nav_agent.target_position = target.global_position
		var direction = global_position.direction_to(nav_agent.get_next_path_position())
		
		if !nav_agent.is_target_reached():
			velocity = velocity.lerp(direction * speed, acceleration * delta)
			move_and_slide()

func attack() -> void:
	can_attack = false
	is_attacking = true

func spell_1() -> void:
	pass

func spell_2() -> void:
	pass
