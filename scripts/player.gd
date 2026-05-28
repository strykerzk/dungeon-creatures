extends CharacterBody2D

@export_category("Player Settings")
@export_group("Movement Settings")
@export var max_speed: float = 500.0
@export var acceleration: float = 8000.0
@export var friction: float = 8000.0

@export_group("Dodge Roll Settings")
@export var roll_speed: float = 900.0
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
var _safe_candidate: Vector2 = Vector2.ZERO
var _safe_candidate_age: float = 0.0
const SAFE_POSITION_AGE_REQUIRED: float = 0.6
var is_falling: bool = false

@export_category("Node References")
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var sfx_dodge: AudioStreamPlayer2D = $SFXDodge
@onready var sfx_channel: AudioStreamPlayer2D = $SFXChannel
@onready var sfx_success: AudioStreamPlayer2D = $SFXSuccess
@onready var sfx_emote: AudioStreamPlayer2D = $SFXEmote
@onready var dodge_particles: GPUParticles2D = $DodgeParticles
@onready var run_dust: GPUParticles2D = $RunDust
@onready var water_splash: GPUParticles2D = $WaterSplash
@onready var handicap_chains: Sprite2D = $HandicapLock

@export_category("UI References")
@onready var hotbar_container: HBoxContainer = %HotbarContainer
@onready var channel_bar: ProgressBar = %ChannelBar
@onready var interact_prompt: Label = %InteractPrompt
@onready var name_label: Label = %NameLabel
@export var speech_bubble_scene: PackedScene
@export var emote_wheel_scene: PackedScene
@export var mutation_draft_scene: PackedScene
var selected_slot_index: int = 0
var active_wheel = null

# --- INVENTORY AND INTERACTIONS ---
@export_category("Loot & Drops")
@export var loot_item_scene: PackedScene
var pickup_history: Array[EquipmentData] = [] 
var pending_loot_data: EquipmentData = null 
var nearby_interactables: Array[Area2D] = []
var active_interactable: Area2D = null
var channel_time: float = 0.0
var has_drafted_mutation: bool = false
var minor_pickups: int = 0

enum State { NORMAL, ROLLING, LOOTING }
var current_state: State = State.NORMAL

var roll_direction: Vector2 = Vector2.DOWN
var is_invulnerable: bool = false
var is_stunned: bool = false
var last_facing_direction: Vector2 = Vector2.DOWN
var current_room_center: Vector2 = Vector2.ZERO
var spawn_lock_timer: float = 0.0
var max_spawn_lock: float = 0.0

var handicap_tween: Tween = null
var stun_blink_tween: Tween = null
var stun_wobble_tween: Tween = null

func _enter_tree() -> void:
	if name.to_int() != 0:
		set_multiplayer_authority(name.to_int())
	else:
		set_multiplayer_authority(1)
	
	if not is_multiplayer_authority() and has_node("HUD"):
		$HUD.hide()

