class_name EquipmentData extends Resource

@export var item_name: String = "Generic Item"
@export_enum("head", "body", "weapon", "boots", "back") var slot: String = "body"
@export var visual_scene: PackedScene # The .tscn for the sword/hat/etc.
@export var sprite_texture: Texture
@export var provided_skill: PackedScene

@export_group("Primary Bonuses")
@export var health_bonus: float = 0.0
@export var speed_mod: float = 0.0
@export var IQ_bonus: int = 0
@export var aggression_bonus: float = 0.0
@export var dexterity_bonus: float = 0.0
@export var precision_bonus: float = 0.0

@export_group("Combat (Weapon Only)")
@export var attack_style: Creature.AttackStyle = Creature.AttackStyle.TACKLE
@export var attack_range: float = 150.0
@export var damage_bonus: float = 0.0 # Added to base creature damage
@export var attack_cooldown: float = 3.0 # Attack cooldowns
@export var projectile_speed: float = 800.0 # For ranged weapons
