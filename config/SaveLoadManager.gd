extends Node

const SAVE_DIR = "user://saves/"
#Later steam cloud:
#const SAVE_DIR = "user://SteamCloud/saves/"
const AUTOSAVE_SLOT_NAME = "autosave"
const MANUAL_SAVE_SLOT_PREFIX = "manual_save_"
const NUM_MANUAL_SAVE_SLOTS = 3

func _ready():
	# Make sure this creates the directory correctly.
	var dir = DirAccess.open("user://")
	
	if !dir.dir_exists("SteamCloud/saves"):
		dir.make_dir_recursive("SteamCloud/saves")
		print("SaveLoadManager: Created 'user://SteamCloud/saves/' directory.")
	else:
		print("SaveLoadManager: 'user://SteamCloud/saves/' directory already exists.")
	
	#Later steam cloud:
	#if !dir.dir_exists("saves"):
	#	dir.make_dir("saves")
	#	print("SaveLoadManager: Created 'user://saves/' directory.")
	#else:
	#	print("SaveLoadManager: 'user://saves/' directory already exists.")

func _get_save_file_path(slot_name: String) -> String:
	var actual_slot_name = slot_name if not slot_name.is_empty() else AUTOSAVE_SLOT_NAME
	return SAVE_DIR + actual_slot_name + ".cfg"  # Change from .json to .cfg

func save_game(player_node: Player, slot_name: String = "") -> bool:
	var path = _get_save_file_path(slot_name)
	
	print("SaveLoadManager: Attempting to save to path: ", path)

	Global.saving = true
	
	var config = ConfigFile.new()
	
	var scene_path_to_save = Global.current_scene_path
	
	if scene_path_to_save.is_empty() or not ResourceLoader.exists(scene_path_to_save, "PackedScene"):
		printerr("SaveLoadManager: ERROR: Global.current_scene_path '", scene_path_to_save, "' is invalid or empty during save.")
		printerr("SaveLoadManager: Cannot save game with an invalid scene path.")
		return false

	# Store all save data in ConfigFile sections
	config.set_value("scene", "current_scene_path", scene_path_to_save)
	
	# Store player data
	var player_data = player_node.get_save_data()
	for key in player_data:
		config.set_value("player", key, player_data[key])
	
	# Store global game state
	var global_data = Global.get_save_data()
	for key in global_data:
		config.set_value("global", key, global_data[key])
	
	config.set_value("metadata", "timestamp", Time.get_datetime_string_from_system())
	
	
	# Save the config file
	var error = config.save(path)
	if error == OK:
		print("Game saved successfully to: ", path)
		return true
	else:
		printerr("SaveLoadManager: Failed to save game to '", path, "'. Error: ", error)
		return false

func get_save_slot_info(slot_name: String = "") -> Dictionary:
	var path = _get_save_file_path(slot_name)
	var file_exists = FileAccess.file_exists(path)
	
	if not file_exists:
		print("SaveLoadManager: get_save_slot_info: No file found at '", path, "'.")
		return {}

	var config = ConfigFile.new()
	var error = config.load(path)
	
	if error != OK:
		printerr("SaveLoadManager: get_save_slot_info: Failed to load file '", path, "'. Error: ", error)
		return {}
	
	# Convert ConfigFile back to dictionary for compatibility
	var save_data = {}
	
	var timestamp = config.get_value("metadata", "timestamp", "No timestamp saved")
	
	var current_scene_path = config.get_value("global", "current_scene_path", "")

	save_data = {
		"timestamp": timestamp,
		"current_scene_path": current_scene_path,
		"global": {}
	}
	
	for key in config.get_section_keys("global"):
		save_data["global"][key] = config.get_value("global", key)
	
	print("SaveLoadManager: Loaded save slot info from '", path, "'")
	
	# Get all sections and keys
	#for section in config.get_sections():
	#	save_data[section] = {}
	#	for key in config.get_section_keys(section):
	#		save_data[section][key] = config.get_value(section, key)
	
	return save_data

func any_save_exists() -> bool:
	var autosave_path = _get_save_file_path(AUTOSAVE_SLOT_NAME)
	
	if FileAccess.file_exists(autosave_path):
		return true
	
	for i in range(1, NUM_MANUAL_SAVE_SLOTS + 1):
		var manual_slot_path = _get_save_file_path(MANUAL_SAVE_SLOT_PREFIX + str(i))
		if FileAccess.file_exists(manual_slot_path):
			return true
			
	return false

func load_game(slot_name: String = "") -> Dictionary:
	var loaded_data = {}
	var file_path = _get_save_file_path(slot_name)
	
	if not FileAccess.file_exists(file_path):
		print("No save game found at: ", file_path)
		return loaded_data

	var config = ConfigFile.new()
	var error = config.load(file_path)
	
	if error != OK:
		print("Error loading game: Could not load file '", file_path, "'. Error: ", error)
		return loaded_data
	
	# Convert to dictionary for compatibility with existing code
	for section in config.get_sections():
		loaded_data[section] = {}
		for key in config.get_section_keys(section):
			loaded_data[section][key] = config.get_value(section, key)
	
	print("Game loaded successfully from: ", file_path)
	
	# Apply the loaded data to Global
	var global_state_data = loaded_data.get("global", {})
	Global.apply_load_data(global_state_data)
	
	Global.current_loaded_player_data = loaded_data.get("player", {})
	Global.current_scene_path = loaded_data.get("scene", {}).get("current_scene_path", "")
	
	return loaded_data

func delete_save_slot(slot_name: String = "") -> bool:
	var file_path = _get_save_file_path(slot_name)

	if FileAccess.file_exists(file_path):
		var dir = DirAccess.open(SAVE_DIR)
		if dir:
			dir.remove(file_path)
			print("Deleted save file: ", file_path)
			return true
		else:
			printerr("Error deleting save file: Could not open directory '", SAVE_DIR, "'.")
			return false
	else:
		print("No save file to delete at: ", file_path)
		return false
