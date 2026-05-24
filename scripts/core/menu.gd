extends Control

@export_category("UI References")
@onready var name_input: LineEdit = $VBoxContainer/NameInput
@onready var host_button: Button = $VBoxContainer/HostButton
@onready var ip_input: LineEdit = $VBoxContainer/HBoxContainer/IPInput
@onready var join_button: Button = $VBoxContainer/HBoxContainer/JoinButton
@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var player_list: RichTextLabel = $VBoxContainer/PlayerList
@onready var start_game_button: Button = $VBoxContainer/StartGameButton

func _ready() -> void:
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	start_game_button.pressed.connect(_on_start_game_pressed)
	
	NetworkManager.connection_successful.connect(_on_connection_success)
	NetworkManager.connection_failed.connect(_on_connection_fail)
	NetworkManager.player_connected.connect(_on_player_list_changed)
	NetworkManager.player_disconnected.connect(_on_player_list_changed)
	
	if multiplayer.multiplayer_peer != null:
		NetworkManager.leave_game()
	
	start_game_button.hide()
	status_label.text = "Waiting for action..."
	name_input.text = "Runner_" + str(randi() % 1000)

func _update_local_player_info() -> void:
	if name_input.text.strip_edges() != "":
		NetworkManager.local_player_info["name"] = name_input.text.strip_edges()

func _on_host_pressed() -> void:
	_update_local_player_info()
	var err = NetworkManager.host_game()
	
	if err == OK:
		status_label.text = "Hosting on Port " + str(NetworkManager.PORT)
		host_button.disabled = true
		join_button.disabled = true
		ip_input.editable = false
		name_input.editable = false
		start_game_button.show()
		_update_player_list()
	else:
		status_label.text = "Failed to host!"

func _on_join_pressed() -> void:
	_update_local_player_info()
	var ip = ip_input.text.strip_edges()
	var err = NetworkManager.join_game(ip)
	
	if err == OK:
		status_label.text = "Connecting to " + (ip if ip != "" else "127.0.0.1") + "..."
		host_button.disabled = true
		join_button.disabled = true
		ip_input.editable = false
		name_input.editable = false
	else:
		status_label.text = "Failed to initiate connection!"

func _on_connection_success() -> void:
	status_label.text = "Connected to Server!"
	var my_id = multiplayer.get_unique_id()
	if not NetworkManager.players.has(my_id):
		NetworkManager.players[my_id] = NetworkManager.local_player_info
	_update_player_list()

func _on_connection_fail() -> void:
	status_label.text = "Connection Failed! Try again."
	host_button.disabled = false
	join_button.disabled = false
	ip_input.editable = true
	name_input.editable = true

func _on_player_list_changed(_id: int = 0, _info: Dictionary = {}) -> void:
	_update_player_list()

func _update_player_list() -> void:
	player_list.text = "[center]-- PLAYERS IN LOBBY --[/center]\n"
	
	# FIX: Extract keys, sort them numerically (1 is always first), then iterate
	var peer_ids = NetworkManager.players.keys()
	peer_ids.sort()
	
	var player_num = 1
	for peer_id in peer_ids:
		var p_name = NetworkManager.players[peer_id].name
		var prefix = " (Host)" if peer_id == 1 else ""
		var me_flag = " (You)" if peer_id == multiplayer.get_unique_id() else ""
		
		player_list.text += "- Player " + str(player_num) + ": " + p_name + prefix + me_flag + "\n"
		player_num += 1

func _on_start_game_pressed() -> void:
	rpc("rpc_start_game")

@rpc("any_peer", "call_local", "reliable")
func rpc_start_game() -> void:
	print("[Menu] Host started the game. Transitioning to Selection Phase...")
	if typeof(StageManager) != TYPE_NIL:
		StageManager.change_stage(StageManager.GameState.SELECTION)
