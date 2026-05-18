extends CharacterBody2D

@export_category("Player Settings")
@export_group("Movement Settings")
@export var max_speed: float = 500.0
@export var acceleration: float = 8000.0
@export var friction: float = 8000.0

@export_group("Dodge Roll Settings")
@export var roll_speed: float = 700.0
@export var roll_duration: float = 0.35
@export var roll_iframe_percent: float = 0.7
@export var dodge_timer: Timer
var can_roll: bool = true 

@export_group("Interaction Settings")
@export var required_channel_time: float = 1.0

@export_group("Hazard Settings")
@onready var void_detector: Area2D = %VoidDetector
@onready var water_detector: Area2D = %WaterDetector
var last_safe_position: Vector2 = Vector2.ZERO
var delayed_safe_position: Vector2 = Vector2.ZERO
var safe_timer: float = 0.0
var is_falling: bool = false

@export_category("Node References")
@export var sprite: AnimatedSprite2D
@export var animation_tree: AnimationTree
@export var sfx_dodge: AudioStreamPlayer2D
@export var sfx_channel: AudioStreamPlayer2D
@export var sfx_success: AudioStreamPlayer2D
@export var dodge_particles: GPUParticles2D

@export_category("UI References")
@onready var hotbar_container: HBoxContainer = %HotbarContainer
@onready var channel_bar: ProgressBar = %ChannelBar
@onready var interact_prompt: Label = %InteractPrompt
var selected_slot_index: int = 0

@export_category("Loot & Drops")
@export var loot_item_scene: PackedScene

enum State { NORMAL, ROLLING, LOOTING }
var current_state: State = State.NORMAL

var roll_direction: Vector2 = Vector2.DOWN
var is_invulnerable: bool = false
var is_stunned: bool = false
var last_facing_direction: Vector2 = Vector2.DOWN

var inventory: Dictionary = {"weapon": [], "head": [], "body": [], "boots": [], "back": []}
var pickup_history: Array[EquipmentData] = [] 
var pending_loot_data: EquipmentData = null 
var active_interactable: Node2D = null
var channel_time: float = 0.0

var spawn_lock_timer: float = 0.0
var max_spawn_lock: float = 0.0

func _enter_tree() -> void:
	if name.to_int() != 0:
		set_multiplayer_authority(name.to_int())
	else:
		set_multiplayer_authority(1)
	
	if not is_multiplayer_authority() and has_node("HUD"):
		$HUD.hide()

func _ready() -> void:
	last_safe_position = global_position
	delayed_safe_position = global_position
	
	_update_hotbar_ui()
	if channel_bar:
		channel_bar.hide()
	
	if interact_prompt:
		interact_prompt.top_level = true
	
	_apply_spawn_handicap()
	
	if has_node("HUD/ScreenFade"):
		var fade = $HUD/ScreenFade
		fade.modulate.a = 1.0 # Start fully black
		var tween = create_tween()
		# Fade to transparent over 0.6 seconds
		tween.tween_property(fade, "modulate:a", 0.0, 0.6).set_ease(Tween.EASE_OUT)
		tween.tween_callback(fade.hide) # Hide it completely when done to save performance

func _physics_process(delta: float) -> void:
	# 1. VISUAL TIMER: Runs on ALL machines so everyone sees the bar drop!
	if spawn_lock_timer > 0:
		spawn_lock_timer -= delta
		if channel_bar:
			channel_bar.value = (spawn_lock_timer / max_spawn_lock) * 100.0
			
		if spawn_lock_timer <= 0:
			if channel_bar: channel_bar.hide()
			if is_multiplayer_authority():
				_show_feedback("Lock released! GO!")

	# 2. PHYSICAL MOVEMENT: Only runs on the local player's machine
	if is_multiplayer_authority():
		if is_falling or is_stunned:
			velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
			move_and_slide()
			handle_animations()
			return
		
		# The Lock
		if spawn_lock_timer > 0:
			velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
			move_and_slide()
			handle_animations()
			return # Skip all other state logic while locked!

		# Normal State Machine
		match current_state:
			State.NORMAL:
				_handle_normal_state(delta)
			State.ROLLING:
				_handle_roll_state(delta)
			State.LOOTING:
				_handle_looting_state(delta)
		
		handle_animations()
	
	# 3. HAZARD DETECTION
	if is_multiplayer_authority() and not is_falling and not is_stunned:
		var touching_void = void_detector.has_overlapping_bodies()
		
		if touching_void:
			safe_timer = 0.0 
			if current_state != State.ROLLING:
				_trigger_fall()
		else:
			if current_state == State.NORMAL:
				safe_timer += delta
				if safe_timer >= 0.5:
					last_safe_position = delayed_safe_position
					delayed_safe_position = global_position
					safe_timer = 0.0
			else:
				safe_timer = 0.0

