extends Creature

# Node ref
@export_category("Local to Duck Nodes")
@export var animation_tree: AnimationTree

func _physics_process(delta: float) -> void:
	super(delta)
	# Animations
	animation_tree.set("parameters/Sprite Flip/blend_position", look_direction.x)

func _on_button_pressed() -> void:
	equip(load("res://resources/weapon_data/melee/sword.tres"))

func _on_button_2_pressed() -> void:
	set_mutation(load("res://resources/mutations/major/mu_juggernaut.tres"))

func _on_button_3_pressed() -> void:
	equip(load("res://resources/weapon_data/ranged/pistol.tres"))
