extends Creature

# Node ref
@export_category("Nodes")
@export var animation_tree: AnimationTree
@export var attack_timer: Timer

func _physics_process(delta: float) -> void:
	super(delta)
	
	# Animations
	animation_tree.set("parameters/Sprite Flip/blend_position", velocity.normalized().x)

func attack() -> void:
	super()
	attack_timer.start(1.0)

func _on_attack_timer_timeout() -> void:
	if is_attacking:
		is_attacking = false
		attack_timer.start(3.0)
	else:
		can_attack = true