func _ready() -> void:
	last_safe_position = global_position
	
	name_label.text = NetworkManager.players[int(name)].name
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
			
			if handicap_tween:
				handicap_tween.kill()
				handicap_tween = null
			
			if handicap_chains and handicap_chains.visible:
				var tween = create_tween().set_parallel(true)
				tween.tween_property(handicap_chains, "scale", Vector2(2.0, 2.0), 0.2)
				tween.tween_property(handicap_chains, "modulate:a", 0.0, 0.2)
				tween.chain().tween_callback(handicap_chains.hide)
				
			if sprite:
				create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.2)
	
	# 2. PHYSICAL MOVEMENT: Only runs on the local player's machine
	if is_multiplayer_authority():
		if is_falling or is_stunned:
			velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
			move_and_slide()
			handle_animations.rpc()
			return
		
		# The Lock
		if spawn_lock_timer > 0:
			velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
			move_and_slide()
			handle_animations.rpc()
			return # Skip all other state logic while locked!
		
		# Interactables
		_update_closest_interactable()
		
		# Normal State Machine
		match current_state:
			State.NORMAL:
				_handle_normal_state(delta)
			State.ROLLING:
				_handle_roll_state(delta)
			State.LOOTING:
				_handle_looting_state(delta)
		
		handle_animations.rpc()
	
	# 3. HAZARD DETECTION
	if is_multiplayer_authority() and not is_falling and not is_stunned:
		var touching_void = void_detector.has_overlapping_bodies()
		
		if touching_void:
			if current_state != State.ROLLING:
				_trigger_fall.rpc()
		elif not touching_void and current_state == State.NORMAL:
				_safe_candidate_age += delta
				if _safe_candidate_age < SAFE_POSITION_AGE_REQUIRED:
					_safe_candidate = global_position  # Keep sampling the candidate
				else:
					# Candidate has been safe for long enough — promote it
					last_safe_position = _safe_candidate
					_safe_candidate = global_position
					_safe_candidate_age = 0.0
		else:
			_safe_candidate_age = 0.0

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
	
	# The Lock: Everyone gets 3 seconds. Handicaps add +2 seconds per win difference.
	var base_lock: float = 3.0
	var handicap_penalty: float = 0.0
	if win_diff > 0:
		handicap_penalty = win_diff * 2.0 
		
	max_spawn_lock = base_lock + handicap_penalty
	spawn_lock_timer = max_spawn_lock
	
	if channel_bar:
		channel_bar.show()
		channel_bar.value = 100.0
		
	if handicap_penalty > 0:
		_show_feedback("Spawn Locked for " + str(max_spawn_lock) + "s! (Handicap Applied)")
		# NEW: Apply the visual lock!
		if handicap_chains:
			handicap_chains.show()
			# Add a subtle pulse to the chains
			handicap_tween = create_tween().set_loops()
			handicap_tween.tween_property(handicap_chains, "scale", Vector2(1.0, 1.0), 0.5)
			handicap_tween.tween_property(handicap_chains, "scale", Vector2(1.1, 1.1), 0.5)
		if sprite:
			sprite.modulate = Color(0.4, 0.4, 0.4, 1.0) # Turn the player gray/dark
	else:
		_show_feedback("Ready... Set...")

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
		_start_roll.rpc()
		
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

func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority(): return
	
	# --- EMOTE WHEEL LOGIC ---
	if event.is_action_pressed("emote_wheel"):
		if emote_wheel_scene and not active_wheel:
			active_wheel = emote_wheel_scene.instantiate()
			add_child(active_wheel)
			
	elif event.is_action_released("emote_wheel"):
		if active_wheel:
			var picked_emote = active_wheel.current_selection
			active_wheel.queue_free()
			active_wheel = null
			
			if picked_emote != "":
				rpc("client_show_emote", picked_emote)

@rpc("authority","call_local","unreliable")
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
	if water_detector:
		in_water = water_detector.has_overlapping_bodies()
	
	var is_running = (current_state == State.NORMAL and velocity.length() > 20.0 and not is_falling)
	
	if run_dust and water_splash:
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

@rpc("authority","call_local","reliable")
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

@rpc("authority","call_local","reliable")
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
	
	if is_multiplayer_authority():
		rpc("client_respawn_at", last_safe_position)

@rpc("authority", "call_local", "reliable")
func client_respawn_at(safe_pos: Vector2) -> void:
	global_position = safe_pos
	sprite.scale = Vector2.ONE
	sprite.modulate.a = 1.0
	sprite.rotation_degrees = 0.0
	is_falling = false
	
	if is_multiplayer_authority():
		if typeof(StageManager) != TYPE_NIL:
			StageManager.screen_shake_requested.emit(8.0)
		_show_feedback("Fell into the void!")
	apply_stun(0.4)

