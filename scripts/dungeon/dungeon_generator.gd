extends Node
class_name DungeonGenerator

class RoomBlueprint:
	var grid_pos: Vector2i
	var ring_level: int = 0
	var template_type: String = "Normal" # Can be changed to "Trap", "Loot", etc.
	var doors: Dictionary = {
		Vector2i.UP: false,
		Vector2i.DOWN: false,
		Vector2i.RIGHT: false,
		Vector2i.LEFT: false
	}
	
	func get_door_count() -> int:
		var count = 0
		for is_open in doors.values():
			if is_open: count += 1
		return count

var grid_size: int = 5
var grid: Array = [] # 2D Array of RoomBlueprints
var center_pos: Vector2i

func _ready() -> void:
	generate_dungeon(9)

func generate_dungeon(size: int = 5) -> Array:
	grid_size = size
	if grid_size % 2 == 0: grid_size += 1 # Force odd number
	
	center_pos = Vector2i(grid_size / 2, grid_size / 2)
	
	_initialize_grid()
	_carve_doors()
	_ensure_full_connectivity()
	
	_debug_print_grid()
	return grid

func _initialize_grid() -> void:
	grid.clear()
	for x in range(grid_size):
		var column = []
		for y in range(grid_size):
			var room = RoomBlueprint.new()
			room.grid_pos = Vector2i(x, y)
			
			# Chebyshev distance: max(abs(x1-x2), abs(y1-y2))
			# Center is 0, adjacent is 1, corners are 2, etc.
			var dist_x = abs(x - center_pos.x)
			var dist_y = abs(y - center_pos.y)
			room.ring_level = max(dist_x, dist_y)
			
			column.append(room)
		grid.append(column)

func _carve_doors() -> void:
	var directions = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	
	for x in range(grid_size):
		for y in range(grid_size):
			var room: RoomBlueprint = grid[x][y]
			
			# Shuffle directions to make the connections random
			var shuffled_dirs = directions.duplicate()
			shuffled_dirs.shuffle()
			
			for dir in shuffled_dirs:
				var neighbor_pos = room.grid_pos + dir
				
				# Check bounds
				if neighbor_pos.x >= 0 and neighbor_pos.x < grid_size and neighbor_pos.y >= 0 and neighbor_pos.y < grid_size:
					var neighbor: RoomBlueprint = grid[neighbor_pos.x][neighbor_pos.y]
					
					# Connect if we have less than 2 doors, OR a 40% chance for extra random webbing
					if room.get_door_count() < 2 or randf() < 0.3:
						_connect_rooms(room, neighbor, dir)

# Flood fill to ensure there are no isolated "islands"
func _ensure_full_connectivity() -> void:
	var visited = []
	var queue = [grid[center_pos.x][center_pos.y]]
	
	# Standard Breadth-First Search
	while queue.size() > 0:
		var current: RoomBlueprint = queue.pop_front()
		if current in visited: continue
		visited.append(current)
		
		# Add connected neighbors to queue
		for dir in current.doors:
			if current.doors[dir]:
				queue.append(grid[current.grid_pos.x + dir.x][current.grid_pos.y + dir.y])
				
	# If we didn't visit every room, we have an island. Fix it.
	var expected_total = grid_size * grid_size
	if visited.size() < expected_total:
		for x in range(grid_size):
			for y in range(grid_size):
				var room = grid[x][y]
				if not room in visited:
					# Find an adjacent room that IS in the visited list and smash a door open
					for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
						var n_pos = room.grid_pos + dir
						if n_pos.x >= 0 and n_pos.x < grid_size and n_pos.y >= 0 and n_pos.y < grid_size:
							var neighbor = grid[n_pos.x][n_pos.y]
							if neighbor in visited:
								_connect_rooms(room, neighbor, dir)
								# Re-run check just to be safe
								_ensure_full_connectivity()
								return

func _connect_rooms(room_a: RoomBlueprint, room_b: RoomBlueprint, dir_from_a: Vector2i) -> void:
	room_a.doors[dir_from_a] = true
	room_b.doors[-dir_from_a] = true # The opposite direction

## Prints a visual representation of the dungeon to the console
func _debug_print_grid() -> void:
	print("--- DUNGEON BLUEPRINT ---")
	for y in range(grid_size):
		var row_str = ""
		var bottom_doors = ""
		for x in range(grid_size):
			var room = grid[x][y]
			# Determine Room Type Char (C = Center, 1 = Ring1, etc)
			var char = "C" if room.ring_level == 0 else str(room.ring_level)
			
			# Right Door
			var right = "-" if room.doors[Vector2i.RIGHT] else " "
			row_str += "[" + char + "]" + right
			
			# Bottom Door
			var bottom = "|   " if room.doors[Vector2i.DOWN] else "    "
			bottom_doors += bottom
			
		print(row_str)
		print(bottom_doors)
	print("-------------------------")
