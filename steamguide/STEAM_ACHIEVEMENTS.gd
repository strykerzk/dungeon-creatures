# Steam Achievements Template
# Place this in: res://scripts/SteamAchievements.gd
#
# This template shows how to integrate achievements into your game systems.
# Connect this to your existing systems (CreatureManager, StageManager, etc.)

extends Node

## Reference to SteamManager autoload
@onready var steam_manager = SteamManager

# ============================================================================
# ACHIEVEMENT CONSTANTS
# ============================================================================
# Define your achievements here. These names MUST match exactly with your
# Steamworks backend configuration. Get them from your Steamworks dashboard.

const ACHIEVEMENTS = {
	# Explorer Achievements
	"EXPLORE_FIRST_ROOM": {
		"id": "ACH_EXPLORE_FIRST_ROOM",
		"name": "First Steps",
		"description": "Enter the first room of the dungeon",
	},
	"EXPLORE_ALL_ROOMS": {
		"id": "ACH_EXPLORE_ALL_ROOMS",
		"name": "Complete Explorer",
		"description": "Discover all rooms in a dungeon",
	},
	
	# Combat Achievements
	"DEFEAT_FIRST_ENEMY": {
		"id": "ACH_DEFEAT_FIRST_ENEMY",
		"name": "Monster Slayer",
		"description": "Defeat your first creature",
	},
	"DEFEAT_BOSS": {
		"id": "ACH_DEFEAT_BOSS",
		"name": "Boss Vanquisher",
		"description": "Defeat a boss creature",
	},
	"KILL_STREAK_10": {
		"id": "ACH_KILL_STREAK_10",
		"name": "On Fire",
		"description": "Defeat 10 creatures without dying",
	},
	
	# Collection Achievements
	"COLLECT_ORB_MINOR": {
		"id": "ACH_COLLECT_MINOR_ORB",
		"name": "Orb Collector",
		"description": "Collect your first minor orb",
	},
	"COLLECT_ALL_ORBS": {
		"id": "ACH_COLLECT_ALL_ORBS",
		"name": "Orb Master",
		"description": "Collect all types of orbs",
	},
	
	# Challenge Achievements
	"SPEEDRUN_LEVEL": {
		"id": "ACH_SPEEDRUN_LEVEL",
		"name": "Speed Demon",
		"description": "Complete a level in under 5 minutes",
	},
	"PERFECT_LEVEL": {
		"id": "ACH_PERFECT_LEVEL",
		"name": "Flawless",
		"description": "Complete a level without taking damage",
	},
	
	# Progression Achievements
	"REACH_LEVEL_10": {
		"id": "ACH_REACH_LEVEL_10",
		"name": "Rising Power",
		"description": "Reach level 10",
	},
	"REACH_LEVEL_50": {
		"id": "ACH_REACH_LEVEL_50",
		"name": "True Warrior",
		"description": "Reach level 50",
	},
	
	# Secret Achievements
	"FIND_SECRET_ROOM": {
		"id": "ACH_FIND_SECRET_ROOM",
		"name": "Secret Finder",
		"description": "Discover a hidden room",
	},
	"UNLOCK_SECRET_ENDING": {
		"id": "ACH_UNLOCK_SECRET_ENDING",
		"name": "Hidden Truth",
		"description": "Unlock the secret ending",
	},
}

func _ready() -> void:
	"""Connect to game systems for achievement tracking."""
	# Wait for SteamManager to be ready
	if steam_manager:
		await steam_manager.steam_ready
		print("[SteamAchievements] Steam ready, achievements enabled")
	else:
		push_warning("[SteamAchievements] SteamManager not found, achievements disabled")
	
	# Connect to game signals
	# These are examples - modify based on your actual signal structure
	
	# Example: Connect to CreatureManager
	#if CreatureManager:
	#	CreatureManager.creature_defeated.connect(_on_creature_defeated)
	#	CreatureManager.boss_defeated.connect(_on_boss_defeated)
	
	# Example: Connect to StageManager
	#if StageManager:
	#	StageManager.room_entered.connect(_on_room_entered)
	#	StageManager.level_completed.connect(_on_level_completed)


# ============================================================================
# ACHIEVEMENT UNLOCK METHODS
# ============================================================================

func unlock_achievement(achievement_key: String) -> void:
	"""
	Unlock an achievement by its key.
	
	Args:
		achievement_key: Key from ACHIEVEMENTS dict (e.g., "DEFEAT_FIRST_ENEMY")
	"""
	if achievement_key not in ACHIEVEMENTS:
		push_error("[SteamAchievements] Unknown achievement: %s" % achievement_key)
		return
	
	if not steam_manager or not steam_manager.is_steam_initialized:
		print("[SteamAchievements] Steam not initialized, skipping achievement: %s" % achievement_key)
		return
	
	var achievement_id = ACHIEVEMENTS[achievement_key]["id"]
	var achievement_name = ACHIEVEMENTS[achievement_key]["name"]
	
	# Check if already unlocked
	if steam_manager.is_achievement_unlocked(achievement_id):
		print("[SteamAchievements] Achievement already unlocked: %s" % achievement_name)
		return
	
	# Unlock achievement
	if steam_manager.unlock_achievement(achievement_id):
		print("[SteamAchievements] Unlocked: %s" % achievement_name)
		_on_achievement_unlocked(achievement_key)
	else:
		push_error("[SteamAchievements] Failed to unlock achievement: %s" % achievement_key)


