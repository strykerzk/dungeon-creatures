class_name EquipmentData extends Resource

@export var item_name: String = "Generic Item"
@export_enum("head", "body", "weapon", "boots", "back") var slot: String = "body"
@export var visual_scene: PackedScene # The .tscn for the sword/hat/etc.
@export var visual_id: String = "" # sword, wooden_hammer
@export var sprite_texture: Texture

@export_category("Skill Assignment")
@export var provided_skill: PackedScene
@export var ranged_projectile: PackedScene

@export_category("Progression")
@export_enum("Common","Rare","Epic","Legendary") var rarity: String = "Common"
@export var is_corrupted: bool = false
var star_level: int = 1
var original_path: String = ""

@export_category("Stat Changes")
@export_group("Primary Bonuses")
@export var health_bonus: float = 0.0
@export var speed_mod: float = 0.0
@export var IQ_bonus: int = 0
@export var aggression_bonus: float = 0.0
@export var dexterity_bonus: float = 0.0
@export var precision_bonus: float = 0.0

@export_group("Combat (Weapon Only)")
@export var attack_style: Creature.AttackStyle = Creature.AttackStyle.TACKLE
@export var attack_range: float = 350.0
@export var damage_bonus: float = 0.0 # Added to base creature damage
@export var attack_cooldown: float = 3.0 # Attack cooldowns
@export var projectile_speed: float = 1000.0 # For ranged weapons