func _apply_spawn_handicap() -> void:
	if typeof(CreatureManager) == TYPE_NIL: return
	
	var my_id = name.to_int()
	var profile = CreatureManager.get_profile(my_id)
	if not profile: return

	var my_wins = profile.wins
	var min_wins = my_wins
	for p_id in CreatureManager.profiles:
		if CreatureManager.profiles[p_id].wins < min_wins:
			min_wins = CreatureManager.profiles[p_id].wins

	var win_diff = my_wins - min_wins
	
	# The Lock: You are frozen for 2.0 seconds per win difference
	if win_diff > 0:
		max_spawn_lock = win_diff * 2.0 
		spawn_lock_timer = max_spawn_lock
		_show_feedback("Spawn Locked for " + str(max_spawn_lock) + "s! (Handicap)")
		if channel_bar:
			channel_bar.show()
			channel_bar.value = 100.0

func _handle_normal_state(delta: float) -> void:
	# --- Normal Movement ---
	var in_water = false
	if water_detector:
		in_water = water_detector.has_overlapping_bodies()
		
	var speed_mod = 0.5 if in_water else 1.0 # 50% speed in water
	
	var input = Input.get_vector("left", "right", "up", "down")
	
	if input != Vector2.ZERO:
		velocity = velocity.move_toward(input * max_speed * speed_mod, acceleration * delta)
		roll_direction = input.normalized()
		last_facing_direction = input.normalized() 
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	
	move_and_slide()
	
	if Input.is_action_just_pressed("dodge") and can_roll and not in_water:
		_start_roll()
		
	# Check for Interaction
	if Input.is_action_just_pressed("interact") and active_interactable:
		_start_channeling()
	
	# --- DYNAMIC HOTBAR ---
	var total_limit = 3
	if typeof(CreatureManager) != TYPE_NIL:
		total_limit = CreatureManager.get_player_inv_limit(name.to_int())
	
	if Input.is_action_just_pressed("cycle_right"):
		selected_slot_index = (selected_slot_index + 1) % total_limit
		_update_hotbar_ui()
	elif Input.is_action_just_pressed("cycle_left"):
		selected_slot_index -= 1
		if selected_slot_index < 0:
			selected_slot_index = total_limit - 1
		_update_hotbar_ui()
	
	if Input.is_action_just_pressed("discard"):
		_discard_selected_item()

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
	
	# --- VFX Toggles ---
	var in_water = false
	if has_node("WaterDetector"):
		in_water = $WaterDetector.has_overlapping_bodies()

	var is_running = (current_state == State.NORMAL and velocity.length() > 20.0 and not is_falling)

	if has_node("RunDust") and has_node("WaterSplash"):
		var run_dust = $RunDust
		var water_splash = $WaterSplash
		
		if is_running:
			if in_water:
				run_dust.emitting = false
				water_splash.emitting = true
			else:
				run_dust.emitting = true
				water_splash.emitting = false
		else:
			run_dust.emitting = false
			water_splash.emitting = false

func _start_roll() -> void:
	current_state = State.ROLLING
	can_roll = false
	is_invulnerable = true
	dodge_particles.restart()
	sfx_dodge.play()
	velocity = roll_direction * roll_speed
	
	await get_tree().create_timer(roll_duration * roll_iframe_percent).timeout
	is_invulnerable = false
	
	await get_tree().create_timer(roll_duration * (1.0 - roll_iframe_percent)).timeout
	_end_roll()

func _handle_roll_state(delta: float) -> void:
	#velocity = velocity.move_toward(Vector2.ZERO, (friction * 0.4) * delta)
	move_and_slide()

func _end_roll() -> void:
	if current_state == State.ROLLING:
		current_state = State.NORMAL
		velocity *= 0.5
	dodge_timer.start(0.8)

func _on_dodge_timer_timeout() -> void:
	can_roll = true

