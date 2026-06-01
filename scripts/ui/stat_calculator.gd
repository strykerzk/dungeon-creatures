extends Control

@onready var main_container: VBoxContainer = %MainContainer
@onready var creature_name: LineEdit = %CreatureName
@onready var status_label: Label = %StatusLabel
@onready var message_timer: Timer = %MessageTimer

@export var groups: Array = [] # [last_typed_string, container_name, line_edit, points_label]
@export var stats: Array[LineEdit] = []

func _ready() -> void:
	for container in main_container.get_children():
		if container.name == "Heading": continue
		
		if container.name == "Total":
			groups.append(container.get_node("Points"))
			continue
		
		var group: Array = ["", container.name]
		for child in container.get_children():
			if child.name == "Name" or child.name == "Total": continue
			if child.name == "LineEdit":
				child.connect("text_changed",on_line_edit_text_changed)
				stats.append(child)
			group.append(child)
		groups.append(group)

func on_line_edit_text_changed(new_text: String) -> void:
	if not new_text.is_valid_float(): return
	
	var active_group = get_active_group(new_text)
	if active_group.is_empty(): return
	
	if new_text == "":
		active_group[3].text = ""
	else:
		active_group[3].text = get_final_value(active_group[1], float(new_text))

func get_active_group(new_text: String) -> Array:
	for group in groups:
		if group is Label or group[2].text == group[0]: continue
		group[0] = group[2].text
		return group
	return []

func get_final_value(type: String, value: float) -> String:
	match type:
		"Health":
			return str(value / 10)
		"Speed":
			return str(value / 10)
		"Damage":
			return str(value * 2)
		"IQ":
			return str(value * 4)
		"Aggression":
			return str(value * 10)
		"Dexterity":
			return str(value * 20)
		"Precision":
			return str(value * 20)
		_:
			return "NO TYPE FOUND"

func _on_calculate_pressed() -> void:
	var total = calculate_total()
	groups[groups.size() - 1].text = str(total)

func calculate_total() -> float:
	var total: float = 0
	for group in groups:
		if group is Label: continue
		total += float(group[3].text)
	return total

func _on_create_pressed() -> void:
	if not check_if_stats_ready(): return
	
	if creature_name.text == "":
		show_message("Creature Name is Empty!", 3.0)
		return
	
	var total: float = calculate_total()
	if total < 100 or total > 110:
		show_message("Creature Is Not Balanced! (Total between 100 to 110)", 3.0)
		return
	
	var data: CreatureData = CreatureData.new()
	data.name = creature_name.text.to_lower()
	
	for group in groups:
		if group is Label: continue
		match group[1]:
			"Health":
				data.base_health = float(group[2].text)
			"Speed":
				data.speed = float(group[2].text)
			"Damage":
				data.damage = float(group[2].text)
			"IQ":
				data.IQ = int(group[2].text)
			"Aggression":
				data.aggression = float(group[2].text)
			"Dexterity":
				data.dexterity = float(group[2].text)
			"Precision":
				data.precision = float(group[2].text)
	
	var save_path: String = "res://resources/creature_data/" + creature_name.text.to_lower() + "_data.tres"
	var error = ResourceSaver.save(data, save_path)
	if error == OK:
		show_message("Data successfully created.")
	else:
		show_message("Failed to create file.")

func check_if_stats_ready() -> bool:
	var total_size:int = groups.size() - 1
	var count:int = 0
	for stat in stats:
		if stat.text != "": count += 1
	
	if count == total_size: return true
	return false

func show_message(text: String, duration: float = 0.0) -> void:
	status_label.text = text
	if duration > 0:
		message_timer.wait_time = duration
		message_timer.start()

func _on_message_timer_timeout() -> void:
	status_label.text = ""


func _on_quit_button_pressed() -> void:
	get_tree().quit()
