extends Camera2D

var default_zoom: Vector2 = Vector2(1.0, 1.0)
var starting_wide_zoom: Vector2 = Vector2(0.3, 0.3)

func _ready() -> void:
	zoom = starting_wide_zoom
	
	var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "zoom", default_zoom, 2.5)
