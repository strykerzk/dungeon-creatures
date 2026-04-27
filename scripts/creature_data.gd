class_name CreatureData extends Resource

@export_category("Stats")
@export var name: String = "Creature"
@export var base_health: float = 100.0
@export var damage: float = 10.0
@export var speed: float = 150.0
@export var IQ: int = 6
@export var aggression: float = 0.5   # 0 to 1: Likelihood to circle vs idle
@export var dexterity: float = 1.0    # Affects telegraph speed and dash power
@export var size: float = 1.0         # Affects scale and momentum (acceleration)
@export var precision: float = 0.5
