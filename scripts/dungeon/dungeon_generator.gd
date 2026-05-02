extends Node
class_name DungeonGenerator

class RoomBlueprint:
	var grid_pos: Vector2i
	var ring_level: int = 0
	var template_type: String = "Normal" # "Normal", "MajorAltar", "MinorAltar", "Coop"
	var doors: Dictionary = {
		Vector2i.UP: false, Vector2i.DOWN: false, 
		Vector2i.RIGHT: false, Vector2i.LEFT: false
	}
	
	func get_door_count() -> int:
		var count = 0
		for is_open in doors.values():
			if is_open: count += 1
		return count

var grid_size: int = 5
var grid: Array = []
var center_pos: Vector2i

func generate_dungeon(size: int = 5) -> Array:
	grid_size = size
	if grid_size % 2 == 0: grid_size += 1 
	center_pos = Vector2i(grid_size / 2, grid_size / 2)
	
	_initialize_grid()
	_open_center_room() # <-- NEW: Force center to be a 4-way hub
	_carve_doors()
	_ensure_full_connectivity()
	_assign_event_rooms() 
	
	return grid

func _initialize_grid() -> void:
	grid.clear()
	for x in range(grid_size):
		var column = []
		for y in range(grid_size):
			var room = RoomBlueprint.new()
			room.grid_pos = Vector2i(x, y)
			room.ring_level = max(abs(x - center_pos.x), abs(y - center_pos.y))
			column.append(room)
		grid.append(column)

## NEW: Forces all 4 doors open on the center room bidirectionally
func _open_center_room() -> void:
	var center_room = grid[center_pos.x][center_pos.y]
	var directions = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	
	for dir in directions:
		var n_pos = center_room.grid_pos + dir
		# Check bounds (though center room in odd grids will always have neighbors)
		if n_pos.x >= 0 and n_pos.x < grid_size and n_pos.y >= 0 and n_pos.y < grid_size:
			var neighbor = grid[n_pos.x][n_pos.y]
			_connect_rooms(center_room, neighbor, dir)

func _carve_doors() -> void:
	var directions = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	for x in range(grid_size):
		for y in range(grid_size):
			var room: RoomBlueprint = grid[x][y]
			var shuffled_dirs = directions.duplicate()
			shuffled_dirs.shuffle()
			
			for dir in shuffled_dirs:
				var neighbor_pos = room.grid_pos + dir
				if neighbor_pos.x >= 0 and neighbor_pos.x < grid_size and neighbor_pos.y >= 0 and neighbor_pos.y < grid_size:
					var neighbor: RoomBlueprint = grid[neighbor_pos.x][neighbor_pos.y]
					if room.get_door_count() < 2 or randf() < 0.4:
						_connect_rooms(room, neighbor, dir)

func _ensure_full_connectivity() -> void:
	# ... (Keep existing flood fill logic exactly as it was) ...
	var visited = []
	var queue = [grid[center_pos.x][center_pos.y]]
	while queue.size() > 0:
		var current: RoomBlueprint = queue.pop_front()
		if current in visited: continue
		visited.append(current)
		for dir in current.doors:
			if current.doors[dir]:
				queue.append(grid[current.grid_pos.x + dir.x][current.grid_pos.y + dir.y])
				
	var expected_total = grid_size * grid_size
	if visited.size() < expected_total:
		for x in range(grid_size):
			for y in range(grid_size):
				var room = grid[x][y]
				if not room in visited:
					for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
						var n_pos = room.grid_pos + dir
						if n_pos.x >= 0 and n_pos.x < grid_size and n_pos.y >= 0 and n_pos.y < grid_size:
							var neighbor = grid[n_pos.x][n_pos.y]
							if neighbor in visited:
								_connect_rooms(room, neighbor, dir)
								_ensure_full_connectivity()
								return

func _connect_rooms(room_a: RoomBlueprint, room_b: RoomBlueprint, dir_from_a: Vector2i) -> void:
	room_a.doors[dir_from_a] = true
	room_b.doors[-dir_from_a] = true

## NEW: Modifies the blueprint templates based on StageManager's event roll
func _assign_event_rooms() -> void:
	# Skip if StageManager isn't available
	if typeof(StageManager) == TYPE_NIL: return 
	
	# Get all rooms in the outermost ring
	var outer_rooms = []
	var max_ring = (grid_size / 2)
	for x in range(grid_size):
		for y in range(grid_size):
			if grid[x][y].ring_level == max_ring:
				outer_rooms.append(grid[x][y])
				
	# If we somehow don't have outer rooms, fallback
	if outer_rooms.is_empty(): return 
	
	match StageManager.current_dungeon_event:
		StageManager.DungeonEvent.MAJOR_ALTARS:
			# Find the 4 literal corners (x=0,y=0), (x=4,y=0), etc.
			for room in outer_rooms:
				if (room.grid_pos.x == 0 or room.grid_pos.x == grid_size - 1) and \
				   (room.grid_pos.y == 0 or room.grid_pos.y == grid_size - 1):
					room.template_type = "MajorAltar"
					
		StageManager.DungeonEvent.MINOR_MIX:
			# Pick 3 random outer rooms
			outer_rooms.shuffle()
			for i in range(min(3, outer_rooms.size())):
				outer_rooms[i].template_type = "MinorAltar"
				
		StageManager.DungeonEvent.MAJOR_COOP:
			# Pick 1 random outer room
			outer_rooms.pick_random().template_type = "CoopRoom"
