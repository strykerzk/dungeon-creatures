extends Creature

# Node ref
@export_category("Local to Duck Nodes")
@export var animation_tree: AnimationTree

func _process(delta: float) -> void:
	super(delta)
	
	# Animations
	#animation_tree.set("parameters/Sprite Flip/blend_position", look_direction.x)
	
