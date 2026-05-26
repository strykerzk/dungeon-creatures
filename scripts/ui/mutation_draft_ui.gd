extends CanvasLayer

@onready var container: HBoxContainer = $ColorRect/HBoxContainer
var player_ref: Node2D = null
var altar_ref: Node2D = null
var room_pos: Vector2i = Vector2i.ZERO

func setup(player: Node2D, altar: Node2D) -> void:
	player_ref = player
	altar_ref = altar
	_populate_choices()

func _populate_choices() -> void:
	for child in container.get_children():
		child.queue_free()
	
	# Get what's still available in the announced pool
	var available: Array[MutationData] = StageManager.get_available_pool()
	
	# Filter out the player's current mutation (no re-drafting the same one)
	if typeof(CreatureManager) != TYPE_NIL and player_ref:
		var profile = CreatureManager.get_profile(player_ref.name.to_int())
		if profile and profile.major_mutation:
			available = available.filter(func(m): return m != profile.major_mutation)
	
	if available.is_empty():
		# All mutations in pool have been claimed by other players
		var empty_label = RichTextLabel.new()
		empty_label.bbcode_enabled = true
		empty_label.text = "[center][color=red]All mutations have been claimed!\nExplore other altars or skip.[/color][/center]"
		container.add_child(empty_label)
		# Auto-close after a moment
		await get_tree().create_timer(2.5).timeout
		if is_inside_tree(): queue_free()
		return
	
	# Show up to 3 random options from the still-available pool
	available.shuffle()
	var choices_to_show: int = min(3, available.size())
	
	for i in range(choices_to_show):
		var mut: MutationData = available[i]
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(250, 350)
	
		var text = "[center]"
		text += "[font_size=24][color=gold]" + mut.mutation_name + "[/color][/font_size]\n\n"
		text += mut.description
		text += "[/center]"
	
		var label = RichTextLabel.new()
		label.bbcode_enabled = true
		label.text = text
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.set_anchors_preset(Control.PRESET_FULL_RECT)
	
		btn.add_child(label)
		btn.pressed.connect(_on_mutation_chosen.bind(mut.resource_path))
		container.add_child(btn)
	
	# Skip button
	var skip_btn = Button.new()
	skip_btn.custom_minimum_size = Vector2(150, 350)
	
	var skip_label = RichTextLabel.new()
	skip_label.bbcode_enabled = true
	skip_label.text = "[center]\n\n\n[font_size=24][color=gray]SKIP[/color][/font_size]\n\nLeave DNA unchanged.[/center]"
	skip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skip_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	skip_btn.add_child(skip_label)
	skip_btn.pressed.connect(_on_skip_chosen)
	container.add_child(skip_btn)

func _on_skip_chosen() -> void:
	if player_ref and player_ref.has_method("_show_feedback"):
		player_ref._show_feedback("Mutation Skipped.")
	queue_free()

func _on_mutation_chosen(path: String) -> void:
	# Immediately broadcast the claim to all machines BEFORE the UI closes
	# This prevents a race where two players simultaneously pick the same mutation
	StageManager.rpc("rpc_mark_mutation_drafted", path)
	
	if player_ref and player_ref.has_method("confirm_major_mutation"):
		player_ref.confirm_major_mutation(path)
	if altar_ref and altar_ref.has_method("rpc_deactivate"):
		altar_ref.rpc("rpc_deactivate")
	
	player_ref.has_drafted_mutation = true
	queue_free()
