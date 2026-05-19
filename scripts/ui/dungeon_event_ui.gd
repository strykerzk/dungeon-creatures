extends CanvasLayer

@onready var round_banner: Label = $RoundBanner
@onready var event_banner: Label = $EventBanner
@onready var roster_list: RichTextLabel = $RosterList

func _ready() -> void:
	if typeof(StageManager) == TYPE_NIL: return
	
	# 1. Setup the Text
	round_banner.text = "ROUND " + str(StageManager.current_round)
	
	var event_enum = StageManager.current_dungeon_event
	event_banner.text = StageManager.DungeonEvent.keys()[event_enum].replace("_", " ")
	
	if event_enum == StageManager.DungeonEvent.MAJOR_ALTARS:
		_setup_blind_roster()
		
	# 2. Sequence the Animations
	var seq = create_tween()
	
	# Banner 1: Slam the Round text down
	var center_y = get_viewport().size.y / 2.0 - 80.0
	seq.tween_property(round_banner, "position:y", center_y, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	
	# Pause for a beat
	seq.tween_interval(0.3)
	
	# Banner 2: Fade in the Event type underneath it
	seq.tween_property(event_banner, "modulate:a", 1.0, 0.5)
	
	# Banner 3: Fade in the Roster (if applicable)
	if event_enum == StageManager.DungeonEvent.MAJOR_ALTARS:
		seq.parallel().tween_property(roster_list, "modulate:a", 1.0, 0.5)
		
	# Pause so players can read it
	seq.tween_interval(1.5)
	
	# Fade everything out right as the 3.0s spawn lock releases
	seq.tween_property(self, "modulate:a", 0.0, 0.3)
	seq.tween_callback(queue_free)

func _setup_blind_roster() -> void:
	# TODO: In the future, we will pull the actual generated mutations for this seed!
	# For now, just show a placeholder hype message.
	roster_list.text = "[center]Hidden Corners contain Major Mutations![/center]"