func _trigger_fall() -> void:
	is_falling = true
	current_state = State.NORMAL # Cancel any looting/interactions
	velocity = Vector2.ZERO
	
	# Optional: Play a falling sound here!
	
	# Visual Feedback: Shrink and fade the sprite to simulate falling into the pit
	var tween = create_tween().set_parallel(true)
	tween.tween_property(sprite, "scale", Vector2.ZERO, 0.5)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
	tween.tween_property(sprite, "rotation_degrees", 360.0, 0.5)
	
	await get_tree().create_timer(0.6).timeout
	
	_respawn_from_fall()

func _respawn_from_fall() -> void:
	# Teleport to the last known safe ground
	global_position = last_safe_position
	delayed_safe_position = last_safe_position
	
	# Reset visuals
	sprite.scale = Vector2.ONE
	sprite.modulate.a = 1.0
	sprite.rotation_degrees = 0.0
	is_falling = false
	
	# Apply Penalty (Using the screen shake RPC from the creature system!)
	if typeof(StageManager) != TYPE_NIL:
		StageManager.screen_shake_requested.emit(8.0)
		
	_show_feedback("Fell into the void!")
	
	apply_stun(0.4)

func apply_stun(duration: float) -> void:
	if not is_multiplayer_authority() or is_invulnerable: return
	
	current_state = State.NORMAL
	velocity = Vector2.ZERO
	is_stunned = true
	is_invulnerable = true
	
	if typeof(StageManager) != TYPE_NIL:
		StageManager.screen_shake_requested.emit(8.0)
	
	# Calculate how many times to loop the animation based on duration
	var loops = max(1, int(duration / 0.2))
	
	var blink_tween = create_tween().set_loops(loops)
	blink_tween.tween_property(sprite, "modulate:a", 0.2, 0.1)
	blink_tween.tween_property(sprite, "modulate:a", 1.0, 0.1)
	
	var wobble_tween = create_tween().set_loops(loops)
	wobble_tween.tween_property(sprite, "rotation_degrees", 15.0, 0.05)
	wobble_tween.tween_property(sprite, "rotation_degrees", -15.0, 0.1)
	wobble_tween.tween_property(sprite, "rotation_degrees", 0.0, 0.05)
	
	await get_tree().create_timer(duration).timeout
	is_stunned = false
	sprite.rotation_degrees = 0.0
	
	# Tiny grace period of i-frames after waking up
	await get_tree().create_timer(0.2).timeout
	is_invulnerable = false


# --- INTERACTION & INVENTORY (NETWORKED) ---

func register_interactable(node: Node2D) -> void:
	active_interactable = node
	if interact_prompt and current_state != State.LOOTING:
		var target_pos = node.global_position + Vector2(0, -50)
		interact_prompt.reset_size()
		interact_prompt.global_position = target_pos - (interact_prompt.size / 2.0)
		interact_prompt.show()
		if node is LootItem:
			interact_prompt.text = "[F] Pick Up"
		elif node is EscapePortal:
			interact_prompt.text = "[F] Escape"

func unregister_interactable(node: Node2D) -> void:
	if active_interactable == node:
		active_interactable = null
		if interact_prompt: 
			interact_prompt.hide()
			
		if current_state == State.LOOTING:
			_cancel_channeling()

func _start_channeling() -> void:
	# Pre-check for inventory limits so we don't waste time channeling
	if active_interactable is LootItem:
		if not _can_pickup(active_interactable.item_data):
			return

	current_state = State.LOOTING
	channel_time = 0.0
	
	if channel_bar:
		channel_bar.show()
		channel_bar.value = 0.0
	
	if interact_prompt:
		interact_prompt.hide()
	
	if active_interactable is LootItem:
		sfx_channel.pitch_scale = 1.2
		required_channel_time = 0.8
	elif active_interactable is EscapePortal:
		sfx_channel.pitch_scale = 0.8
		required_channel_time = 1.5
	sfx_channel.play()

func _handle_looting_state(delta: float) -> void:
	# Add friction so we slide to a halt if moving when started
	velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	move_and_slide()
	
	if not Input.is_action_pressed("interact") or not is_instance_valid(active_interactable):
		_cancel_channeling()
		return
		
	channel_time += delta
	if channel_bar:
		channel_bar.value = (channel_time / required_channel_time) * 100.0
		
	if channel_time >= required_channel_time:
		_complete_channeling()

func _cancel_channeling() -> void:
	if current_state == State.LOOTING:
		current_state = State.NORMAL
		if channel_bar:
			channel_bar.hide()
		if interact_prompt and active_interactable:
			interact_prompt.show()
	sfx_channel.stop()

