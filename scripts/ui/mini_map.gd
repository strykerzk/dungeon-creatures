extends CanvasLayer
class_name MiniMap

@onready var map_control: Control = $MapControl
@onready var background_dim: ColorRect = $BackgroundDim

var grid: Array = []
var discovered_rooms: Array[Vector2i] = []

# Visual Settings
var room_size: float = 40.0
var spacing: float = 60.0

func _ready() -> void:
	hide_map() # Hidden by default
	# Connect the Control node's internal draw signal to our custom drawing function
	map_control.draw.connect(_on_map_draw)
	
func setup(_grid: Array, center_pos: Vector2i) -> void:
	grid = _grid
	discover_room(center_pos) # Always discover the starting hub immediately

func discover_room(grid_pos: Vector2i) -> void:
	if not grid_pos in discovered_rooms:
		discovered_rooms.append(grid_pos)
		map_control.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_map"):
		if map_control.visible:
			hide_map()
		else:
			show_map()

func show_map() -> void:
	map_control.visible = true
	background_dim.visible = true
	
func hide_map() -> void:
	map_control.visible = false
	background_dim.visible = false

func _on_map_draw() -> void:
	if grid.is_empty(): return
	
	var offset = map_control.get_viewport_rect().size / 2.0
	
	# Calculate grid center to offset the drawing so the hub is exactly in the middle of the screen
	var grid_width = grid.size()
	var center_room = Vector2(grid_width / 2.0, grid_width / 2.0)
	
	for x in range(grid.size()):
		for y in range(grid[x].size()):
			var blueprint: DungeonGenerator.RoomBlueprint = grid[x][y]
			
			if blueprint.grid_pos in discovered_rooms:
				# Math to position the rooms relative to the center of the screen
				var rel_x = x - center_room.x
				var rel_y = y - center_room.y
				var draw_pos = offset + (Vector2(rel_x, rel_y) * spacing)
				
				var rect = Rect2(draw_pos - Vector2(room_size/2, room_size/2), Vector2(room_size, room_size))
				
				# 1. Draw Corridors (White Lines connecting doors)
				for dir_vec in blueprint.doors:
					if blueprint.doors[dir_vec]:
						var end_pos = draw_pos + (Vector2(dir_vec) * (spacing / 2.0))
						map_control.draw_line(draw_pos, end_pos, Color.WHITE, 6.0)
						
				# 2. Draw Room Background
				map_control.draw_rect(rect, Color.BLACK, true)
				
				# 3. Draw Room Border
				map_control.draw_rect(rect, Color.WHITE, false, 3.0)
				
				# 4. Highlight Major Event Rooms (Red Dot)
				if blueprint.template_type == "MajorAltar":
					map_control.draw_circle(draw_pos, 6.0, Color.RED)
