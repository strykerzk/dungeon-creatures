extends Area2D
class_name Hitbox

var damage_value: float = 0.0
var attacker: Creature = null

func _enter_tree() -> void:
	area_entered.connect(_on_area_entered)

func _init():
	# Hitboxes should usually only detect Hurtboxes (Layer/Mask setup)
	set_collision_layer_value(1, false)
	set_collision_layer_value(5, true)
	
	set_collision_mask_value(1, false)
	set_collision_mask_value(4, true)
	monitoring = false # Controlled by weapon/creature

func _on_area_entered(area: Area2D) -> void:
	if not multiplayer.is_server(): return
	
	if area.name == "Hurtbox":
		var entity = area.get_parent()
		if entity == attacker: return
		
		if entity.has_method("take_damage"):
			entity.take_damage(damage_value, attacker)
			print("Damage dealt!")