func apply_stun(duration: float) -> void:
	if is_invulnerable: return
	if stun_blink_tween: stun_blink_tween.kill()
	if stun_wobble_tween: stun_wobble_tween.kill()
	
	current_state = State.NORMAL
	velocity = Vector2.ZERO
	is_stunned = true
	is_invulnerable = true
	
	if typeof(StageManager) != TYPE_NIL and is_multiplayer_authority():
		StageManager.screen_shake_requested.emit(8.0)
	
	# Calculate how many times to loop the animation based on duration
	var loops = max(1, int(duration / 0.2))
	
	stun_blink_tween = create_tween().set_loops(loops)
	stun_blink_tween.tween_property(sprite, "modulate:a", 0.2, 0.1)
	stun_blink_tween.tween_property(sprite, "modulate:a", 1.0, 0.1)
	
	stun_wobble_tween = create_tween().set_loops(loops)
	stun_wobble_tween.tween_property(sprite, "rotation_degrees", 15.0, 0.05)
	stun_wobble_tween.tween_property(sprite, "rotation_degrees", -15.0, 0.1)
	stun_wobble_tween.tween_property(sprite, "rotation_degrees", 0.0, 0.05)
	
	await get_tree().create_timer(duration).timeout
	is_stunned = false
	sprite.rotation_degrees = 0.0
	
	# Tiny grace period of i-frames after waking up
	await get_tree().create_timer(0.2).timeout
	is_invulnerable = false

func _get_inventory() -> Dictionary:
	var dict: Dictionary = {"weapon": [], "head": [], "body": [], "boots": [], "back": []}
	for item in pickup_history:
		dict[item.slot].append(item)
	return dict

# --- INTERACTION & INVENTORY (NETWORKED) ---
func _start_channeling() -> void:
	if active_interactable is LootItem:
		if not _can_pickup(active_interactable.item_data): return
	elif active_interactable is MajorAltar:
		if has_drafted_mutation:
			_show_feedback("You can only draft one Major Mutation per run!")
			return
	elif active_interactable is MinorOrb:
		if minor_pickups >= CreatureManager.minor_slot_limit:
			_show_feedback("DNA Capacity Reached this run! (Limit: " + str(CreatureManager.minor_slot_limit) + ")")
	elif active_interactable is Lever:
		if active_interactable.is_pulled or active_interactable.is_locked:
			return
		sfx_channel.pitch_scale = 1.0
		required_channel_time = 0.0

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
	elif active_interactable is MinorOrb:
		sfx_channel.pitch_scale = 1.2
		required_channel_time = 1.2
	elif active_interactable is EscapePortal:
		sfx_channel.pitch_scale = 0.8
		required_channel_time = 1.0
	elif active_interactable is MajorAltar:
		sfx_channel.pitch_scale = 0.6
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
	elif active_interactable is MinorOrb:
		_request_orb_pickup(active_interactable)
	elif active_interactable is EscapePortal:
		extract_from_dungeon(false)
	elif active_interactable is Lever:
		active_interactable.rpc("rpc_pull_lever")
	elif active_interactable is MajorAltar:
		if mutation_draft_scene:
			var ui = mutation_draft_scene.instantiate()
			get_tree().current_scene.add_child(ui) # Dungeon root
			ui.setup(self, active_interactable)
		
	current_state = State.NORMAL
	if channel_bar:
		channel_bar.hide()
	
	sfx_channel.stop()
	sfx_success.play()

func _can_pickup(item_data: EquipmentData) -> bool:
	var total_max: int = CreatureManager.inv_total_limit if typeof(CreatureManager) != TYPE_NIL else 5
	var type_max: int = CreatureManager.inv_type_limit if typeof(CreatureManager) != TYPE_NIL else 1
	
	if pickup_history.size() >= total_max:
		_show_feedback("Bag Full! (Limit: " + str(total_max) + ")")
		return false
	
	var slot_items = pickup_history.filter(func(i): return i.slot == item_data.slot)
	var unique_types: Dictionary = {}
	for item in slot_items:
		unique_types[item.resource_path] = true
	
	if unique_types.has(item_data.resource_path):
		return true
	
	if unique_types.size() >= type_max:
		_show_feedback("Can't carry another " + item_data.slot + " type!")
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
		rpc("client_remove_loot", loot_path)
		
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
@rpc("authority", "call_local", "reliable")
func client_grant_loot() -> void:
	if multiplayer.get_remote_sender_id() != 1: return
	
	if pending_loot_data == null: return
	
	current_state = State.NORMAL
	pickup_history.append(pending_loot_data)
	_show_feedback("Picked up: " + pending_loot_data.item_name)
	pending_loot_data = null
	_update_hotbar_ui()

