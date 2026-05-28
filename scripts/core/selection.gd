extends Control

@export_category("UI References")
@onready var species_select_panel: VBoxContainer = %SpeciesSelectPanel
@onready var species_dropdown: OptionButton = %SpeciesDropdown
@onready var lock_in_button: Button = %LockInButton
@onready var status_label: Label = %StatusLabel
@onready var sound_panel: VBoxContainer = %SoundRecordingPanel
@onready var duration_bar: ProgressBar = %DurationBar
@onready var record_status: Label = %SoundLabel
@onready var ready_button: Button = %ReadyButton

# Tracks which players have locked in (Host only)
var ready_players: Array[int] = []

var locked_in: bool = false
var is_previewing: bool = false

const SOUND_SLOTS: Array[String] = ["hurt","attack","dodge","death"]
var _pending_sounds: Dictionary = {}  # String -> AudioStreamWAV
var _pending_pitches: Dictionary = {} # String -> float
var _active_slot: String = ""

func _ready() -> void:
	species_dropdown.add_item("Duck")
	species_dropdown.add_item("Cat")
	
	lock_in_button.pressed.connect(_on_lock_in_pressed)
	
	status_label.text = "Choose your starting Creature!"
	
	for slot in SOUND_SLOTS:
		_pending_pitches[slot] = 1.0
	
	AudioRecorder.recording_stopped.connect(_on_recording_stopped)
	AudioRecorder.recording_tick.connect(_on_recording_tick)
	
	_build_sound_slot_ui()

func _on_lock_in_pressed() -> void:
	if not locked_in:
		locked_in = true
		# Disable UI to prevent spamming
		species_dropdown.disabled = true
		_refresh_button_states()
		
		status_label.text = "Waiting for other players..."
		
		commit_sounds_to_profile()
		
		# Grab the text of the selected item and make it lowercase (e.g., "duck")
		var selected_species = species_dropdown.get_item_text(species_dropdown.selected).to_lower()
		print("[Selection] You locked in: ", selected_species)
		
		var my_id = multiplayer.get_unique_id()
		
		# Update our local CreatureProfile immediately
		if typeof(CreatureManager) != TYPE_NIL:
			var profile = CreatureManager.get_profile(my_id)
			if profile:
				profile.species = selected_species
				
		# Send our choice to the Host
		rpc_id(1, "server_player_pressed_lock_in", my_id, selected_species)
	else:
		locked_in = false
		species_dropdown.disabled = false
		_refresh_button_states()
		
		status_label.text = "Choose your starting Creature!"
		
		var my_id = multiplayer.get_unique_id()
		
		# Update our local CreatureProfile immediately
		if typeof(CreatureManager) != TYPE_NIL:
			var profile = CreatureManager.get_profile(my_id)
			if profile:
				profile.species = CreatureManager.default_species
				
		# Send our choice to the Host
		rpc_id(1, "server_player_pressed_lock_in", my_id, CreatureManager.default_species)

# --- NETWORK HANDSHAKE ---

@rpc("any_peer", "call_local", "reliable")
func server_player_pressed_lock_in(peer_id: int, selected_species: String) -> void:
	if not multiplayer.is_server(): return
	
	# The Host updates its master copy of the client's profile
	if typeof(CreatureManager) != TYPE_NIL:
		var profile = CreatureManager.get_profile(peer_id)
		if profile:
			profile.species = selected_species
	
	if not peer_id in ready_players:
		ready_players.append(peer_id)
		print("[Selection] Player ", peer_id, " is ready as a ", selected_species, ". (", ready_players.size(), "/", NetworkManager.players.size(), ")")
	elif peer_id in  ready_players:
		ready_players.erase(peer_id)
		print("[Selection] Player ", peer_id, " canceled ready. (", ready_players.size(), "/", NetworkManager.players.size(), ")")
	
	# Check if everyone has locked in
	if ready_players.size() >= NetworkManager.players.size():
		rpc("toggle_lock_in_button")
		# Give a slight delay so the last player sees the UI update
		await get_tree().create_timer(1.0).timeout
		rpc("rpc_start")

@rpc("authority", "call_local", "reliable")
func toggle_lock_in_button() -> void:
	lock_in_button.disabled = !lock_in_button.disabled

@rpc("authority", "call_local", "reliable")
func rpc_start() -> void:
	if multiplayer.is_server():
		CreatureManager.sync_all_profiles()
	
	if typeof(StageManager) != TYPE_NIL:
		StageManager.change_stage(StageManager.GameState.COMBAT)

