extends CharacterBody2D

@export_category("Player Settings")
@export_group("Movement Settings")
@export var max_speed: float = 300.0
@export var acceleration: float = 2500.0
@export var friction: float = 3000.0

@export_group("Dodge Roll Settings")
@export var roll_speed: float = 600.0
@export var roll_duration: float = 0.8
@export var roll_iframe_percent: float = 0.7 ## Percentage of roll that is invulnerable

@export_category("Node References")
@export var sprite: AnimatedSprite2D
@export var animation_tree: AnimationTree

enum State { NORMAL, ROLLING }
var current_state: State = State.NORMAL

var roll_direction: Vector2 = Vector2.DOWN
var is_invulnerable: bool = false

# --- INVENTORY ---
var inventory: Dictionary = {
	"weapon": [],
	"head": [],
	"body": [],
	"boots": [],
	"back": []
}

func _physics_process(delta: float) -> void:
	match current_state:
		State.NORMAL:
			_handle_move_state(delta)
		State.ROLLING:
			_handle_roll_state(delta)

func _handle_move_state(delta: float) -> void:
	var input = Input.get_vector("left", "right", "up", "down")
	
	if input != Vector2.ZERO:
		velocity = velocity.move_toward(input * max_speed, acceleration * delta)
		roll_direction = input.normalized()
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	
	move_and_slide()
	
	if Input.is_action_just_pressed("dodge"):
		_start_roll()
	
	handle_animations()

func handle_animations() -> void:
	sprite.flip_h = velocity.x < 0
	if current_state == State.ROLLING: sprite.play("dodge")
	elif velocity != Vector2.ZERO: sprite.play("run")
	else: sprite.play("idle")

func _start_roll() -> void:
	current_state = State.ROLLING
	is_invulnerable = true
	
	# Initial burst
	velocity = roll_direction * roll_speed
	
	# Duration Timer
	await get_tree().create_timer(roll_duration * roll_iframe_percent).timeout
	is_invulnerable = false
	
	await get_tree().create_timer(roll_duration * (1.0 - roll_iframe_percent)).timeout
	_end_roll()

func _handle_roll_state(_delta: float) -> void:
	# Ignore input, just move in fixed direction
	move_and_slide()

func _end_roll() -> void:
	current_state = State.NORMAL
	# Apply slight friction penalty after roll to prevent infinite rolling speed
	velocity *= 0.5

# --- INTERACTION & INVENTORY ---

## Called by dungeon loot items via Area2D signals
func try_pickup_item(item_data: EquipmentData) -> bool:
	# 1. Get limits from CreatureManager (assuming it tracks the current round)
	# For now, we'll use local defaults if CreatureManager isn't fully set up.
	var total_max = 5
	var type_max = 1
	
	if typeof(CreatureManager) != TYPE_NIL:
		total_max = CreatureManager.current_inv_total_limit
		type_max = CreatureManager.current_inv_type_limit

	# 2. Check total capacity
	var current_total = 0
	for key in inventory:
		current_total += inventory[key].size()
		
	if current_total >= total_max:
		_show_feedback("Bag Full!")
		return false
		
	# 3. Check type capacity
	if inventory[item_data.slot].size() >= type_max:
		_show_feedback("Too many " + item_data.slot + " items!")
		return false
		
	# 4. Add to inventory
	inventory[item_data.slot].append(item_data)
	_show_feedback("Picked up: " + item_data.item_name)
	return true

func _show_feedback(msg: String) -> void:
	print("[Player] ", msg)
	# Later: Trigger UI popup or floating text