func _request_orb_pickup(orb_node: Node2D) -> void:
	_show_feedback("Splicing DNA...")
	# FIX 3: Send the exact, unique NodePath instead of the generic string name!
	rpc_id(1, "server_request_orb", orb_node.get_path())

@rpc("any_peer", "call_local", "reliable")
func server_request_orb(orb_path: NodePath) -> void:
	if not multiplayer.is_server(): return
	
	var orb_node = get_node_or_null(orb_path)
	if is_instance_valid(orb_node) and not orb_node.is_queued_for_deletion():
		var sender_id = multiplayer.get_remote_sender_id()
		if sender_id == 0: sender_id = 1
	
		# Server-side per-run check using the host's copy of this player's node
		# self here IS the host's copy of the requesting player's node (Godot routes RPCs by node path)
		if minor_pickups >= CreatureManager.minor_slot_limit:
			return
	
		var path = orb_node.mutation_data.resource_path
		rpc("client_destroy_orb", orb_path)
		rpc("client_grant_orb", sender_id, path)


@rpc("any_peer", "call_local", "reliable")
func client_destroy_orb(orb_path: NodePath) -> void:
	var orb_node = get_node_or_null(orb_path)
	if is_instance_valid(orb_node):
		orb_node.queue_free()

@rpc("any_peer", "call_local", "reliable")
func client_grant_orb(target_player_id: int, path: String) -> void:
	var data = load(path)
	var profile = CreatureManager.get_profile(target_player_id)
	
	if profile:
		profile.minor_mutations.append(data)
	
	# Only play the UI feedback and sound if WE are the ones who picked it up!
	if target_player_id == name.to_int():
		minor_pickups += 1
		_show_feedback("DNA Spliced: " + data.mutation_name)
		if sfx_success: sfx_success.play()

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
	if pickup_history.is_empty() or selected_slot_index >= pickup_history.size():
		_show_feedback("That slot is empty!")
		return
	
	var item_to_drop = pickup_history[selected_slot_index]
	pickup_history.remove_at(selected_slot_index)
	# Clamp index in case we removed the last item
	selected_slot_index = min(selected_slot_index, pickup_history.size() - 1)
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

@rpc("authority", "call_local", "reliable")
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
	current_state = State.LOOTING
	rpc("client_hide_player")
	
	if forced_by_timeout:
		_show_feedback("TIME'S UP! The dungeon collapses...")
		_apply_timeout_penalty()
	else:
		_show_feedback("Extracted safely!")
	
	if typeof(CreatureManager) != TYPE_NIL:
		CreatureManager.commit_dungeon_loot(name.to_int(), pickup_history.duplicate())
		_show_feedback("Saved " + str(pickup_history.size()) + " items to Stash.")
	
	pickup_history.clear()
	
	if typeof(StageManager) != TYPE_NIL:
		StageManager.rpc_id(1, "server_player_extracted", multiplayer.get_unique_id())
	
	var cam = get_tree().current_scene.get_node_or_null("DungeonCamera")
	if cam and cam.has_method("start_spectating"):
		cam.start_spectating()

