extends Node2D
class_name DamageNumber

var amount: float = 0.0

@onready var label: Label = $Label

func _ready() -> void:
	# Round the damage to a clean integer
	label.text = str(int(amount))
	
	# Set scale to zero initially so we can pop it in
	scale = Vector2.ZERO
	
	# Create a parallel tween (multiple animations happening at once)
	var tween = create_tween().set_parallel(true)
	
	# 1. PUNCHY ENTRY: Pop to 1.5x scale using a "bouncy" transition, then settle to 1.0x
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1).set_delay(0.15)
	
	# 2. FLOAT AWAY: Drift upwards smoothly
	tween.tween_property(self, "position:y", position.y - 10.0, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# 3. FADE OUT: Wait 0.2s so the player can read it, then fade to invisible
	tween.tween_property(self, "modulate:a", 0.0, 0.4).set_delay(0.2)
	
	# 4. CLEANUP: Once all animations finish, delete the node!
	tween.chain().tween_callback(queue_free)
