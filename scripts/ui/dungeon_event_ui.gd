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
	
	if time_left < 0:
		countdown_banner.hide()
		return
	
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
	round_banner.text = "ROUND " + str(StageManager.current_round)
	
	var event_enum = StageManager.current_dungeon_event
	event_banner.text = StageManager.DungeonEvent.keys()[event_enum].replace("_", " ")
	
	if event_enum == StageManager.DungeonEvent.MAJOR_ALTARS:
		if not StageManager.announced_major_pool.is_empty():
			# Pool already arrived (host's local call resolves instantly)
			_setup_announced_roster()
		else:
			# Clients: pool is in transit, wait for the signal
			StageManager.announced_pool_ready.connect(
				_setup_announced_roster, CONNECT_ONE_SHOT
			)
		
	# Sequence animations (same as before)
	var seq = create_tween()
	seq.tween_property(round_banner, "modulate:a", 1.0, 0.3)
	seq.tween_interval(0.3)
	seq.tween_property(event_banner, "modulate:a", 1.0, 0.5)
	
	if event_enum == StageManager.DungeonEvent.MAJOR_ALTARS:
		seq.parallel().tween_property(roster_list, "modulate:a", 1.0, 0.5)
	
	seq.tween_interval(2.5)  # Slightly longer so players can read the mutation list
	seq.tween_property(event_banner, "modulate:a", 0.0, 0.3)
	seq.tween_property(round_banner, "modulate:a", 0.0, 0.3)
	seq.tween_property(roster_list, "modulate:a", 0.0, 0.3)
	#seq.tween_callback(queue_free)

func _setup_announced_roster() -> void:
	var pool = StageManager.announced_major_pool
	
	if pool.is_empty():
		roster_list.text = "[center][color=gray]Loading mutations...[/color][/center]"
		return
	
	var text = "[center][font_size=16][color=gold]━━ MAJOR MUTATIONS IN PLAY ━━[/color][/font_size]\n\n"
	for mut in pool:
		text += "[color=gold]◆ " + mut.mutation_name + "[/color]\n"
		text += "[color=gray][font_size=12]" + mut.description + "[/font_size][/color]\n\n"
	text += "[/center]"
	roster_list.text = text