func _complete_channeling() -> void:
	if active_interactable is LootItem:
		_request_loot_pickup(active_interactable)
	elif active_interactable is EscapePortal:
		extract_from_dungeon(false)
		
	current_state = State.NORMAL
	if channel_bar:
		channel_bar.hide()
	
	sfx_channel.stop()
	sfx_success.play()

func _can_pickup(item_data: EquipmentData) -> bool:
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
	return true

func _request_loot_pickup(loot_node: Node2D) -> void:
	pending_loot_data = loot_node.item_data
	_show_feedback("Grabbing loot...")
	rpc_id(1, "server_request_loot", loot_node.get_path())
	
	await get_tree().create_timer(1.0).timeout
	if is_instance_valid(loot_node) and pending_loot_data == loot_node.item_data:
		pending_loot_data = null
		_show_feedback("Loot request dropped. Target invalid.")
	
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
	_update_hotbar_ui()

func _update_hotbar_ui() -> void:
	if not is_multiplayer_authority() or not hotbar_container: return
	
	var total_limit = CreatureManager.inv_total_limit if typeof(CreatureManager) != TYPE_NIL else 3
	
	# Safety catch if the limit changes
	if selected_slot_index >= total_limit: selected_slot_index = 0
	
	# Clear the old boxes
	for child in hotbar_container.get_children():
		child.queue_free()
		
	# Draw the boxes
	for i in range(total_limit):
		var panel = PanelContainer.new()
		panel.custom_minimum_size = Vector2(80, 80)
		
		# Draw the background and highlight
		var style = StyleBoxFlat.new()
		if i == selected_slot_index:
			style.bg_color = Color(0.8, 0.8, 0.2, 0.5) # Highlight Yellow
			style.border_width_bottom = 5
			style.border_color = Color.YELLOW
		else:
			style.bg_color = Color(0.2, 0.2, 0.2, 0.7) # Dark Grey
			style.border_width_bottom = 5
			style.border_color = Color(0.1, 0.1, 0.1, 0.9)
			
		panel.add_theme_stylebox_override("panel", style)
		
		# If we have an item in this slot (treating pickup_history as our bag)
		if i < pickup_history.size():
			var item = pickup_history[i]
			var label = Label.new()
			label.text = item.item_name
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.autowrap_mode = TextServer.AUTOWRAP_WORD
			label.add_theme_font_size_override("font_size", 14)
			panel.add_child(label)
			
		hotbar_container.add_child(panel)

func _discard_selected_item() -> void:
	if pickup_history.is_empty():
		_show_feedback("Bag is empty!")
		return
		
	# Check if the selected slot actually has an item in it
	if selected_slot_index >= pickup_history.size():
		_show_feedback("That slot is empty!")
		return
		
	# Remove the specific item we selected
	var item_to_drop = pickup_history[selected_slot_index]
	inventory[item_to_drop.slot].erase(item_to_drop)
	pickup_history.remove_at(selected_slot_index)
	
	_show_feedback("Discarded: " + item_to_drop.item_name)
	
	_update_hotbar_ui()
	
	rpc_id(1, "server_request_drop_item", item_to_drop.resource_path, global_position)

@rpc("any_peer", "call_local", "reliable")
func server_request_drop_item(resource_path: String, drop_pos: Vector2) -> void:
	if not multiplayer.is_server(): return
	
	var unique_name = "DroppedLoot_" + str(Time.get_ticks_msec()) + "_" + str(randi() % 1000)
	var random_offset = Vector2(randf_range(-30, 30), randf_range(-30, 30))
	var final_pos = drop_pos + random_offset
	
	rpc("client_spawn_dropped_item", resource_path, final_pos, unique_name)

@rpc("any_peer", "call_local", "reliable")
func client_spawn_dropped_item(resource_path: String, final_pos: Vector2, loot_name: String) -> void:
	if multiplayer.get_remote_sender_id() != 1 and multiplayer.get_remote_sender_id() != 0:
		return
		
	if not loot_item_scene:
		push_error("[Player] Loot Item Scene is not assigned!")
		return
		
	var loot_inst = loot_item_scene.instantiate() as LootItem
	loot_inst.item_data = load(resource_path)
	loot_inst.name = loot_name
	
	get_tree().current_scene.add_child(loot_inst)
	loot_inst.global_position = final_pos

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
	
	if typeof(StageManager) != TYPE_NIL:
		StageManager.rpc_id(1, "server_player_extracted", multiplayer.get_unique_id())

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
