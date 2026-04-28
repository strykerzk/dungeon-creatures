extends Node2D
class_name Weapon

@export var damage_mult: float
@export var attack_range: float
@export var cooldown_mod: float

@export var sprite: Sprite2D
@export var audio: AudioStreamPlayer2D

func activate(_base_damage: float, _attacker: CharacterBody2D) -> void:
	pass
