# Steam Manager - Template Autoload Script
# Place this in: res://scripts/SteamManager.gd
# Register in project.godot as: SteamManager="*res://scripts/SteamManager.gd"
#
# This is a template. Customize based on your game's needs.

extends Node

## Steam API initialization flag
var is_steam_initialized: bool = false

## Steam User ID
var steam_user_id: int = 0

## Steam Username
var steam_username: String = ""

## Track initialized callback connections
var _callbacks_connected: bool = false

## Signal emitted when Steam is ready
signal steam_ready

## Signal emitted on Steam initialization error
signal steam_error(error: String)

## Signal emitted when user achievements are loaded
signal achievements_loaded

## Signal emitted when user statistics are loaded
signal statistics_loaded

func _ready() -> void:
	"""Initialize Steam on startup."""
	if not await _initialize_steam():
		push_error("Failed to initialize Steam")
		emit_signal("steam_error", "Steam initialization failed")
		return
	
	_connect_steam_callbacks()
	print("[SteamManager] Steam initialized successfully")
	emit_signal("steam_ready")


func _initialize_steam() -> bool:
	"""
	Initialize the Steam API.
	Returns true if successful, false otherwise.
	"""
	# Check if GodotSteam is available
	if not Steam:
		push_error("GodotSteam plugin not found. Ensure addons/godotsteam is installed.")
		return false
	
	# Initialize Steam
	var init_result = Steam.steamInit()
	
	if init_result == false:
		push_error("Steam failed to initialize. Make sure Steam is running and steam_appid.txt exists.")
		return false
	
	is_steam_initialized = true
	
	# Get user information
	steam_user_id = Steam.getSteamID()
	steam_username = Steam.getFriendPersonaName(steam_user_id)
	
	print("[SteamManager] Steam initialized")
	print("[SteamManager] User ID: %d" % steam_user_id)
	print("[SteamManager] Username: %s" % steam_username)
	
	return true


func _connect_steam_callbacks() -> void:
	"""Connect to Steam callback signals."""
	if _callbacks_connected:
		return
	
	# User Statistics callbacks
	Steam.user_stats_received.connect(_on_user_stats_received)
	Steam.user_achievements_stored.connect(_on_achievement_stored)
	
	# Leaderboard callbacks (if using leaderboards)
	Steam.leaderboard_scores_downloaded.connect(_on_leaderboard_scores_downloaded)
	
	# Request user stats
	Steam.requestCurrentStats()
	
	_callbacks_connected = true


func _on_user_stats_received(game_id: int, result: int, user_id: int) -> void:
	"""Handle user statistics received from Steam."""
	if result == Steam.RESULT_OK:
		print("[SteamManager] User stats loaded successfully")
		emit_signal("statistics_loaded")
		
		# Load all achievements here if needed
		_load_achievements()
	else:
		push_error("[SteamManager] Failed to load user stats")


func _load_achievements() -> void:
	"""Load all achievements for the current user."""
	var achievement_count = Steam.getNumAchievements()
	print("[SteamManager] Found %d achievements" % achievement_count)
	
	for i in range(achievement_count):
		var achievement_name = Steam.getAchievementName(i)
		var is_unlocked = Steam.getAchievementAchieved(achievement_name)
		print("[SteamManager] Achievement '%s': %s" % [achievement_name, "Unlocked" if is_unlocked else "Locked"])
	
	emit_signal("achievements_loaded")


func _on_achievement_stored(name: String, achieved: bool) -> void:
	"""Handle achievement stored callback."""
	print("[SteamManager] Achievement '%s' stored: %s" % [name, "Achieved" if achieved else "Not achieved"])


func _on_leaderboard_scores_downloaded(leaderboard_handle: int) -> void:
	"""Handle leaderboard scores downloaded."""
	print("[SteamManager] Leaderboard scores downloaded")


# ============================================================================
# PUBLIC METHODS - Use these in your game code
# ============================================================================

func unlock_achievement(achievement_name: String) -> bool:
	"""
	Unlock an achievement.
	
	Args:
		achievement_name: The API name of the achievement (from Steamworks)
	
	Returns:
		true if successful, false otherwise
	"""
	if not is_steam_initialized:
		push_warning("[SteamManager] Steam not initialized, cannot unlock achievement")
		return false
	
	var result = Steam.setAchievement(achievement_name)
	
	if result:
		print("[SteamManager] Achievement unlocked: %s" % achievement_name)
		Steam.storeStats()  # Store to Steam servers
	else:
		push_error("[SteamManager] Failed to unlock achievement: %s" % achievement_name)
	
	return result


