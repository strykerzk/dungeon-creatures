extends CharacterBody2D

@export_category("Player Settings")
@export_group("Movement Settings")
@export var max_speed: float = 180.0
@export var acceleration: float = 1200.0
@export var friction: float = 1600.0

@export_group("Dodge Roll Settings")
@export var roll_speed: float = 500.0
@export var roll_duration: float = 0.6
@export var roll_iframe_percent: float = 0.7 ## Percentage of roll that is invulnerable

@export_category("Node References")
@export var sprite: AnimatedSprite2D
@export var animation_tree: AnimationTree

enum State { NORMAL, ROLLING }
var current_state: State = State.NORMAL

var roll_direction: Vector2 = Vector2.DOWN
var is_invulnerable: bool = false

# Tracks the last direction the player moved in for animations
var last_facing_direction: Vector2 = Vector2.DOWN

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
		last_facing_direction = input.normalized() # Remember this for when we stop!
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	
	move_and_slide()
	
	if Input.is_action_just_pressed("dodge"):
		_start_roll()
	
	handle_animations()

func handle_animations() -> void:
	# 1. Handle Flip (Only update if we are actively moving horizontally)
	if velocity.x != 0:
		sprite.flip_h = velocity.x < 0
		
	# Note: If you eventually use 4-directional sprites (up/down/left/right), 
	# you will use the `last_facing_direction` variable here to pick the 
	# correct "idle_up" or "idle_down" animation when velocity is Vector2.ZERO.
	
	# 2. Play Animations
	if current_state == State.ROLLING: 
		sprite.play("dodge")
	elif velocity != Vector2.ZERO: 
		sprite.play("run")
	else: 
		sprite.play("idle")

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

func _handle_roll_state(delta: float) -> void:
	# Ignore input, lose momentum gradually
	velocity = velocity.move_toward(Vector2.ZERO, (friction * 0.6) * delta)
	move_and_slide()

func _end_roll() -> void:
	current_state = State.NORMAL
	# Apply slight friction penalty after roll to prevent infinite rolling speed
	velocity *= 0.5

# --- INTERACTION & INVENTORY ---

## Called by dungeon loot items via Area2D signals
func try_pickup_item(item_data: EquipmentData) -> bool:
	var total_max = 5
	var type_max = 1
	
	if typeof(CreatureManager) != TYPE_NIL:
		total_max = CreatureManager.inv_total_limit
		type_max = CreatureManager.inv_type_limit

	var current_total = 0
	for key in inventory:
		current_total += inventory[key].size()
		
	if current_total >= total_max:
		_show_feedback("Bag Full!")
		return false
		
	if inventory[item_data.slot].size() >= type_max:
		_show_feedback("Too many " + item_data.slot + " items!")
		return false
		
	inventory[item_data.slot].append(item_data)
	_show_feedback("Picked up: " + item_data.item_name)
	return true

func _show_feedback(msg: String) -> void:
	print("[Player] ", msg)
