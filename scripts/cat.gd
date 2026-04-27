extends Creature

# Node ref
@export_category("Nodes")
@export var animation_tree: AnimationTree

func _physics_process(delta: float) -> void:
	super(delta)
	
	# Animations
	look_direction = global_position.direction_to(target.global_position)
	animation_tree.set("parameters/Sprite Flip/blend_position", look_direction.x)