func _build_sound_slot_ui() -> void:
	for slot in SOUND_SLOTS:
		var row = HBoxContainer.new()

		var label = Label.new()
		label.text = slot.capitalize()
		label.custom_minimum_size = Vector2(70, 0)
		row.add_child(label)

		var rec_btn = Button.new()
		rec_btn.text = "● REC"
		rec_btn.pressed.connect(_on_record_pressed.bind(slot))
		rec_btn.name = "RecBtn_" + slot
		rec_btn.add_to_group("sound_ui")
		row.add_child(rec_btn)

		var play_btn = Button.new()
		play_btn.text = "▶"
		play_btn.disabled = true
		play_btn.pressed.connect(_on_preview_pressed.bind(slot))
		play_btn.name = "PlayBtn_" + slot
		row.add_child(play_btn)

		var clear_btn = Button.new()
		clear_btn.text = "✕"
		clear_btn.disabled = true
		clear_btn.pressed.connect(_on_clear_pressed.bind(slot))
		clear_btn.name = "ClearBtn_" + slot
		clear_btn.add_to_group("sound_ui")
		row.add_child(clear_btn)

		var pitch_slider = HSlider.new()
		pitch_slider.min_value = 0.5
		pitch_slider.max_value = 2.0
		pitch_slider.step = 0.05
		pitch_slider.value = 1.0
		pitch_slider.custom_minimum_size = Vector2(120, 0)
		pitch_slider.value_changed.connect(_on_pitch_changed.bind(slot))
		pitch_slider.name = "PitchSlider_" + slot
		row.add_child(pitch_slider)

		var pitch_label = Label.new()
		pitch_label.text = "1.00×"
		pitch_label.custom_minimum_size = Vector2(45, 0)
		pitch_label.name = "PitchLabel_" + slot
		row.add_child(pitch_label)

		sound_panel.add_child(row)

func _refresh_button_states() -> void:
	var is_recording: bool = AudioRecorder._recording
	var is_busy: bool = locked_in or is_recording or is_previewing
	
	for slot in SOUND_SLOTS:
		var rec_btn   = sound_panel.find_child("RecBtn_"      + slot, true, false) as Button
		var play_btn  = sound_panel.find_child("PlayBtn_"     + slot, true, false) as Button
		var clear_btn = sound_panel.find_child("ClearBtn_"    + slot, true, false) as Button
		var slider    = sound_panel.find_child("PitchSlider_" + slot, true, false) as HSlider
	
		var has_sound: bool = _pending_sounds.has(slot)
		var is_active_slot: bool = (_active_slot == slot)
	
		if rec_btn:
			if locked_in:
				rec_btn.disabled = true
				rec_btn.text = "● REC"
			elif is_recording and is_active_slot:
				# This slot is currently recording — button becomes a STOP button
				rec_btn.disabled = false
				rec_btn.text = "■ STOP"
			elif is_recording:
				# A different slot is recording — block all other Rec buttons
				rec_btn.disabled = true
				rec_btn.text = "● REC"
			else:
				rec_btn.disabled = false
				rec_btn.text = "● REC"
	
		if play_btn:
			# Only enabled when: sound exists AND not locked AND not recording
			play_btn.disabled = not has_sound or is_busy
	
		if clear_btn:
			# Same condition as Play
			clear_btn.disabled = not has_sound or is_busy
	
		if slider:
			slider.editable = has_sound and not is_busy

func _on_record_pressed(slot: String) -> void:
	if AudioRecorder._recording:
		# Stop current recording early
		AudioRecorder.stop_recording()
		return
	
	_active_slot = slot
	duration_bar.value = 0.0
	record_status.text = "Recording: " + slot.capitalize() + "..."
	AudioRecorder.start_recording()
	_refresh_button_states()

func _on_recording_stopped(stream: AudioStreamWAV) -> void:
	if _active_slot.is_empty():
		return
	_pending_sounds[_active_slot] = stream
	record_status.text = _active_slot.capitalize() + " recorded. ✓"
	_active_slot = ""
	duration_bar.value = 0.0
	_refresh_button_states()

func _on_recording_tick(seconds_remaining: float) -> void:
	duration_bar.value = 1.0 - (seconds_remaining / AudioRecorder.MAX_DURATION)

func _on_preview_pressed(slot: String) -> void:
	if not _pending_sounds.has(slot):
		return
	var preview_player = AudioStreamPlayer.new()
	add_child(preview_player)
	preview_player.stream = _pending_sounds[slot]
	preview_player.pitch_scale = _pending_pitches.get(slot, 1.0)
	preview_player.play()
	# Auto-clean when done
	preview_player.finished.connect(func():
		preview_player.queue_free()
		is_previewing = false
		_refresh_button_states()
	)
	is_previewing = true
	_refresh_button_states()
	preview_player.play()

func _on_clear_pressed(slot: String) -> void:
	_pending_sounds.erase(slot)
	record_status.text = slot.capitalize() + " cleared."
	_refresh_button_states()

func _on_pitch_changed(value: float, slot: String) -> void:
	_pending_pitches[slot] = value
	var pitch_label = sound_panel.find_child("PitchLabel_" + slot, true, false)
	if pitch_label:
		pitch_label.text = "%.2f×" % value

# Call this when the player hits "Ready" on the Selection screen,
# BEFORE the existing ready RPC fires
func commit_sounds_to_profile() -> void:
	var local_id = multiplayer.get_unique_id()
	var profile = CreatureManager.get_profile(local_id)
	if not profile:
		return
	for slot in SOUND_SLOTS:
		if _pending_sounds.has(slot):
			profile.set_custom_sound(
				slot,
				_pending_sounds[slot],
				_pending_pitches.get(slot, 1.0)
			)
	# Broadcast to all other peers
	_sync_sounds_to_peers(local_id, profile)

func _sync_sounds_to_peers(player_id: int, profile) -> void:
	for slot in SOUND_SLOTS:
		if profile.has_custom_sound(slot):
			var raw: PackedByteArray = AudioRecorder.wav_to_bytes(profile.custom_sounds[slot])
			var pitch: float = profile.sound_pitches.get(slot, 1.0)
			# RPC through CreatureManager autoload — survives scene transitions
			CreatureManager.rpc("rpc_receive_peer_sound", player_id, slot, raw, pitch)
