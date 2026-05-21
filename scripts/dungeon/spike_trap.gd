extends Area2D

@export var damage: float = 15.0
@export var stun_time: float = 0.8
@export var active_time: float = 1.0
@export var inactive_time: float = 1.5
@export var delay: float = 0.0
@export_enum("Inactive", "Active") var starting_state: int

@onready var sprite: Sprite2D = $Sprite2D
@onready var timer: Timer = $Timer

var is_active: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	timer.timeout.connect(_on_timer_timeout)
	await get_tree().create_timer(delay).timeout
	match starting_state:
		0: _set_inactive()
		1: _set_active()

func _set_active() -> void:
	is_active = true
	sprite.frame = 1 # Frame 1 = Spikes Up
	timer.start(active_time)
	
	# Instantly hit anyone standing on it when it pops up!
	for body in get_overlapping_bodies():
		_hit_body(body)

func _set_inactive() -> void:
	is_active = false
	sprite.frame = 0 # Frame 0 = Hidden
	timer.start(inactive_time)

func _on_timer_timeout() -> void:
	if is_active:
		_set_inactive()
	else:
		_set_active()

func _on_body_entered(body: Node2D) -> void:
	if is_active:
		_hit_body(body)

func _hit_body(body: Node2D) -> void:
	if body.has_method("apply_stun"):
		# Hits the Player!
		body.apply_stun(stun_time)
	elif body.has_method("take_damage") and multiplayer.is_server():
		# Hits the AI Creature!
		body.take_damage(damage)
