class_name Weapon extends Node2D

# Reference to the data that defined this weapon
var data: EquipmentData 
var attacker: Creature

# Values local to the node for quick access
var attack_range: float = 150.0
var attack_cd: float = 3.0
var attack_style: Creature.AttackStyle = Creature.AttackStyle.MELEE_TACKLE

@export var sprite: Sprite2D
@export var audio: AudioStreamPlayer2D

## Called by Creature.equip() immediately after instantiation
func setup(equipment_resource: EquipmentData) -> void:
	data = equipment_resource
	attack_range = data.attack_range
	attack_cd = data.attack_cooldown
	attack_style = data.attack_style

func activate(_base_damage: float, p_attacker: Creature) -> void:
	attacker = p_attacker
