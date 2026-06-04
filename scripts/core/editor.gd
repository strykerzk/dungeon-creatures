extends Control

@export_category("UI References")
@onready var stash_grid: GridContainer = %StashGrid
@onready var status_label: Label = %StatusLabel

@onready var equip_grid: GridContainer = %EquipGrid
@onready var ready_button: Button = %ReadyButton

@onready var major_texture: TextureRect = %MajorTexture
@onready var minor_grid: GridContainer = %MinorContainer

@onready var sprite_textures: Dictionary = {
	"base": %BaseTexture,
	"back": %BackTexture,
	"boots": %BootsTexture,
	"body": %BodyTexture,
	"head": %HeadTexture,
	"weapon": %WeaponTexture
}

@onready var slot_buttons: Dictionary = {
	"weapon": [%WeaponSlot,"res://art/equipment/ui/weapon_empty.png"],
	"head": [%HeadSlot,"res://art/equipment/ui/head_empty.png"],
	"body": [%BodySlot,"res://art/equipment/ui/body_empty.png"],
	"boots": [%BootsSlot,"res://art/equipment/ui/boots_empty.png"],
	"back": [%BackSlot,"res://art/equipment/ui/back_empty.png"]
}

@onready var stash_buttons: Dictionary[String, Button] = {
	"all": %StashAll,
	"head": %StashHead,
	"body": %StashBody,
	"back": %StashBack,
	"boots": %StashBoots,
	"weapon": %StashWeapon
}


var ready_players: Array[int] = []
var is_ready: bool = false
var local_profile: CreatureManager.CreatureProfile
var stash_mode = "all"

func _ready() -> void:
	# 1. Get our local ID
	var my_id = multiplayer.get_unique_id()
	
	# 2. Fetch our profile from the global CreatureManager
	if typeof(CreatureManager) != TYPE_NIL:
		local_profile = CreatureManager.get_profile(my_id)
		
	if local_profile:
		_populate_stash_ui()
		_dress_up_sprite()
	else:
		status_label.text = "Error: Could not load profile data!"
	
	for slot_name in slot_buttons.keys():
		slot_buttons[slot_name][0].pressed.connect(_on_equip_slot_clicked.bind(slot_name))
	
	ready_button.pressed.connect(_on_ready_pressed)
	
	if local_profile:
		_refresh_ui()
	else:
		status_label.text = "ERROR: Could not load profile data!"

func _refresh_ui() -> void:
	_dress_up_sprite()
	_populate_stash_ui()
	_update_stash_buttons()
	_populate_equip_ui()
	_populate_mutation_ui()

func _dress_up_sprite() -> void:
	var file_path: String = ""
	for key in sprite_textures.keys():
		if sprite_textures[key].texture == null:
			if key == "base":
				file_path = "res://art/creature_sprites/"+ local_profile.species \
				+ "/" + local_profile.species + "_base.png"
				sprite_textures[key].texture = load(file_path )
			elif local_profile.equipped_items.has(key):
				var item: EquipmentData = local_profile.equipped_items[key]
				file_path = "res://art/equipment/" + key + "/" + item.visual_id \
				+ "_" + local_profile.species + ".png"
				if FileAccess.file_exists(file_path):
					sprite_textures[key].texture = load(file_path)
		elif not local_profile.equipped_items.has(key):
			if key != "base":
				sprite_textures[key].texture = null

