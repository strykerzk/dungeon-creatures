class_name FileUtils
extends RefCounted

static func load_resources_from_folder(folder_path: String) -> Array:
	var loaded_resources: Array = []
	var dir = DirAccess.open(folder_path)
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if not dir.current_is_dir():
				# CRITICAL EXPORT FIX: 
				# When Godot exports a game, it often adds ".remap" to the end of text-based resource files.
				# We must strip it out, otherwise load() will fail in your final built game!
				var clean_name = file_name.replace(".remap", "")
				
				# Check if it's a Godot resource file
				if clean_name.ends_with(".tres") or clean_name.ends_with(".res"):
					var full_path = folder_path + "/" + clean_name
					var resource = load(full_path)
					if resource:
						loaded_resources.append(resource)
			
			file_name = dir.get_next()
	else:
		push_error("Failed to open folder path: " + folder_path)
		
	return loaded_resources
