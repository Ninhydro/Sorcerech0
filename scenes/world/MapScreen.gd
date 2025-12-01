extends CanvasLayer

@onready var map_container = $MapContainer
@onready var map_texture = $MapContainer/MapTexture
@onready var player_container = $PlayerContainer
@onready var player_icon = $PlayerContainer/PlayerIcon
@onready var icons_layer =$PlayerContainer/IconsLayer 

var quest_icons = {}

func _ready():
	hide()
	setup_player_icon()
	setup_map_scaling()

func setup_map_scaling():
	# Scale the entire map container to fit the screen
	var screen_size = Vector2(320, 180)  
	var map_size = Vector2(1280, 720)
	
	# Calculate scale factor to fit map to screen
	#var scale_factor = min(screen_size.x / map_size.x, screen_size.y / map_size.y)
	#map_container.scale = Vector2(scale_factor, scale_factor)
	
	# Center the map container on screen
	#map_container.position = (screen_size - (map_size * scale_factor)) / 2
	
	var scale_factor = 1  # Experiment with this value
	
	map_container.scale = Vector2(scale_factor, scale_factor)
	map_container.position = Vector2.ZERO
	
	print("Map scaled by: ", scale_factor)
	print("Map container position: ", map_container.position)
	
func setup_player_icon():
	var player_scale_factor = 0.25  # Player icon scale
	player_container.scale = Vector2(player_scale_factor, player_scale_factor)
	player_container.size = Vector2(320, 180)
	player_container.position = Vector2.ZERO
	
	#player_icon.modulate = Color.RED
	player_icon.scale = Vector2(2.0, 2.0)
	
	if player_icon is TextureRect:
		player_icon.custom_minimum_size = Vector2(20, 20)
		player_icon.size = Vector2(20, 20)

func _input(event):
	if event.is_action_pressed("map"):
		if visible:
			hide()
			get_tree().paused = false
		else:
			show_map()
			get_tree().paused = true
		get_viewport().set_input_as_handled()
	

func show_map():
	print("=== SHOW MAP DEBUG ===")

	
	# Get the master map
	var master_texture = Cartographer.get_master_map_texture()
	if master_texture:
		map_texture.texture = master_texture
	
	# Update player position
	update_player_icon()
	
	update_quest_markers()
	
	show()


func update_quest_markers():
	# Clear existing quest icons (or update them)
	clear_quest_icons()
	
	# Create icons for each quest marker
	for quest_name in Global.quest_markers:
		var world_pos = Global.quest_markers[quest_name]
		var map_pos = world_to_map_position(world_pos)
		create_quest_icon(quest_name, map_pos)

func create_quest_icon(quest_name: String, map_position: Vector2):
	# Create a new TextureRect for the quest icon
	var quest_icon = TextureRect.new()
	quest_icon.name = "QuestIcon_" + quest_name
	quest_icon.texture = load("res://assets_image/Background/Map/Quest_icon.png")  
	quest_icon.modulate = Color.YELLOW  
	quest_icon.scale = Vector2(0.5, 0.5)  # Adjust size as needed
	quest_icon.position = map_position
	
	# Center the icon on the position
	if quest_icon.texture:
		var icon_size = quest_icon.texture.get_size() * quest_icon.scale
		quest_icon.position -= icon_size / 2
	
	icons_layer.add_child(quest_icon)
	quest_icons[quest_name] = quest_icon
	
	print("Created quest icon for: ", quest_name, " at ", map_position)

func clear_quest_icons():
	# Remove all quest icons
	for quest_name in quest_icons:
		var icon = quest_icons[quest_name]
		if is_instance_valid(icon):
			icon.queue_free()
	quest_icons.clear()
	
func update_player_icon():
	print("--- UPDATE PLAYER ICON DEBUG ---")
	

	if Global.tracking_paused and Global.should_update_before_pause:
		var map_pos = world_to_map_position(Global.last_known_player_position)
		var offset = Vector2(0, -10)
		player_icon.position = map_pos + offset
		Global.should_update_before_pause = false
		print("Updated player icon to last known position before pause")
		return
	
	# Normal tracking
	if Global.playerBody and not Global.tracking_paused:
		var world_pos = Global.playerBody.global_position
		var map_pos = world_to_map_position(world_pos)
		var offset = Vector2(0, -10)
		player_icon.position = map_pos + offset

# Call this function to pause tracking (e.g., when entering a room)
func pause_tracking():
	Global.tracking_paused = true
	print("Map tracking PAUSED")

# Call this function to resume tracking (e.g., when leaving a room)
func resume_tracking():
	Global.tracking_paused = false
	print("Map tracking RESUMED")
	update_player_icon()  # Update to current position
	

func world_to_map_position(world_pos: Vector2) -> Vector2:
	var world_bounds_min = Vector2(-7888, -4016)
	var world_bounds_max = Vector2(10288, 6208)
	var map_size = Vector2(1280, 720)
	
	var normalized_x = inverse_lerp(world_bounds_min.x, world_bounds_max.x, world_pos.x)
	var normalized_y = inverse_lerp(world_bounds_min.y, world_bounds_max.y, world_pos.y)
	
	normalized_x = clamp(normalized_x, 0.0, 1.0)
	normalized_y = clamp(normalized_y, 0.0, 1.0)
	
	return Vector2(
		normalized_x * map_size.x,
		normalized_y * map_size.y
	)

func test_player_icon_visibility():
	print("=== DEBUG1 TEST ===")
	player_icon.position = Vector2(100, 100)
	print("Player icon forced to (100, 100)")