@rpc("any_peer", "call_local", "reliable")
func client_hide_player() -> void:
	set_physics_process(false)
	set_process_unhandled_input(false)
	
	if sprite:
		var tween = create_tween().set_parallel(true)
		
		# Squish horizontally to 10% width
		tween.tween_property(sprite, "scale:x", 0.1, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		
		# Stretch vertically to 300% height
		tween.tween_property(sprite, "scale:y", 3.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		
		# Shoot upwards 300 pixels
		tween.tween_property(sprite, "position:y", sprite.position.y - 300.0, 0.4).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		
		# Hide the node completely ONLY after the animation finishes
		tween.chain().tween_callback(hide)
	else:
		hide()

@rpc("any_peer", "call_local", "reliable")
func client_show_emote(emoji_text: String) -> void:
	if not speech_bubble_scene: return
	
	var bubble = speech_bubble_scene.instantiate()
	add_child(bubble)
	
	# Spawn it slightly higher than interaction prompts
	bubble.position = Vector2(0, -90) 
	sfx_emote.play()
	
	if bubble.has_method("setup"):
		bubble.setup(emoji_text)

func _apply_timeout_penalty() -> void:
	if pickup_history.is_empty(): return
	var items_to_lose: int = max(1, pickup_history.size() / 2)
	for i in range(items_to_lose):
		if pickup_history.is_empty(): break
		var idx = randi() % pickup_history.size()
		pickup_history.remove_at(idx)
	_show_feedback("PENALTY: Lost " + str(items_to_lose) + " items!")

func confirm_major_mutation(resource_path: String) -> void:
	_show_feedback("Mutation locked in!")
	rpc_id(1, "server_grant_major_mutation", resource_path)

@rpc("any_peer", "call_local", "reliable")
func server_grant_major_mutation(path: String) -> void:
	if not multiplayer.is_server(): return
	
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0: sender_id = 1
	
	# Race condition guard: was this mutation stolen in the window between
	# the player opening the UI and confirming their pick?
	if path in StageManager.drafted_mutation_paths:
		rpc_id(sender_id, "client_draft_stolen")
		return
	
	var profile = CreatureManager.get_profile(sender_id)
	profile.major_mutation = load(path)
	print("[Server] Granted major mutation to Player ", sender_id)

@rpc("authority", "call_local", "reliable")
func client_draft_stolen() -> void:
	_show_feedback("That mutation was just claimed! Try another altar.")
	has_drafted_mutation = false  # Let them try again at a different altar

func _on_interaction_detector_area_entered(area: Area2D) -> void:
	if not is_multiplayer_authority(): return
	
	if not area in nearby_interactables:
		nearby_interactables.append(area)
		if interact_prompt and current_state != State.LOOTING:
			var target_pos = area.global_position + Vector2(0, -50)
			interact_prompt.reset_size()
			interact_prompt.global_position = target_pos - (interact_prompt.size / 2.0)
			interact_prompt.show()
			if area is LootItem or area is MinorOrb:
				interact_prompt.text = "[F] Pick Up"
			elif area is EscapePortal:
				interact_prompt.text = "[F] Escape"
			else:
				interact_prompt.text = "[F] Interact"

func _on_interaction_detector_area_exited(area: Area2D) -> void:
	if not is_multiplayer_authority(): return
	
	nearby_interactables.erase(area)
	if area == active_interactable:
		_set_active_interactable(null)
		if interact_prompt: 
			interact_prompt.hide()
			
		if current_state == State.LOOTING:
			_cancel_channeling()

func _update_closest_interactable() -> void:
	# Clean out deleted items safely
	nearby_interactables = nearby_interactables.filter(func(a): return is_instance_valid(a))
	
	if nearby_interactables.is_empty():
		if active_interactable != null: 
			_set_active_interactable(null)
		return
		
	var closest_item = null
	var min_dist_sq = INF
	
	for item in nearby_interactables:
		var dist_sq = global_position.distance_squared_to(item.global_position)
		if dist_sq < min_dist_sq:
			min_dist_sq = dist_sq
			closest_item = item
			
	if closest_item != active_interactable:
		_set_active_interactable(closest_item)

func _set_active_interactable(new_target: Area2D) -> void:
	# Turn OFF the old highlight
	if is_instance_valid(active_interactable) and active_interactable.has_method("set_highlight"):
		active_interactable.set_highlight(false)
		
	active_interactable = new_target
	
	# Turn ON the new highlight
	if is_instance_valid(active_interactable) and active_interactable.has_method("set_highlight"):
		active_interactable.set_highlight(true)
