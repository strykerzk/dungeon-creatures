extends Control

@export_category("UI References")
@onready var species_dropdown: OptionButton = $VBoxContainer/SpeciesDropdown
@onready var lock_in_button: Button = $VBoxContainer/LockInButton
@onready var status_label: Label = $VBoxContainer/StatusLabel

# Tracks which players have locked in (Host only)
var ready_players: Array[int] = []

func _ready() -> void:
	# 1. Populate the dropdown with our available species
	species_dropdown.add_item("Duck")
	species_dropdown.add_item("Cat")
	species_dropdown.add_item("Pig")
	
	# 2. Connect the lock-in button
	lock_in_button.pressed.connect(_on_lock_in_pressed)
	
	status_label.text = "Choose your starting Creature!"

func _on_lock_in_pressed() -> void:
	# Disable UI to prevent spamming
	lock_in_button.disabled = true
	species_dropdown.disabled = true
	status_label.text = "Waiting for other players..."
	
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
	rpc_id(1, "server_player_locked_in", my_id, selected_species)

# --- NETWORK HANDSHAKE ---

@rpc("any_peer", "call_local", "reliable")
func server_player_locked_in(peer_id: int, selected_species: String) -> void:
	if not multiplayer.is_server(): return
	
	# The Host updates its master copy of the client's profile
	if typeof(CreatureManager) != TYPE_NIL:
		var profile = CreatureManager.get_profile(peer_id)
		if profile:
			profile.species = selected_species
			
	# Track the ready state
	if not peer_id in ready_players:
		ready_players.append(peer_id)
		print("[Selection] Player ", peer_id, " is ready as a ", selected_species, ". (", ready_players.size(), "/", NetworkManager.players.size(), ")")
		
	# Check if everyone has locked in
	if ready_players.size() >= NetworkManager.players.size():
		print("[Selection] All players ready! Teleporting to Arena...")
		# Give a slight delay so the last player sees the UI update
		await get_tree().create_timer(1.0).timeout
		rpc("rpc_start_arena")

@rpc("authority", "call_local", "reliable")
func rpc_start_arena() -> void:
	if typeof(StageManager) != TYPE_NIL:
		StageManager.change_stage(StageManager.GameState.COMBAT)
