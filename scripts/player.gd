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

var inventory: Dictionary = {"weapon": [], "head": [], "body": [], "boots": [], "back": []}
var pickup_history: Array[EquipmentData] = [] 

# NEW: Temporarily stores what we are looking at while we ask the server for permission
var pending_loot_data: EquipmentData = null 

func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())

func _physics_process(delta: float) -> void:
	if is_multiplayer_authority():
		match current_state:
			State.NORMAL:
				_handle_move_state(delta)
			State.ROLLING:
				_handle_roll_state(delta)
			State.LOOTING:
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

func handle_animations() -> void:
	if velocity.x != 0:
		sprite.flip_h = velocity.x < 0
		
	if current_state == State.ROLLING: 
		sprite.play("dodge")
	elif current_state == State.LOOTING:
		sprite.play("idle") 
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
	if current_state == State.ROLLING:
		current_state = State.NORMAL
		velocity *= 0.5

# --- INTERACTION & INVENTORY (NETWORKED) ---

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

	# Step 1: Start local inspection
	current_state = State.LOOTING
	pending_loot_data = item_data
	_show_feedback("Inspecting...")
	
	await get_tree().create_timer(0.5).timeout
	
	if current_state != State.LOOTING:
		pending_loot_data = null
		_show_feedback("Looting interrupted!")
		return
		
	# Step 2: Ask the Host for permission!
	# We send the exact node path of the loot so the server knows which one we want
	var loot_path = loot_node.get_path()
	rpc_id(1, "server_request_loot", loot_path)

# Runs ONLY on the Host (Peer ID 1)
@rpc("any_peer", "call_local", "reliable")
func server_request_loot(loot_path: NodePath) -> void:
	if not multiplayer.is_server(): return
	
	var loot_node = get_node_or_null(loot_path)
	
	# If the node exists and isn't already being deleted, you win!
	if is_instance_valid(loot_node) and not loot_node.is_queued_for_deletion():
		# 1. Tell all clients to delete the item from the world
		rpc("client_remove_loot", loot_path)
		
		# 2. Tell the specific player who asked that they got it!
		var sender_id = multiplayer.get_remote_sender_id()
		if sender_id == 0: sender_id = 1 # Edge case if Host is the one who looted
		rpc_id(sender_id, "client_grant_loot")

# Runs on ALL clients to visually clean up the world
@rpc("any_peer", "call_local", "reliable")
func client_remove_loot(loot_path: NodePath) -> void:
	var loot_node = get_node_or_null(loot_path)
	if is_instance_valid(loot_node):
		loot_node.queue_free()

# Runs ONLY on the specific client who won the item
@rpc("any_peer", "call_local", "reliable")
func client_grant_loot() -> void:
	if multiplayer.get_remote_sender_id() != 1: return
	
	if pending_loot_data == null: return
	
	current_state = State.NORMAL
	inventory[pending_loot_data.slot].append(pending_loot_data)
	pickup_history.append(pending_loot_data)
	_show_feedback("Picked up: " + pending_loot_data.item_name)
	pending_loot_data = null

func _discard_last_item() -> void:
	if pickup_history.is_empty():
		_show_feedback("Nothing to discard!")
		return
		
	var item_to_drop = pickup_history.pop_back()
	inventory[item_to_drop.slot].erase(item_to_drop)
	_show_feedback("Discarded: " + item_to_drop.item_name)
	# Future Polish: We will RPC the host here to spawn a new physical LootItem back into the world!

func _show_feedback(msg: String) -> void:
	print("[Player " + str(name) + "] ", msg)

## Called when the player safely reaches the exit, OR when time runs out.
func extract_from_dungeon(forced_by_timeout: bool = false) -> void:
	if not is_multiplayer_authority(): return
	
	current_state = State.LOOTING # Freeze the player's inputs
	
	# Tell ALL clients to hide my avatar
	rpc("client_hide_player")
	
	if forced_by_timeout:
		_show_feedback("TIME'S UP! The dungeon collapses...")
		_apply_timeout_penalty()
	else:
		_show_feedback("Extracted safely!")

	var extracted_loot: Array[EquipmentData] = []
	for slot in inventory.keys():
		extracted_loot.append_array(inventory[slot])
	
	if typeof(CreatureManager) != TYPE_NIL:
		CreatureManager.commit_dungeon_loot(name.to_int(), extracted_loot)
		_show_feedback("Saved " + str(extracted_loot.size()) + " items to Stash.")
	
	for slot in inventory.keys():
		inventory[slot].clear()
	pickup_history.clear()

@rpc("any_peer", "call_local", "reliable")
func client_hide_player() -> void:
	hide()
	set_physics_process(false)
	set_process_unhandled_input(false)


func _apply_timeout_penalty() -> void:
	# Penalty logic: Lose 50% of the items you picked up this run, chosen randomly.
	var total_items = 0
	for slot in inventory.keys():
		total_items += inventory[slot].size()
		
	if total_items == 0: return # Nothing to lose!
	
	var items_to_lose = max(1, total_items / 2) # Lose half, at least 1
	var lost_count = 0
	
	while lost_count < items_to_lose:
		# Pick a random slot
		var available_slots = []
		for slot in inventory.keys():
			if inventory[slot].size() > 0:
				available_slots.append(slot)
				
		if available_slots.is_empty(): break
		
		var random_slot = available_slots.pick_random()
		var slot_array: Array = inventory[random_slot]
		
		# Erase a random item from that slot
		var item_to_drop = slot_array.pick_random()
		slot_array.erase(item_to_drop)
		
		# Also remove it from history so discard doesn't break
		pickup_history.erase(item_to_drop)
		lost_count += 1
		
	_show_feedback("PENALTY: Lost " + str(lost_count) + " items!")
