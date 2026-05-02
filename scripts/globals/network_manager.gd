extends Node

## NetworkManager: Handles hosting, joining, and connection state robustness.
## MUST BE ADDED TO PROJECT AUTOLOADS AS "NetworkManager"

signal player_connected(peer_id: int, player_info: Dictionary)
signal player_disconnected(peer_id: int)
signal server_disconnected()
signal connection_failed()
signal connection_successful()

const PORT = 7000
const MAX_CLIENTS = 4
const DEFAULT_SERVER_IP = "127.0.0.1"

# Dictionary to store connected players. Key: peer_id, Value: Dictionary of info
var players: Dictionary = {}

# Local player info (Can be updated in the main menu later)
var local_player_info: Dictionary = {"name": "Player", "color": Color.WHITE}

func _ready() -> void:
	# 1. Hook into Godot's core multiplayer signals for robust state tracking
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_ok)
	multiplayer.connection_failed.connect(_on_connected_fail)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

## Starts a server on the host's machine.
func host_game() -> Error:
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, MAX_CLIENTS)
	
	if error != OK:
		push_error("[NetworkManager] Failed to host server: ", error)
		return error

	multiplayer.multiplayer_peer = peer
	
	# The host is always peer ID 1
	players[1] = local_player_info
	player_connected.emit(1, local_player_info)
	
	print("[NetworkManager] Hosted server successfully on Port: ", PORT)
	return OK

## Connects to a running server.
func join_game(address: String = "") -> Error:
	if address.is_empty():
		address = DEFAULT_SERVER_IP
		
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address, PORT)
	
	if error != OK:
		push_error("[NetworkManager] Failed to create client: ", error)
		return error

	multiplayer.multiplayer_peer = peer
	print("[NetworkManager] Connecting to server at ", address, "...")
	return OK

## Gracefully closes the connection and cleans up data.
func leave_game() -> void:
	players.clear()
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	print("[NetworkManager] Left the game. Connection closed.")

# --- SIGNAL HANDLERS (The Robustness Fixes) ---

func _on_player_connected(id: int) -> void:
	print("[NetworkManager] Peer connected: ", id)
	# When a new player connects, we immediately send them OUR local info.
	# We use a reliable RPC so the packet isn't lost during connection load spikes.
	rpc_id(id, "register_player", local_player_info)

func _on_player_disconnected(id: int) -> void:
	print("[NetworkManager] Peer disconnected: ", id)
	
	# Safeguard: Remove them from the tracking dictionary
	if players.has(id):
		players.erase(id)
		
	player_disconnected.emit(id)
	# Note: Physical nodes (like their Dungeon Runner) should be deleted by the scene 
	# listening to this signal, not directly by the NetworkManager.

func _on_connected_ok() -> void:
	print("[NetworkManager] Connection successful!")
	connection_successful.emit()

func _on_connected_fail() -> void:
	push_warning("[NetworkManager] Connection failed! Server might be offline or blocked.")
	# Safeguard: Clear the peer so the user can try again immediately without restarting the game.
	multiplayer.multiplayer_peer = null
	connection_failed.emit()

func _on_server_disconnected() -> void:
	push_warning("[NetworkManager] Server disconnected! (Host crashed or closed the game).")
	# Safeguard: Total cleanup. If the host drops, the clients must reset.
	players.clear()
	multiplayer.multiplayer_peer = null
	server_disconnected.emit()
	
	# Emergency fallback: Kick the player back to the main menu using our StageManager
	if typeof(StageManager) != TYPE_NIL:
		StageManager.change_stage(StageManager.GameState.MENU)

# --- REMOTE PROCEDURE CALLS (RPCs) ---

## This function runs on OTHER machines when called.
@rpc("any_peer", "reliable")
func register_player(new_player_info: Dictionary) -> void:
	# Determine who sent this packet
	var new_player_id = multiplayer.get_remote_sender_id()
	
	# Save their info to our local dictionary
	players[new_player_id] = new_player_info
	player_connected.emit(new_player_id, new_player_info)
	
	print("[NetworkManager] Registered player ", new_player_id, " (", new_player_info.name, ")")
