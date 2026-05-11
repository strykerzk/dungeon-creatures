class_name CreatureData extends Resource

@export_category("Stats")
@export var name: String = "Creature"
@export var base_health: float = 100.0
@export var damage: float = 10.0
@export var speed: float = 250.0
@export var IQ: int = 5
@export var aggression: float = 0.5   # 0 to 1: Likelihood to circle vs idle
@export var dexterity: float = 1.0    # Affects telegraph speed and dash power
@export var size: float = 1.0         # Affects scale and momentum (acceleration)
@export var precision: float = 0.5

# Min and Max used for clamping
@export_group("Stat Mininum and Maximums")
@export var min_health: float = 1.0
@export var min_speed: float = 50.0
@export var max_speed: float = 800.0
@export var min_damage: float = 1.0
@export var max_damage: float = 100.0
@export var min_IQ: int = 1
@export var max_IQ: int = 10
@export var min_aggression: float = 0.0
@export var max_aggression: float = 1.0
@export var min_dexterity: float = 0.1
@export var max_dexterity: float = 3.0
@export var min_precision: float = 0.0
@export var max_precision: float = 1.0
@export var min_size: float = 0.5
@export var max_size: float = 5.0
