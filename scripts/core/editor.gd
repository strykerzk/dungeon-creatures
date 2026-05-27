extends Control

@export_category("UI References")
@onready var stash_container: VBoxContainer = %StashList
@onready var status_label: Label = %StatusLabel

@onready var equip_panel: VBoxContainer = %EquipPanel
@onready var ready_button: Button = %ReadyButton

@onready var slot_buttons: Dictionary = {
	"weapon": %WeaponSlot,
	"head": %HeadSlot,
	"body": %BodySlot,
	"boots": %BootsSlot,
	"back": %BackSlot
}

var ready_players: Array[int] = []
var is_ready: bool = false
var local_profile: CreatureManager.CreatureProfile

func _ready() -> void:
	# 1. Get our local ID
	var my_id = multiplayer.get_unique_id()
	
	# 2. Fetch our profile from the global CreatureManager
	if typeof(CreatureManager) != TYPE_NIL:
		local_profile = CreatureManager.get_profile(my_id)
		
	if local_profile:
		_populate_stash_ui()
	else:
		status_label.text = "Error: Could not load profile data!"
	
	for slot_name in slot_buttons.keys():
		slot_buttons[slot_name].pressed.connect(_on_equip_slot_clicked.bind(slot_name))
	
	ready_button.pressed.connect(_on_ready_pressed)
	
	if local_profile:
		_refresh_ui()
	else:
		status_label.text = "ERROR: Could not load profile data!"

func _refresh_ui() -> void:
	_populate_stash_ui()
	_populate_equip_ui()

## Reads the stash array and creates a simple UI button for each item
func _populate_stash_ui() -> void:
	# Clear out any placeholder UI elements
	for child in stash_container.get_children():
		child.queue_free()
		
	var stash_items = local_profile.stash
	
	if stash_items.is_empty():
		status_label.text = "Your stash is empty. Better luck next time!"
		return
		
	status_label.text = "Select items to equip to your Creature."
	
	for i in range(stash_items.size()):
		var item: EquipmentData = stash_items[i]
		
		# Create a button for the item
		var btn = Button.new()
		btn.text = item.item_name + " (" + item.slot + ")"
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		
		# Optional: If your EquipmentData has an icon, add it here!
		# btn.icon = item.icon
		
		# We bind the item data to the button's pressed signal so we know WHICH item was clicked later
		btn.pressed.connect(_on_stash_item_clicked.bind(item))
		
		stash_container.add_child(btn)

func _on_stash_item_clicked(item_data: EquipmentData) -> void:
	print("[Editor] Equipping: ", item_data.item_name)
	
	# 1. If we already have something in this slot, unequip it first
	var target_slot = item_data.slot
	if local_profile.equipped_items.has(target_slot):
		_on_equip_slot_clicked(target_slot)
		
	# 2. Move item from Stash to Equipped
	local_profile.stash.erase(item_data)
	local_profile.equipped_items[target_slot] = item_data
	
	_refresh_ui()

func _populate_equip_ui() -> void:
	for slot_name in slot_buttons.keys():
		var btn: Button = slot_buttons[slot_name]
		if local_profile.equipped_items.has(slot_name):
			var item = local_profile.equipped_items[slot_name]
			btn.text = slot_name.capitalize() + ": " + item.item_name
		else:
			btn.text = slot_name.capitalize() + ": [Empty]"

func _on_equip_slot_clicked(slot_name: String) -> void:
	if not local_profile.equipped_items.has(slot_name):
		return # Nothing to unequip!
		
	var item_data = local_profile.equipped_items[slot_name]
	print("[Editor] Unequipping: ", item_data.item_name)
	
	# Move item from Equipped back to Stash
	local_profile.equipped_items.erase(slot_name)
	local_profile.stash.append(item_data)
	
	_refresh_ui()

func _on_ready_pressed() -> void:
	if !is_ready:
		is_ready = true
		status_label.text = "Waiting for other players..."
		
		# Extract resource paths to safely send over the network
		var serialized_build: Dictionary = {}
		for slot in local_profile.equipped_items.keys():
			var item: EquipmentData = local_profile.equipped_items[slot]
			serialized_build[slot] = item.resource_path
			
		print("[Editor] Build locked in! Sending to Host...")
		
		# Send our build to Peer ID 1 (The Host)
		rpc_id(1, "server_player_ready", multiplayer.get_unique_id(), serialized_build)
	else:
		is_ready = false
		status_label.text = "Canceled ready."
		
		rpc_id(1, "server_player_unready", multiplayer.get_unique_id())

@rpc("any_peer", "call_local", "reliable")
func server_player_ready(peer_id: int, serialized_build: Dictionary) -> void:
	if not multiplayer.is_server(): return
	
	# 1. Get this player's profile on the Host's machine
	var host_profile = CreatureManager.get_profile(peer_id)
	host_profile.equipped_items.clear()
	
	# 2. Rebuild the items from the file paths they sent us
	for slot in serialized_build.keys():
		var resource_path = serialized_build[slot]
		host_profile.equipped_items[slot] = load(resource_path)
		
	# 3. Mark them as ready
	if not peer_id in ready_players:
		ready_players.append(peer_id)
		print("[Editor] Player ", peer_id, " locked in! (", ready_players.size(), "/", NetworkManager.players.size(), ")")
		
	# 4. Check if everyone is ready
	if ready_players.size() >= NetworkManager.players.size():
		print("[Editor] All players ready! Proceeding to Arena...")
		rpc("toggle_ready_button")
		# Give a tiny delay so the final player sees the UI update before teleporting
		await get_tree().create_timer(1.0).timeout
		rpc("rpc_start_arena")

@rpc("any_peer", "call_local", "reliable")
func server_player_unready(peer_id: int) -> void:
	if not multiplayer.is_server(): return
	
	if peer_id in ready_players:
		ready_players.erase(peer_id)
		print("[Editor] Player ", peer_id, " canceled ready! (", ready_players.size(), "/", NetworkManager.players.size(), ")")

@rpc("authority", "call_local", "reliable")
func toggle_ready_button() -> void:
	ready_button.disabled = !ready_button.disabled

@rpc("authority", "call_local", "reliable")
func rpc_start_arena() -> void:
	if typeof(StageManager) != TYPE_NIL:
		StageManager.change_stage(StageManager.GameState.COMBAT)
