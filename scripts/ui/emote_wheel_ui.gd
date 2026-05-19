extends CanvasLayer

@onready var center_anchor: Control = $CenterAnchor
@onready var center_text: Label = $CenterAnchor/CenterText

# Array of dictionaries so we can store both the icon and the description!
var emotes = [
	{"angle": -PI/2,   "icon": "❗", "name": "Here!"},     # Top
	{"angle": -PI/4,   "icon": "👍", "name": "Good"},      # Top-Right
	{"angle": 0.0,     "icon": "🛑", "name": "Wait!"},     # Right
	{"angle": PI/4,    "icon": "💢", "name": "Angry"},     # Bottom-Right
	{"angle": PI/2,    "icon": "🆘", "name": "Help!"},      # Bottom
	{"angle": 3*PI/4,  "icon": "🥲", "name": "Sad"},       # Bottom-Left
	{"angle": PI,      "icon": "❓", "name": "What?"},     # Left
	{"angle": -3*PI/4, "icon": "❤️", "name": "Thanks"}     # Top-Left
]

var current_selection: String = ""
var wheel_center: Vector2

var inner_radius: float = 40.0
var outer_radius: float = 140.0

func _ready() -> void:
	# 1. Lock the wheel to wherever the cursor was when the button was pressed!
	wheel_center = get_viewport().get_mouse_position()
	
	center_anchor.draw.connect(_on_anchor_draw)

func _process(_delta: float) -> void:
	var mouse_pos = get_viewport().get_mouse_position()
	var dist = wheel_center.distance_to(mouse_pos)
	var dir = wheel_center.direction_to(mouse_pos)
	
	current_selection = ""
	var hovered_name = ""
	
	# Only select an item if the mouse is pushed past the inner deadzone
	if dist > inner_radius:
		var angle = dir.angle()
		var snapped_angle = snapped(angle, PI/4)
		if snapped_angle == -PI: snapped_angle = PI 
		
		# Find the matching emote
		for e in emotes:
			if is_equal_approx(e.angle, snapped_angle):
				current_selection = e.icon
				hovered_name = e.name
				break
				
	# Update the text in the middle of the wheel
	if current_selection != "":
		center_text.text = current_selection + "\n" + hovered_name
	else:
		center_text.text = "EMOTE"
		
	# Keep the text perfectly centered even when its size changes!
	center_text.position = wheel_center - (center_text.size / 2.0)
		
	# Force a redraw every frame so the hover highlight updates
	center_anchor.queue_redraw()

func _on_anchor_draw() -> void:
	# Draw the 8 slices
	for e in emotes:
		var is_hovered = (current_selection == e.icon)
		
		# Colors: Dark gray normally, Bright blue when hovered
		var bg_color = Color(0.1, 0.1, 0.1, 0.85) if not is_hovered else Color(0.1, 0.5, 0.8, 0.9)
		var line_color = Color(0.8, 0.6, 0.2, 1.0) # Gold border
		
		# Calculate the edges of this specific wedge (22.5 degrees on either side of the center angle)
		var start_angle = e.angle - (PI/8)
		var end_angle = e.angle + (PI/8)
		
		_draw_wedge(wheel_center, inner_radius, outer_radius, start_angle, end_angle, bg_color, line_color)
		
		# Draw the emoji icon in the middle of the wedge
		var mid_radius = (inner_radius + outer_radius) / 2.0
		var icon_pos = wheel_center + Vector2(cos(e.angle), sin(e.angle)) * mid_radius
		
		# Get the exact size of the emoji to perfectly center it
		var font = ThemeDB.fallback_font
		var icon_size = font.get_string_size(e.icon, HORIZONTAL_ALIGNMENT_LEFT, -1, 24)
		
		# Offset X by half width, offset Y by a fraction of height (since Godot draws strings from the baseline)
		var exact_center = icon_pos + Vector2(-icon_size.x / 2.0, icon_size.y / 3.0)
		
		center_anchor.draw_string(font, exact_center, e.icon, HORIZONTAL_ALIGNMENT_LEFT, -1, 24)

## Helper function to mathematically draw a curved "slice" of a circle
func _draw_wedge(center: Vector2, r_in: float, r_out: float, a_start: float, a_end: float, fill_col: Color, line_col: Color) -> void:
	var points = PackedVector2Array()
	var resolution = 8 # How smooth the curve is
	
	# 1. Draw the outer curve
	for i in range(resolution + 1):
		var t = i / float(resolution)
		var current_angle = lerp(a_start, a_end, t)
		points.append(center + Vector2(cos(current_angle), sin(current_angle)) * r_out)
		
	# 2. Draw the inner curve (in reverse so the polygon closes itself properly)
	for i in range(resolution + 1):
		var t = 1.0 - (i / float(resolution))
		var current_angle = lerp(a_start, a_end, t)
		points.append(center + Vector2(cos(current_angle), sin(current_angle)) * r_in)
		
	# Paint the wedge
	center_anchor.draw_polygon(points, PackedColorArray([fill_col]))
	
	# Draw the gold outline around the wedge
	points.append(points[0]) # Close the loop for the outline
	center_anchor.draw_polyline(points, line_col, 2.0, true)
