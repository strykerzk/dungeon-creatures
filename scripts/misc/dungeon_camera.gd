extends Camera2D

var default_zoom: Vector2 = Vector2(1.0, 1.0)
var starting_wide_zoom: Vector2 = Vector2(0.3, 0.3)

var is_spectating: bool = false
var spectate_index: int = 0
var active_players: Array[Node2D] = []

@export var follow_speed: float = 5.0

func _ready() -> void:
	zoom = starting_wide_zoom
	
	var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "zoom", default_zoom, 2.5)

func _process(delta: float) -> void:
	if not is_spectating: return
	
	_update_active_players()
	
	if active_players.is_empty(): 
		return # No one left to spectate
		
	_handle_input()
	
	var target_player = active_players[spectate_index]
	
	# Lerp the camera to the center of the room the target player is currently in!
	if "current_room_center" in target_player:
		var target_pos = target_player.current_room_center
		global_position = global_position.lerp(target_pos, follow_speed * delta)

func start_spectating() -> void:
	is_spectating = true
	print("[DungeonCamera] Spectator mode activated.")
	
	var minimap = get_node_or_null("../DungeonInstantiator/MiniMap")
	if minimap and minimap.has_method("reveal_all"):
		minimap.reveal_all()
	
	var instantiator = get_node_or_null("../DungeonInstantiator")
	if instantiator and instantiator.has_method("lift_fog"):
		instantiator.lift_fog()

func _update_active_players() -> void:
	active_players.clear()
	var players_container = get_node_or_null("../Players")
	if not players_container: return
	
	var my_id = multiplayer.get_unique_id()
	for child in players_container.get_children():
		if child.name == "MultiplayerSpawner": continue
		# Only spectate OTHER players who haven't extracted (we check visibility since extracted players are hidden)
		if child.name.to_int() != my_id and child.visible:
			active_players.append(child)

func _handle_input() -> void:
	# You can use cycle_right/left, or just piggyback off movement keys!
	if Input.is_action_just_pressed("move_right"):
		spectate_index = (spectate_index + 1) % active_players.size()
	elif Input.is_action_just_pressed("move_left"):
		spectate_index -= 1
		if spectate_index < 0:
			spectate_index = active_players.size() - 1