## Reads the stash array and creates a simple UI button for each item
func _populate_stash_ui() -> void:
	# Clear out any placeholder UI elements
	for child in stash_grid.get_children():
		child.queue_free()
		
	var stash_items = local_profile.stash
	
	if stash_items.is_empty():
		status_label.text = "Your stash is empty. Better luck next time!"
		return
		
	status_label.text = "Select items to equip to your Creature."
	
	for i in range(stash_items.size()):
		var item: EquipmentData = stash_items[i]
		
		if stash_mode != "all" and item.slot != stash_mode: continue
		
		var m_container = MarginContainer.new()
		
		m_container.custom_minimum_size = Vector2(128,128)
		m_container.add_theme_constant_override("margin_left", 10)
		m_container.add_theme_constant_override("margin_top", 10)
		m_container.add_theme_constant_override("margin_right", 10)
		m_container.add_theme_constant_override("margin_bottom", 10)
		
		
		var btn = Button.new()
		#btn.text = item.item_name + " (" + item.slot + ")"
		#btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		
		# Optional: If your EquipmentData has an icon, add it here!
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.icon = item.sprite_texture
		btn.expand_icon = true
		btn.theme = load("res://resources/ui/stash_ui.tres")
		
		# We bind the item data to the button's pressed signal so we know WHICH item was clicked later
		btn.pressed.connect(_on_stash_item_clicked.bind(item))
		
		stash_grid.add_child(m_container)
		m_container.add_child(btn)

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

func _update_stash_buttons() -> void:
	for slot in stash_buttons.keys():
		if slot == stash_mode:
			stash_buttons[slot].flat = true
		else:
			stash_buttons[slot].flat = false

func _populate_equip_ui() -> void:
	for slot_name in slot_buttons.keys():
		var btn: Button = slot_buttons[slot_name][0]
		if local_profile.equipped_items.has(slot_name):
			var item = local_profile.equipped_items[slot_name]
			#btn.text = slot_name.capitalize() + ": " + item.item_name
			btn.icon = item.sprite_texture
			btn.expand_icon = true
		else:
			#btn.text = slot_name.capitalize() + ": [Empty]"
			btn.icon = load(slot_buttons[slot_name][1].trim_prefix(".remap"))

func _on_equip_slot_clicked(slot_name: String) -> void:
	if not local_profile.equipped_items.has(slot_name):
		return # Nothing to unequip!
		
	var item_data = local_profile.equipped_items[slot_name]
	print("[Editor] Unequipping: ", item_data.item_name)
	
	# Move item from Equipped back to Stash
	local_profile.equipped_items.erase(slot_name)
	local_profile.stash.append(item_data)
	
	_refresh_ui()

func _populate_mutation_ui() -> void:
	if major_texture.texture == null:
		if local_profile.major_mutation != null:
			major_texture.texture = local_profile.major_mutation.icon
	
	for child in minor_grid.get_children():
		child.queue_free()
	
	for mutation in local_profile.minor_mutations:
		
		var m_container = MarginContainer.new()
		m_container.custom_minimum_size = Vector2(128,128)
		m_container.add_theme_constant_override("margin_left", 10)
		m_container.add_theme_constant_override("margin_top", 10)
		m_container.add_theme_constant_override("margin_right", 10)
		m_container.add_theme_constant_override("margin_bottom", 10)
		
		var btn = Button.new()
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.icon = mutation.icon
		btn.expand_icon = true
		btn.pressed.connect(_on_minor_mutation_clicked.bind(btn))
		
		minor_grid.add_child(m_container)
		m_container.add_child(btn)

func _on_minor_mutation_clicked(btn: Button) -> void:
	pass

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


func _on_stash_all_pressed() -> void:
	if stash_mode != "all":
		stash_mode = "all"
	_refresh_ui()


func _on_stash_head_pressed() -> void:
	if stash_mode != "head":
		stash_mode = "head"
	_refresh_ui()


func _on_stash_body_pressed() -> void:
	if stash_mode != "body":
		stash_mode = "body"
	_refresh_ui()


func _on_stash_back_pressed() -> void:
	if stash_mode != "back":
		stash_mode = "back"
	_refresh_ui()


func _on_stash_boots_pressed() -> void:
	if stash_mode != "boots":
		stash_mode = "boots"
	_refresh_ui()


func _on_stash_weapon_pressed() -> void:
	if stash_mode != "weapon":
		stash_mode = "weapon"
	_refresh_ui()