func _on_achievement_unlocked(achievement_key: String) -> void:
	"""Called when an achievement is successfully unlocked."""
	var achievement_data = ACHIEVEMENTS[achievement_key]
	
	# Show UI notification (implement based on your game)
	print("[Achievement Unlocked] %s: %s" % [achievement_data["name"], achievement_data["description"]])
	
	# You could emit a signal here to show a popup:
	# achievement_unlocked.emit(achievement_data)
	
	# Or play a sound effect:
	# AudioRecorder.play_sound("achievement_unlock")


# ============================================================================
# GAME EVENT HANDLERS
# ============================================================================
# These methods connect to your game systems and trigger achievements

func _on_creature_defeated() -> void:
	"""Called when the first creature is defeated."""
	unlock_achievement("DEFEAT_FIRST_ENEMY")


func _on_boss_defeated() -> void:
	"""Called when a boss is defeated."""
	unlock_achievement("DEFEAT_BOSS")


func _on_room_entered(room_id: int) -> void:
	"""Called when entering a new room."""
	if room_id == 0:  # First room
		unlock_achievement("EXPLORE_FIRST_ROOM")


func _on_level_completed(level_number: int, time_taken: float, damage_taken: int) -> void:
	"""Called when a level is completed."""
	# Speedrun achievement (5 minutes = 300 seconds)
	if time_taken < 300.0:
		unlock_achievement("SPEEDRUN_LEVEL")
	
	# Perfect level (no damage taken)
	if damage_taken == 0:
		unlock_achievement("PERFECT_LEVEL")


func _on_minor_orb_collected() -> void:
	"""Called when collecting a minor orb."""
	unlock_achievement("COLLECT_ORB_MINOR")


func _on_player_level_changed(new_level: int) -> void:
	"""Called when player level increases."""
	if new_level == 10:
		unlock_achievement("REACH_LEVEL_10")
	elif new_level == 50:
		unlock_achievement("REACH_LEVEL_50")


# ============================================================================
# STAT TRACKING METHODS
# ============================================================================
# Use these to track game statistics (kills, deaths, playtime, etc.)

func increment_stat(stat_name: String, amount: int = 1) -> void:
	"""
	Increment a statistic by a certain amount.
	
	Args:
		stat_name: The statistic name
		amount: Amount to increment by
	"""
	if not steam_manager or not steam_manager.is_steam_initialized:
		return
	
	var current_value = steam_manager.get_statistic(stat_name)
	steam_manager.set_statistic(stat_name, current_value + amount)


func set_stat(stat_name: String, value: int) -> void:
	"""
	Set a statistic to a specific value.
	
	Args:
		stat_name: The statistic name
		value: The value to set
	"""
	if not steam_manager or not steam_manager.is_steam_initialized:
		return
	
	steam_manager.set_statistic(stat_name, value)


func get_stat(stat_name: String) -> int:
	"""
	Get a statistic value.
	
	Args:
		stat_name: The statistic name
	
	Returns:
		The statistic value
	"""
	if not steam_manager or not steam_manager.is_steam_initialized:
		return 0
	
	return steam_manager.get_statistic(stat_name)


# ============================================================================
# HELPER METHODS
# ============================================================================

func get_achievement_info(achievement_key: String) -> Dictionary:
	"""
	Get information about an achievement.
	
	Args:
		achievement_key: Key from ACHIEVEMENTS dict
	
	Returns:
		Achievement data dictionary
	"""
	if achievement_key in ACHIEVEMENTS:
		return ACHIEVEMENTS[achievement_key].duplicate()
	return {}


func is_achievement_unlocked(achievement_key: String) -> bool:
	"""
	Check if an achievement is unlocked.
	
	Args:
		achievement_key: Key from ACHIEVEMENTS dict
	
	Returns:
		true if unlocked, false otherwise
	"""
	if achievement_key not in ACHIEVEMENTS:
		return false
	
	if not steam_manager or not steam_manager.is_steam_initialized:
		return false
	
	var achievement_id = ACHIEVEMENTS[achievement_key]["id"]
	return steam_manager.is_achievement_unlocked(achievement_id)


func get_all_achievements() -> Array:
	"""
	Get all achievements and their unlock status.
	
	Returns:
		Array of achievement dictionaries with unlock status
	"""
	var result = []
	
	for key in ACHIEVEMENTS.keys():
		var achievement = ACHIEVEMENTS[key].duplicate()
		achievement["unlocked"] = is_achievement_unlocked(key)
		result.append(achievement)
	
	return result


func print_all_achievements() -> void:
	"""Debug: Print all achievements and their status."""
	print("\n=== All Achievements ===")
	
	for achievement in get_all_achievements():
		var status = "✓" if achievement["unlocked"] else "✗"
		print("  [%s] %s - %s" % [status, achievement["name"], achievement["description"]])
	
	print("========================\n")
