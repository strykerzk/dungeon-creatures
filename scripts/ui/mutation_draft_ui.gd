extends CanvasLayer

@export var mutation_pool: Array[MutationData]
@onready var container: HBoxContainer = $ColorRect/HBoxContainer
var player_ref: Node2D = null
var altar_ref: Node2D = null

func setup(player: Node2D, altar: Node2D) -> void:
	player_ref = player
	altar_ref = altar
	_populate_choices()

func _populate_choices() -> void:
	for child in container.get_children():
		child.queue_free()
		
	# 1. Gather the currently active mutation
	var active_mutation: MutationData = null
	if typeof(CreatureManager) != TYPE_NIL and player_ref:
		var profile = CreatureManager.get_profile(player_ref.name.to_int())
		if profile and profile.major_mutation:
			active_mutation = profile.major_mutation
			
	# 2. Filter the pool to EXCLUDE the active mutation
	var valid_mutations: Array[MutationData] = []
	for mut in mutation_pool:
		if mut != active_mutation:
			valid_mutations.append(mut)
			
	# 3. Pick up to 3 random options
	valid_mutations.shuffle()
	var choices_to_show = min(3, valid_mutations.size())
	
	for i in range(choices_to_show):
		var mut = valid_mutations[i]
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
		
	# 4. Add the SKIP Button
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
	if player_ref and player_ref.has_method("confirm_major_mutation"):
		player_ref.confirm_major_mutation(path)
	if altar_ref and altar_ref.has_method("rpc_deactivate"):
		altar_ref.rpc("rpc_deactivate")
	
	queue_free() # Close the UI