func set_statistic(stat_name: String, value: int) -> bool:
	"""
	Set a user statistic.
	
	Args:
		stat_name: The API name of the statistic
		value: The value to set
	
	Returns:
		true if successful, false otherwise
	"""
	if not is_steam_initialized:
		push_warning("[SteamManager] Steam not initialized, cannot set statistic")
		return false
	
	Steam.setStatInt(stat_name, value)
	var result = Steam.storeStats()
	
	if result:
		print("[SteamManager] Statistic set: %s = %d" % [stat_name, value])
	else:
		push_error("[SteamManager] Failed to set statistic: %s" % stat_name)
	
	return result


func get_statistic(stat_name: String) -> int:
	"""
	Get a user statistic.
	
	Args:
		stat_name: The API name of the statistic
	
	Returns:
		The statistic value, or 0 if not found
	"""
	if not is_steam_initialized:
		push_warning("[SteamManager] Steam not initialized, cannot get statistic")
		return 0
	
	return Steam.getStatInt(stat_name)


func is_achievement_unlocked(achievement_name: String) -> bool:
	"""
	Check if an achievement is unlocked.
	
	Args:
		achievement_name: The API name of the achievement
	
	Returns:
		true if unlocked, false otherwise
	"""
	if not is_steam_initialized:
		push_warning("[SteamManager] Steam not initialized, cannot check achievement")
		return false
	
	return Steam.getAchievementAchieved(achievement_name)


func show_store_page() -> void:
	"""Open the game's store page in Steam overlay."""
	if not is_steam_initialized:
		push_warning("[SteamManager] Steam not initialized, cannot show store page")
		return
	
	Steam.activateGameOverlayToWebPage("https://steamcommunity.com/app/YOUR_APP_ID")


func show_achievements() -> void:
	"""Open the achievements overlay."""
	if not is_steam_initialized:
		push_warning("[SteamManager] Steam not initialized, cannot show achievements")
		return
	
	Steam.activateGameOverlay("achievements")


func show_community() -> void:
	"""Open the Steam community overlay."""
	if not is_steam_initialized:
		push_warning("[SteamManager] Steam not initialized, cannot show community")
		return
	
	Steam.activateGameOverlay("community")


func upload_cloud_save(filename: String, file_contents: PackedByteArray) -> bool:
	"""
	Upload a file to Steam Cloud.
	
	Args:
		filename: Name of the file (e.g., "save_game_1.dat")
		file_contents: The file data to upload
	
	Returns:
		true if successful, false otherwise
	"""
	if not is_steam_initialized:
		push_warning("[SteamManager] Steam not initialized, cannot upload cloud save")
		return false
	
	var result = Steam.fileWrite(filename, file_contents)
	
	if result:
		print("[SteamManager] Cloud save uploaded: %s" % filename)
	else:
		push_error("[SteamManager] Failed to upload cloud save: %s" % filename)
	
	return result


func download_cloud_save(filename: String) -> PackedByteArray:
	"""
	Download a file from Steam Cloud.
	
	Args:
		filename: Name of the file to download
	
	Returns:
		The file contents as PackedByteArray, or empty array if failed
	"""
	if not is_steam_initialized:
		push_warning("[SteamManager] Steam not initialized, cannot download cloud save")
		return PackedByteArray()
	
	if not Steam.fileExists(filename):
		push_warning("[SteamManager] Cloud save does not exist: %s" % filename)
		return PackedByteArray()
	
	var file_contents = Steam.fileRead(filename)
	
	if file_contents.size() > 0:
		print("[SteamManager] Cloud save downloaded: %s" % filename)
	else:
		push_error("[SteamManager] Failed to download cloud save: %s" % filename)
	
	return file_contents


func get_user_info() -> Dictionary:
	"""
	Get current Steam user information.
	
	Returns:
		Dictionary with user_id, username, and other info
	"""
	return {
		"user_id": steam_user_id,
		"username": steam_username,
		"is_online": Steam.getFriendPersonaState(steam_user_id) == Steam.PERSONA_STATE_ONLINE
	}


# ============================================================================
# DEBUG METHODS - Remove before production
# ============================================================================

func debug_print_all_achievements() -> void:
	"""Print all achievements and their unlock status (debug only)."""
	if not is_steam_initialized:
		return
	
	var achievement_count = Steam.getNumAchievements()
	print("\n=== All Achievements ===")
	
	for i in range(achievement_count):
		var achievement_name = Steam.getAchievementName(i)
		var is_unlocked = Steam.getAchievementAchieved(achievement_name)
		print("  [%d] %s: %s" % [i, achievement_name, "✓" if is_unlocked else "✗"])
	
	print("=======================\n")


func debug_print_all_statistics() -> void:
	"""Print all statistics (debug only)."""
	if not is_steam_initialized:
		return
	
	var stat_count = Steam.getNumStats()
	print("\n=== All Statistics ===")
	
	for i in range(stat_count):
		var stat_name = Steam.getStatName(i)
		var stat_value = Steam.getStatInt(stat_name)
		print("  [%d] %s: %d" % [i, stat_name, stat_value])
	
	print("=====================\n")
