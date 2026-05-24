extends CanvasLayer

@onready var round_banner: Label = %RoundBanner
@onready var event_banner: Label = %EventBanner
@onready var countdown_banner: Label = %CountdownBanner
@onready var countdown_timer: Timer = %CountdownTimer
@onready var roster_list: RichTextLabel = %RosterList

var time_left: float = 0
var timer_started: bool = false
var portal_open: bool = false

func _ready() -> void:
	if typeof(StageManager) == TYPE_NIL: return
	
	time_left = StageManager.dungeon_time_limit
	round_start()

func _physics_process(delta: float) -> void:
	time_left -= delta
	var minutes: int = time_left / 60
	var seconds: int = time_left - (minutes * 60)
	if seconds < 10:
		countdown_banner.text = str(minutes) + ":0" + str(seconds)
	else:
		countdown_banner.text = str(minutes) + ":" + str(seconds)
	
	if time_left <= StageManager.dungeon_time_limit * 0.4 and !portal_open:
		portal_open = true
		countdown_banner.label_settings.outline_color = Color.LIME_GREEN
		countdown_banner.label_settings.outline_size = 24

func round_start() -> void:
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
	seq.tween_property(round_banner, "position:y", center_y - 30.0, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	
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
	seq.tween_property(event_banner, "modulate:a", 0.0, 0.3)
	seq.tween_property(round_banner, "modulate:a", 0.0, 0.3)
	#seq.tween_callback(queue_free)

func _setup_blind_roster() -> void:
	# TODO: In the future, we will pull the actual generated mutations for this seed!
	# For now, just show a placeholder hype message.
	roster_list.text = "[center]Hidden Corners contain Major Mutations![/center]"
