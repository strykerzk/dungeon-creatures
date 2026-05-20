class_name MutationData extends Resource

@export var mutation_name: String = "Unknown Mutation"
@export_multiline var description: String = "Stat changes go here."
@export_enum("major", "minor") var mutation_type: String = "major"
@export var icon: Texture2D
@export var provided_skill: PackedScene

# Major Mutations have all mults plus choice of additive mods
@export_group("Major Mutations")
@export var health_mult: float = 1.0
@export var damage_mult: float = 1.0
@export var speed_mult: float = 1.0
@export var size_mult: float = 1.0

# Minor mutations are additive
@export_group("Minor Mutations")
@export var health_bonus: float = 0.0
@export var damage_bonus: float = 0.0
@export var speed_mod: float = 0.0
@export var IQ_bonus: int = 0
@export var aggression_bonus: float = 0.0
@export var dexterity_bonus: float = 0.0
@export var precision_bonus: float = 0.0
