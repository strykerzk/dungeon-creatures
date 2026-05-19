extends Node2D

@onready var label: Label = $Label

func setup(emoji: String) -> void:
	label.text = emoji
	
	scale = Vector2.ZERO
	var tween = create_tween().set_parallel(true)
	
	# Pop in
	tween.tween_property(self, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Float up slightly
	tween.tween_property(self, "position:y", position.y - 30.0, 1.5).set_ease(Tween.EASE_OUT)
	
	# Fade out after 1.5s
	tween.chain().tween_property(self, "modulate:a", 0.0, 0.3)
	tween.chain().tween_callback(queue_free)
