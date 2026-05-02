extends CharacterBody2D

@export_category("Player Settings")
@export_group("Movement Settings")
@export var max_speed: float = 180.0
@export var acceleration: float = 1200.0
@export var friction: float = 1600.0

@export_group("Dodge Roll Settings")
@export var roll_speed: float = 450.0
@export var roll_duration: float = 0.35
@export var roll_iframe_percent: float = 0.7 

@export_category("Node References")
@export var sprite: AnimatedSprite2D
@export var animation_tree: AnimationTree

enum State { NORMAL, ROLLING, LOOTING }
var current_state: State = State.NORMAL

var roll_direction: Vector2 = Vector2.DOWN
var is_invulnerable: bool = false
var last_facing_direction: Vector2 = Vector2.DOWN

# --- INVENTORY ---
var inventory: Dictionary = {
	"weapon": [], "head": [], "body": [], "boots": [], "back": []
}
var pickup_history: Array[EquipmentData] = [] # Tracks order for quick-discard

func _physics_process(delta: float) -> void:
	match current_state:
		State.NORMAL:
			_handle_move_state(delta)
		State.ROLLING:
			_handle_roll_state(delta)
		State.LOOTING:
			# Slide to a stop while inspecting loot
			velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
			move_and_slide()
			handle_animations()

func _handle_move_state(delta: float) -> void:
	var input = Input.get_vector("left", "right", "up", "down")
	
	if input != Vector2.ZERO:
		velocity = velocity.move_toward(input * max_speed, acceleration * delta)
		roll_direction = input.normalized()
		last_facing_direction = input.normalized() 
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	
	move_and_slide()
	
	if Input.is_action_just_pressed("dodge"):
		_start_roll()
		
	if Input.is_action_just_pressed("discard"):
		_discard_last_item()
	
	handle_animations()

func handle_animations() -> void:
	if velocity.x != 0:
		sprite.flip_h = velocity.x < 0
		
	if current_state == State.ROLLING: 
		sprite.play("dodge")
	elif current_state == State.LOOTING:
		sprite.play("idle") # Can replace with an 'inspect' animation later
	elif velocity != Vector2.ZERO: 
		sprite.play("run")
	else: 
		sprite.play("idle")

func _start_roll() -> void:
	current_state = State.ROLLING
	is_invulnerable = true
	velocity = roll_direction * roll_speed
	
	await get_tree().create_timer(roll_duration * roll_iframe_percent).timeout
	is_invulnerable = false
	
	await get_tree().create_timer(roll_duration * (1.0 - roll_iframe_percent)).timeout
	_end_roll()

func _handle_roll_state(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, (friction * 0.4) * delta)
	move_and_slide()

func _end_roll() -> void:
	# Only reset to NORMAL if we weren't interrupted
	if current_state == State.ROLLING:
		current_state = State.NORMAL
		velocity *= 0.5

# --- INTERACTION & INVENTORY ---

## Asynchronous pickup to allow for the "Inspection Delay"
func try_pickup_item(item_data: EquipmentData, loot_node: Node2D) -> void:
	if current_state != State.NORMAL: return
	
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
		return
		
	if inventory[item_data.slot].size() >= type_max:
		_show_feedback("Too many " + item_data.slot + " items!")
		return

	# Start Inspection Phase
	current_state = State.LOOTING
	_show_feedback("Inspecting...")
	
	# Wait 0.5 seconds for the "anti-hogging" risk mechanic
	await get_tree().create_timer(0.5).timeout
	
	# Check if player was interrupted (e.g. hit by trap)
	if current_state != State.LOOTING:
		_show_feedback("Looting interrupted!")
		return
		
	# Success!
	current_state = State.NORMAL
	inventory[item_data.slot].append(item_data)
	pickup_history.append(item_data)
	_show_feedback("Picked up: " + item_data.item_name)
	
	# Player handles destroying the item now
	if is_instance_valid(loot_node):
		loot_node.queue_free()

func _discard_last_item() -> void:
	if pickup_history.is_empty():
		_show_feedback("Nothing to discard!")
		return
		
	var item_to_drop = pickup_history.pop_back()
	inventory[item_to_drop.slot].erase(item_to_drop)
	_show_feedback("Discarded: " + item_to_drop.item_name)
	
	# Note: Once we have the procedural drop system running, 
	# we can instantiate a physical LootItem here so it drops back onto the floor!

func _show_feedback(msg: String) -> void:
	print("[Player] ", msg)
