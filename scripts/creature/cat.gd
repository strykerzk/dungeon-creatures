extends Creature

# Node ref
@export_category("Nodes")
@export var animation_tree: AnimationTree

func _physics_process(delta: float) -> void:
	super(delta)
	
	# Animations
	animation_tree.set("parameters/Sprite Flip/blend_position", look_direction.x)

func take_damage(amount: float) -> void:
	super(amount)
	
	$DamageNumber.text = str(int(amount))
	$DamageNumber.show()
	await get_tree().create_timer(0.3).timeout
	$DamageNumber.hide()

func dodge(attacker: Creature) -> void:
	super(attacker)
	$DodgeLabel.show()
	await get_tree().create_timer(1.0).timeout
	$DodgeLabel.hide()


func _on_button_pressed() -> void:
	equip(load("res://resources/weapon_data/sword.tres"))


func _on_button_2_pressed() -> void:
	set_mutation(load("res://resources/mutations/major/mu_juggernaut.tres"))
