# res://scripts/globals/Global.gd
extends Node

var version = 1.0
# Game State Variables
var gameStarted: bool = false
var sub_quest: Dictionary = {}
var autosave_timer: Timer = Timer.new()
var autosave_interval_seconds: float = 60.0

# Window Management
var last_window_size: Vector2i = Vector2i.ZERO
var last_window_position: Vector2i = Vector2i.ZERO
var resize_check_active: bool = true
var unpause_cooldown_timer: float = 0.0
var ignore_player_input_after_unpause: bool = false
const UNPAUSE_COOLDOWN_DURATION: float = 0.5

# UI State Variables
var is_dialog_open := false
var attacking := false
var is_cutscene_active := false


var highlight_shader: Shader
var highlight_materials: Array = []  # Track all created highlight materials
var camouflage_shader: Shader
var circle_shader: Shader

var snap_threshold: int = 50

func _ready():
	load_persistent_data()
	#reset_persistent()
	Dialogic.connect("dialog_started", Callable(self, "_on_dialog_started"))
	Dialogic.connect("dialog_ended", Callable(self, "_on_dialog_ended"))
	highlight_shader = load("res://shaders/highlight2.gdshader") #currently I think the highlight.gdshader is not used
	camouflage_shader = load("res://shaders/camouflage_alpha.gdshader")
	circle_shader = load("res://shaders/circle.gdshader")
	
	if highlight_shader:
		print("Global highlight shader loaded successfully")
	else:
		print("ERROR: Failed to load highlight shader")
		highlight_shader = _create_fallback_shader()
	

func _handle_window_change(size: Vector2i, position: Vector2i):
	var screen_size = DisplayServer.screen_get_size()
	var half_screen_width = screen_size.x / 2
	
	print("Global: Window changed - Size: ", size, " | Position: ", position)
	print("Global: Screen: ", screen_size, " | Half-width: ", half_screen_width)
	
	# Check if window is at screen edge (snapped)
	var at_left_edge = position.x < snap_threshold
	var at_right_edge = position.x > screen_size.x - size.x - snap_threshold
	
	# Check if window width is close to half-screen but not exact
	var width_close_to_half = abs(size.x - half_screen_width) < snap_threshold
	var wrong_size = size.x != half_screen_width
	
	# If window is at edge and close to half-screen but wrong size, fix it
	if (at_left_edge or at_right_edge) and width_close_to_half and wrong_size:
		print("Global: Snap detected! Forcing exact half-screen: ", Vector2i(half_screen_width, size.y))
		DisplayServer.window_set_size(Vector2i(half_screen_width, size.y))
		
func create_highlight_material() -> ShaderMaterial:
	var material = ShaderMaterial.new()
	material.shader = highlight_shader
	highlight_materials.append(material)
	return material

func create_camouflage_material() -> ShaderMaterial:
	var material = ShaderMaterial.new()
	material.shader = camouflage_shader
	return material

func create_circle_material() -> ShaderMaterial:
	var material = ShaderMaterial.new()
	material.shader = circle_shader
	return material

func cleanup_all_materials():
	print("Global: Cleaning up all shader materials")
	for material in highlight_materials:
		if material and is_instance_valid(material):
			material = null
	highlight_materials.clear()

func _create_fallback_shader() -> Shader:
	var shader = Shader.new()
	shader.code = """
	shader_type canvas_item;
	void fragment() {
		COLOR = texture(TEXTURE, UV);
	}
	"""
	return shader

func _exit_tree():
	cleanup_all_materials()

func cleanup_dialogic():
	if Engine.has_singleton("Dialogic"):
		var dlg = Dialogic
		dlg.end_all_dialogs()
		dlg.clear()
		
func _on_dialog_started():
	is_dialog_open = true

func _on_dialog_ended():
	is_dialog_open = false
	
var play_intro_cutscene := false
var playerBody: Player = null # This is the variable the ProfileScene is looking for
var selected_form_index: int


var current_form: String = "Normal" # Initialize with default value for the backing variable

# Declare the signal
# Signals
signal current_form_changed(new_form_id: String)
signal brightness_changed(new_brightness_value)

# Form management functions
func set_player_form(value: String):
	if current_form != value:
		current_form = value
		current_form_changed.emit(current_form)
		print("Global: Player form changed to: " + current_form)

func get_player_form() -> String:
	return current_form

# Player Stats
var health: int = 60
var health_max: int = 60
var health_min: int = 0
var playerAlive: bool = true
var playerDamageZone: Area2D
var playerDamageAmount: int
var playerHitbox: Area2D

# Player Abilities
var telekinesis_mode := false
var teleporting := false
var dashing := false
var camouflage := false
var time_freeze := false

# Save/Load State
var near_save := false
var saving := false
var loading := false

var enemyADamageZone: Area2D
var enemyADamageAmount: int
var enemyAdealing: bool
var enemyAknockback := Vector2.ZERO

var tracking_paused = false

var kills: int = 0 # Initialize kills
var affinity: int = 0 # Initialize affinity negative magus, positive cyber
var player_status: String = "Neutral" 

func increment_kills() -> void:
	if timeline >= 8 and timeline < 9:
		return  # Don't increment kills during timeline 8-9
	kills += 1
	print("Kills increased to: ", kills)
	
var active_quests := []
var completed_quests := []
var dialog_timeline := ""
var dialog_current_index := 0
var dialogic_variables: Dictionary = {}

# Graphics Settings
var fullscreen_on := false
var vsync_on := false
var brightness: float = 1.0
var pixel_smoothing := false
var fps_limit: int = 60
var resolution_index: int = 2 # Default to 1280x720

# Audio Settings
var master_vol: float = -10.0
var bgm_vol: float = -10.0
var sfx_vol: float = -10.0
var voice_vol: float = -10.0

# Available display resolutions
var base_resolution = Vector2(320, 180)
var available_resolutions = [
	Vector2i(640, 360),
	Vector2i(960, 540),
	Vector2i(1280, 720),
	Vector2i(1920, 1080)
]



var current_scene_path: String = "" 

var current_loaded_player_data: Dictionary = {}
var current_game_state_data: Dictionary = {}

var cutscene_name: String = ""
var cutscene_playback_position: float = 0.0

#signal brightness_changed(new_brightness_value)

var player_position_before_dialog: Vector2 = Vector2.ZERO # Use Vector2 for position
var scene_path_before_dialog: String = ""


var cutscene_finished1 = false

#var ignore_player_input_after_unpause: bool = false
#var unpause_cooldown_timer: float = 0.0
#const UNPAUSE_COOLDOWN_DURATION: float = 0.5  # 100ms cooldown

var global_time_scale: float = 1.0
func slow_time():
	global_time_scale = 0.5  #change this for time stop/slow

func normal_time():
	global_time_scale = 1.0  # 100% normal speed
	

#Timeline
var timeline = 0 
#0 prologue cutscene, after done change to 1, 
#1 tutorial mode, to house (block until maya house)
#2 minigame mode, block until house and guide to minigame
#3 after minigame expand to town, starting chapter part 1 but stop until town, see dialog npc new aerendale
#4 expand to tromarvelia & exactlyion, start part 1, see dialog npc tromarvelia & exactlyion
#Quest 2x: find out Tromarvelia & Exactlyion
#5 after unlock both form go to part 1 climax, change npc dialog about war
#Quest 1x: go back to New Aerendale
#6-6.2 start part 2, change npc dialog for part 2

#Quest 1x: Talk back at junkyard
#6.5
#Quest 2x: Explore Tromarvelia & Exactlyion
#7 decision, check unlocked ultimate form, checkpoint go back from restart
#Quest 1x: make decision
#8 ending timeline route, look at route status decision, change npc dialog depends on route
#Quest 1x: Ending Magus, Cyber, Genocide, True/Pacifist
#9 restart timeline if not true or pacifist
#10 Epilogue mode (after true end or pacifist end) final change on npc dialog


var magus_form = false
var cyber_form = false
var ult_magus_form = false
var ult_cyber_form = false
var route_status = "" # "", "Genocide", "Magus", "Cyber","True"(normal), "Pacifist"
#(Nataly always fight Maya)  on magus & cyber routes, with the optional nora & valentina fight
var first_boss_dead = false 
var alyra_dead = false 
#false means alyra alive so this is true normal route -> lux dead, zach king & different dialog overall
#true means alyra is dead so this contribute true pacifist route -> lux alive, varek king & different dialog overall
var gawr_dead = false
#false -> it will give extra scene on nora sealing gawr  
#		on cyber route gawr will help king fight us (can be varek/zach) (no dialog change)
# 		contribute pacifist end  
#true -> unable to go to pacifist end, no extra scene
var nora_dead = false
#false ->  if gawr_dead = false -> save nora on sealing gawr scene
#								on magus route help fight valentina, if valentina die then nora help with buff? 
#								on cyber fight nora
#								contribute pacifist end
#false ->  if gawr_dead = true -> gawr dead, but nora is still alive somewhere
#								on magus route fight valentina alone 
#								on cyber fight nora
#true ->  if gawr_dead = false -> cannot save nora on sealing gawr scene
#								on magus route fight valentina alone 
#								on cyber route no fight since nora is dead
var replica_fini_dead = false
#false -> it will give extra scene on saving valentina from fini attack 
#		on magus route fini will help sterling fight us  (no dialog change)
# 		contribute pacifist end  
#true -> unable to go to pacifist end, no extra scene
var valentina_dead = false
#false ->  if replica_fini_dead = false -> save valentina from fini
#								on cyber route help fight nora, if nora die then valentina help with buff? 
#								on magus fight valentina
#								contribute pacifist end
#false ->  if replica_fini_dead = true -> fini dead, but valentina is still alive somewhere
#								on cyber route fight nora alone 
#								on magus fight valentina
#true ->  if replica_fini_dead = false -> cannot save valentina from fini
#								on cyber route fight nora alone 
#								on magus route no fight since valentina is dead 
#
var teleport_first = 0.0
var teleport_last = 0.0
var first_tromarvelia = false
var first_exactlyion = false
var meet_nora_one = false
var meet_valentina_one = false

var exactlyion_two = false
var tromarvelia_two = false
var meet_replica = false
var meet_gawr = false
var after_battle_replica = false
var after_battle_gawr = false


#Some of this need to be persistent save for achievement
var ending_magus = false
var ending_cyber = false
var ending_genocide = false
var ending_true = false
var ending_pacifist = false
var game_cleared = false

# Player tracking
var player: Player = null
var current_area: String = ""

var killing = false

var last_known_player_position: Vector2 = Vector2.ZERO
var should_update_before_pause: bool = false

# In Global.gd
var quest_markers = {}  # Stores quest marker positions: { "quest_name": Vector2(position) }

var minigame_nora_completed = false
var nora_station_1_completed: bool = false  # Green station
var nora_station_2_completed: bool = false  # Purple station  
var nora_station_3_completed: bool = false  # Gold station

var minigame_valentina_completed = false

var explode_door = false
var cannon_goal_door_destroyed = false
var final_puzzle_door = false

var is_boss_battle
var gawr_failed_route_used


# Function to add/update quest markers
func add_quest_marker(quest_name: String, world_position: Vector2):
	quest_markers[quest_name] = world_position
	
	if not active_quests.has(quest_name):
		active_quests.append(quest_name)
		print("Added quest to active_quests: ", quest_name)
		
	print("Added quest marker: ", quest_name, " at ", world_position)

# Function to remove quest markers
func remove_quest_marker(quest_name: String):
	if quest_markers.erase(quest_name):
		# Remove quest name from active_quests
		active_quests.erase(quest_name)
		
		# Add quest name to completed_quests for tracking
		if not completed_quests.has(quest_name):
			completed_quests.append(quest_name)
			print("Added quest to completed_quests: ", quest_name)
		
		print("Removed quest marker: ", quest_name)

# Function to update quest marker position
func update_quest_marker(quest_name: String, new_world_position: Vector2):
	if quest_markers.has(quest_name):
		quest_markers[quest_name] = new_world_position
		print("Updated quest marker: ", quest_name, " to ", new_world_position)

# Function to complete a quest (removes marker and updates arrays)
func complete_quest(quest_name: String):
	remove_quest_marker(quest_name)
	print("Completed quest: ", quest_name)

# Function to get active quest names for UI
func get_active_quest_names() -> Array:
	return active_quests.duplicate()

# Function to get completed quest names for UI
func get_completed_quest_names() -> Array:
	return completed_quests.duplicate()

# Function to check if a quest is active
func is_quest_active(quest_name: String) -> bool:
	return active_quests.has(quest_name)

# Function to check if a quest is completed
func is_quest_completed(quest_name: String) -> bool:
	return completed_quests.has(quest_name)
	

# Player registration function
func register_player(player_node: Player) -> void:
	player = player_node
	print("Global: Player registered")

# Area management functions
func set_current_area(area_name: String) -> void:
	if current_area != area_name:
		current_area = area_name
		print("Global: Current area changed to: ", area_name)

func get_current_area() -> String:
	return current_area

func get_player() -> Player:
	return player

func get_player_camera() -> Camera2D:
	if player and player.has_node("CameraPivot/Camera2D"):
		return player.get_node("CameraPivot/Camera2D")
	return null

# Map and Quest System
#var quest_markers: Dictionary = {}
var revealed_chunks: Dictionary = {}
var player_has_quill := false
var map_screen: CanvasLayer = null
var map_visible := false

# Map texture update function
func set_map_texture(texture: Texture2D):
	if map_screen and map_screen.has_method("update_map_texture"):
		map_screen.update_map_texture(texture)

#var health: int = 100
#var health_max: int = 100
#var health_min: int = 0
var health_regeneration_rate: float = 0.0  # Health per second (default: 0.5 = 1 health every 2 seconds)
var health_regeneration_timer: float = 0.0
var health_regeneration_active: bool = true  # Can be toggled on/off
var player_is_moving: bool = false  # Add this line
#var playerAlive: bool = true

# Add these functions in the script (I suggest adding them after the health variables)

# Health regeneration functions

func set_player_moving(is_moving: bool) -> void:
	"""Call this from Player script when player starts/stops moving"""
	player_is_moving = is_moving
	
func is_player_moving() -> bool:
	"""Check if player is currently moving"""
	return player_is_moving
	
func enable_health_regeneration() -> void:
	"""Enable health regeneration"""
	health_regeneration_active = true
	print("Health regeneration enabled")

func disable_health_regeneration() -> void:
	"""Disable health regeneration"""
	health_regeneration_active = false
	print("Health regeneration disabled")

func reset_health_regeneration() -> void:
	"""Reset health regeneration timer"""
	health_regeneration_timer = 0.0

func regenerate_health(delta: float) -> void:
	"""Regenerate health based on time passed - ONLY when player is NOT moving"""
	if not health_regeneration_active or not playerAlive:
		return
	
	if health >= health_max:
		return  # Already at max health
	
	# Only regenerate if player is NOT moving
	if player_is_moving:
		return  # Player is moving, don't regenerate
	
	health_regeneration_timer += delta
	
	# Calculate how much health to add
	var health_to_add = health_regeneration_rate * health_regeneration_timer
	
	if health_to_add >= 1.0:  # Add at least 1 health point
		var int_health_to_add = int(health_to_add)
		health = min(health + int_health_to_add, health_max)
		
		# Keep the fractional part for next time
		health_regeneration_timer -= int_health_to_add / health_regeneration_rate
		
		if player and player.has_signal("health_changed"):
			player.health_changed.emit(health, health_max)
		print("Regenerated health: ", health, "/", health_max)
		
func _init():
	# Initialize essential settings only
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	master_vol = 0.0 # Override default for master volume

func _process(delta):
	if Input.is_action_just_pressed("debug1"):  # Assign a key like F1
		print("timeline: ", Global.timeline)
		print("route status: ", Global.route_status)
		print("kills: ", Global.kills)
		print("alyra_dead: ", Global.alyra_dead)
		print("gawr_dead: ", Global.gawr_dead)
		print("nora_dead: ", Global.nora_dead)
		print("replica_fini_dead: ", Global.replica_fini_dead)
		print("valentina_dead: ", Global.valentina_dead)
	
	# Only proceed if the "no" action is pressed AND a timeline is currently active

	if Input.is_action_just_pressed("no") and Dialogic.current_timeline != null:
		if Dialogic.Text.is_textbox_visible():
			Dialogic.paused = true
			Dialogic.Text.hide_textbox()
		else:
			Dialogic.Text.show_textbox()
			Dialogic.paused = false
			# Wait a very short moment before allowing another input
			await get_tree().create_timer(0.05).timeout
		
		
	regenerate_health(delta)
	
		

		#Global.timeline = 8
	#Global.timeline == 8 and Global.route_status == "Cyber"
		#print("persistent_microchips ",persistent_microchips)
		#print("persistent_magic_stones ",persistent_magic_stones)
		#print("persistent_video_tapes ",persistent_video_tapes)
	#	print("timeline ",timeline)
	#	Global.killing =  !Global.killing
	#	print(Global.killing)
	#	print("Player World Position: ", global_position)
	# Handle unpause cooldown timer
	if unpause_cooldown_timer > 0:
		unpause_cooldown_timer -= delta
		if unpause_cooldown_timer <= 0:
			ignore_player_input_after_unpause = false
			unpause_cooldown_timer = 0.0
			print("Global: Input enabled after cooldown")
	
	# Handle window resizing if not in fullscreen
	if not resize_check_active or fullscreen_on:
		return
	
	var current_size = DisplayServer.window_get_size()
	var current_position = DisplayServer.window_get_position()
	
	if current_size != last_window_size or current_position != last_window_position:
		_handle_window_change(current_size, current_position)
		last_window_size = current_size
		last_window_position = current_position
	
func start_unpause_cooldown():
	ignore_player_input_after_unpause = true
	unpause_cooldown_timer = UNPAUSE_COOLDOWN_DURATION
	print("Global: Unpause cooldown started for ", UNPAUSE_COOLDOWN_DURATION, " seconds")
	
func set_current_game_scene_path(path: String):
	current_scene_path = path
	print("Global: Current game scene path set to: " + current_scene_path)

func get_save_data() -> Dictionary:
	
	var data = {
		"gameStarted": gameStarted,
		"current_scene_path": current_scene_path,
		"play_intro_cutscene": play_intro_cutscene,
		"cutscene_finished1": cutscene_finished1,
		"is_cutscene_active": is_cutscene_active, 
		"cutscene_name": cutscene_name,
		"cutscene_playback_position": cutscene_playback_position,
		
		"fullscreen_on": fullscreen_on,
		"vsync_on": vsync_on,
		"brightness": brightness,
		"fps_limit": fps_limit,
		"master_vol": master_vol,
		"bgm_vol": bgm_vol,
		"sfx_vol": sfx_vol,
		"voice_vol": voice_vol,
		"resolution_index": resolution_index,

		"selected_form_index": selected_form_index,
		"current_form": get_player_form(), # Use the getter for saving
		"playerAlive": playerAlive,
		"health_max": health_max,
		"health_regeneration_rate": health_regeneration_rate,
		"health_regeneration_active": health_regeneration_active,

		"kills": kills, # Save kills
		"affinity": affinity, # Save affinity
		"player_status": player_status, 
		
		"sub_quest": sub_quest,
		"active_quests": active_quests,
		"completed_quests": completed_quests, #sub & main quest
		"timeline": timeline,
		"magus_form":magus_form,
		"cyber_form":cyber_form,
		"ult_magus_form":ult_magus_form,
		"ult_cyber_form":ult_cyber_form,
		"route_status":route_status,
		"first_boss_dead":first_boss_dead,
		"alyra_dead":alyra_dead,
		"gawr_dead":gawr_dead,
		"nora_dead":nora_dead,
		"replica_fini_dead":replica_fini_dead,
		"valentina_dead":valentina_dead,
		
		"first_tromarvelia":first_tromarvelia,
		"first_exactlyion":first_exactlyion,
		"meet_nora_one":meet_nora_one,
		"meet_valentina_one":meet_valentina_one,
		
		"exactlyion_two":exactlyion_two,
		"tromarvelia_two":tromarvelia_two,
		"meet_replica":meet_replica,
		"meet_gawr":meet_gawr,
		"after_battle_replica":after_battle_replica,
		"after_battle_gawr":after_battle_gawr,
		
		"ending_magus":ending_magus,
		"ending_cyber":ending_cyber,
		"ending_genocide":ending_genocide,
		"ending_true":ending_true,
		"ending_pacifist":ending_pacifist,
		"game_cleared":game_cleared,
		
		"revealed_chunks": revealed_chunks,
		"quest_markers": _serialize_quest_markers(),
		"minigame_nora_completed": minigame_nora_completed,
		"minigame_valentina_completed": minigame_valentina_completed,
		"explode_door": explode_door,
		"cannon_goal_door_destroyed": cannon_goal_door_destroyed,
		"final_puzzle_door": final_puzzle_door,
		
		
	}
	return data
		
func apply_load_data(data: Dictionary):
	current_scene_path = data.get("current_scene_path", "")
	gameStarted = data.get("gameStarted", false)
	play_intro_cutscene = data.get("play_intro_cutscene", false)
	cutscene_finished1 = data.get("cutscene_finished1", false)
	is_cutscene_active = data.get("is_cutscene_active", false)
	cutscene_name = data.get("cutscene_name", "")
	cutscene_playback_position = data.get("cutscene_playback_position", 0.0)
	
		
	fullscreen_on = data.get("fullscreen_on", false)
	vsync_on = data.get("vsync_on", false)
	brightness = data.get("brightness", 1.0)
	fps_limit = data.get("fps_limit", 60)
	master_vol = data.get("master_vol", -10.0)
	bgm_vol = data.get("bgm_vol", -10.0)
	sfx_vol = data.get("sfx_vol", -10.0)
	voice_vol = data.get("voice_vol", -10.0)
	resolution_index = data.get("resolution_index", 2) 

	
	selected_form_index = data.get("selected_form_index", 0)
	set_player_form(data.get("current_form", "Normal"))
	playerAlive = data.get("playerAlive", true)
	health_max = data.get("health_max", 60)
	health_regeneration_rate = data.get("health_regeneration_rate", 0.0)
	health_regeneration_active = data.get("health_regeneration_active", true)

	sub_quest = data.get("sub_quest", {})
	active_quests = data.get("active_quests", [])
	completed_quests = data.get("completed_quests", [])
	
	kills = data.get("kills", 0)
	affinity = data.get("affinity", 0)
	player_status = data.get("player_status", "Neutral")
		
	timeline = data.get("timeline", 0)
	magus_form = data.get("magus_form", false)
	cyber_form = data.get("cyber_form", false)
	ult_magus_form = data.get("ult_magus_form", false)
	ult_cyber_form = data.get("ult_cyber_form", false)
	route_status = data.get("route_status", "")
	first_boss_dead = data.get("first_boss_dead", false)
	alyra_dead = data.get("alyra_dead", false)
	gawr_dead = data.get("gawr_dead", false)
	nora_dead = data.get("nora_dead", false)
	replica_fini_dead = data.get("replica_fini_dead", false)
	valentina_dead = data.get("valentina_dead", false)

	
	first_tromarvelia = data.get("first_tromarvelia", false)
	first_exactlyion = data.get("first_exactlyion", false)
	meet_nora_one = data.get("meet_nora_one", false)
	meet_valentina_one = data.get("meet_valentina_one", false)
	
	exactlyion_two = data.get("exactlyion_two", false)
	tromarvelia_two = data.get("tromarvelia_two", false)
	meet_replica = data.get("meet_replica", false)
	meet_gawr = data.get("meet_gawr", false)
	after_battle_replica = data.get("after_battle_replica", false)
	after_battle_gawr = data.get("after_battle_gawr", false)

	ending_magus = data.get("ending_magus", false)
	ending_cyber = data.get("ending_cyber", false)
	ending_genocide = data.get("ending_genocide", false)
	ending_true = data.get("ending_true", false)
	ending_pacifist = data.get("ending_pacifist", false)
	game_cleared = data.get("game_cleared", false)

	revealed_chunks = data.get("revealed_chunks", {})
	
	_deserialize_quest_markers(data.get("quest_markers", {}))
	
	minigame_nora_completed = data.get("minigame_nora_completed", false)
	minigame_valentina_completed = data.get("minigame_valentina_completed", false)
	explode_door = data.get("explode_door", false)
	cannon_goal_door_destroyed = data.get("cannon_goal_door_destroyed", false)
	final_puzzle_door = data.get("final_puzzle_door", false)

	print("Global: Save data loaded successfully.")

func reset_to_defaults():
	print("Global: Resetting essential game state to defaults.")
	current_scene_path = ""
	current_loaded_player_data = {}
	current_game_state_data = {}
	gameStarted = false
	is_dialog_open = false
	attacking = false
	play_intro_cutscene = false
	selected_form_index = 0
	playerAlive = true
	health_max = 60
	health_regeneration_rate = 0.0
	health_regeneration_active = true
	# Reset player abilities
	telekinesis_mode = false
	teleporting = false
	dashing = false
	camouflage = false
	time_freeze = false
	# Reset settings to defaults
	fullscreen_on = false
	vsync_on = false
	brightness = 1.0
	fps_limit = 60
	master_vol = -10.0
	bgm_vol = -10.0
	sfx_vol = -10.0
	voice_vol = -10.0
	resolution_index = 2
	
	kills = 0 # Reset kills
	affinity = 0 # Reset affinity
	player_status = "Neutral" 
	# Reset the form using the setter
	set_player_form("Normal") 
	
	timeline = 0
	magus_form = false
	cyber_form = false
	ult_magus_form = false
	ult_cyber_form = false
	route_status = ""
	first_boss_dead = false
	alyra_dead = false
	gawr_dead = false
	nora_dead = false
	replica_fini_dead = false
	valentina_dead = false
	
	first_tromarvelia =  false
	first_exactlyion = false
	meet_nora_one = false
	meet_valentina_one = false

	exactlyion_two = false
	tromarvelia_two = false
	meet_replica = false
	meet_gawr = false
	after_battle_replica = false
	after_battle_gawr = false
	
	
	ending_magus = false
	ending_cyber = false
	ending_genocide = false
	ending_true = false
	ending_pacifist = false
	game_cleared = false

	sub_quest = {}
	active_quests = []
	completed_quests = []
	dialog_timeline = ""
	dialog_current_index = 0
	dialogic_variables = {}
	is_cutscene_active = false 
	
	revealed_chunks  = {}
	quest_markers = {}

	cutscene_name = ""
	cutscene_playback_position = 0.0
	cutscene_finished1 = false
	
	minigame_nora_completed = false
	minigame_valentina_completed = false
	explode_door = false
	cannon_goal_door_destroyed = false
	final_puzzle_door = false
	
# Helper functions for quest marker serialization
func _serialize_quest_markers() -> Dictionary:
	var serialized = {}
	for quest_name in quest_markers:
		var position = quest_markers[quest_name]
		# Convert Vector2 to serializable format
		serialized[quest_name] = {"x": position.x, "y": position.y}
	return serialized

func _deserialize_quest_markers(serialized_data: Dictionary):
	quest_markers = {}
	for quest_name in serialized_data:
		var pos_data = serialized_data[quest_name]
		var position = Vector2(pos_data["x"], pos_data["y"])
		quest_markers[quest_name] = position
	print("Loaded ", quest_markers.size(), " quest markers from save")
	
func apply_graphics_settings():
	
	# Fullscreen
	if fullscreen_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		# Hide borders in fullscreen
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		
		# Apply resolution for windowed mode
		var current_resolution = available_resolutions[resolution_index]
		
		# Get screen size to detect half-screen scenarios
		var screen_size = DisplayServer.screen_get_size()
		var half_screen_width = screen_size.x / 2
		
		print("applying displayyyyyyyyy")
		# If selected resolution is close to half-screen width, ensure it triggers Windows snap
		if abs(current_resolution.x - half_screen_width) <= 20:  # Within 20 pixels of half-screen
			# Set to slightly above half-screen to ensure Windows snap detection
			DisplayServer.window_set_size(Vector2i(half_screen_width + 10, current_resolution.y))
		else:
			DisplayServer.window_set_size(current_resolution)
		
		# Center window
		call_deferred("_center_window")
	
	# V-Sync
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync_on else DisplayServer.VSYNC_DISABLED)
	
	# Brightness
	brightness_changed.emit(brightness)
	
	# FPS Limit
	Engine.set_max_fps(fps_limit)
	
	print("Global: Applied graphics settings - Fullscreen=" + str(fullscreen_on))

func _center_window():
	var screen_size = DisplayServer.screen_get_size()
	var window_size = DisplayServer.window_get_size()
	var centered_position = (screen_size - window_size) / 2
	DisplayServer.window_set_position(centered_position)

func apply_audio_settings():
	var master_bus_idx = AudioServer.get_bus_index("Master")
	var bgm_bus_idx = AudioServer.get_bus_index("BGM")
	var sfx_bus_idx = AudioServer.get_bus_index("SFX")
	var voice_bus_idx = AudioServer.get_bus_index("Voice") 

	if master_bus_idx != -1:
		AudioServer.set_bus_volume_db(master_bus_idx, master_vol)
	if bgm_bus_idx != -1:
		AudioServer.set_bus_volume_db(bgm_bus_idx, bgm_vol)
	if sfx_bus_idx != -1:
		AudioServer.set_bus_volume_db(sfx_bus_idx, sfx_vol)
	if voice_bus_idx != -1: 
		AudioServer.set_bus_volume_db(voice_bus_idx, voice_vol)
	
	print("Global: Applied audio settings: Master=" + str(master_vol) + 
		  ", BGM=" + str(bgm_vol) + ", SFX=" + str(sfx_vol) + 
		  ", Voice=" + str(voice_vol))


func _on_autosave_timer_timeout():
	print("Autosave timer triggered!")
	var player_node = get_tree().get_first_node_in_group("player")
	if player_node:
		if Global.current_scene_path.is_empty():
			printerr("Autosave: Global.current_scene_path is empty! Cannot autosave reliably.")
			return
		SaveLoadManager.save_game(player_node, "")
		print("Game autosaved by timer.")
	else:
		print("No player node found for timer-based autosave!")
		

func cleanup_all_shader_materials():
	"""Global cleanup called during exit"""
	print("Global: Cleaning up all shader materials")
	if playerBody and is_instance_valid(playerBody):
		if playerBody.has_method("emergency_cleanup_shaders"):
			playerBody.emergency_cleanup_shaders()


var persistent_data_path: String = "user://persistent_data.cfg"  # Changed from .dat to .cfg
#Later steam cloud:
#var persistent_data_path: String = "user://SteamCloud/persistent_data.cfg"

# Individual persistent achievement variables
var persistent_ending_magus: bool = false
var persistent_ending_cyber: bool = false
var persistent_ending_genocide: bool = false
var persistent_ending_true: bool = false
var persistent_ending_pacifist: bool = false
var persistent_collected_all_microchips: bool = false
var persistent_collected_all_magic_stones: bool = false
var persistent_collected_all_video_tapes: bool = false
var persistent_saved_alyra: bool = false
var persistent_alyra_dead: bool = false
var persistent_saved_lux: bool = false
var persistent_saved_nora: bool = false
var persistent_saved_valentina: bool = false
var persistent_cleared_part_1: bool = false
var persistent_game_100_percent: bool = false


# Persistent collections
var persistent_microchips: int = 0
var persistent_magic_stones: int = 0
var persistent_video_tapes: int = 0

var persistent_video_tape_1_collected: bool = false
var persistent_video_tape_2_collected: bool = false
var persistent_video_tape_3_collected: bool = false

var persistent_microchip_ids: Array = []
var persistent_magic_stone_ids: Array = []

func save_persistent_data():
	var config = ConfigFile.new()
	
	# Store all persistent variables in organized sections
	config.set_value("achievements", "ending_magus", persistent_ending_magus)
	config.set_value("achievements", "ending_cyber", persistent_ending_cyber)
	config.set_value("achievements", "ending_genocide", persistent_ending_genocide)
	config.set_value("achievements", "ending_true", persistent_ending_true)
	config.set_value("achievements", "ending_pacifist", persistent_ending_pacifist)
	config.set_value("achievements", "collected_all_microchips", persistent_collected_all_microchips)
	config.set_value("achievements", "collected_all_magic_stones", persistent_collected_all_magic_stones)
	config.set_value("achievements", "collected_all_video_tapes", persistent_collected_all_video_tapes)
	config.set_value("achievements", "saved_alyra", persistent_saved_alyra)
	config.set_value("achievements", "alyra_dead", persistent_alyra_dead)
	config.set_value("achievements", "saved_lux", persistent_saved_lux)
	config.set_value("achievements", "saved_nora", persistent_saved_nora)
	config.set_value("achievements", "saved_valentina", persistent_saved_valentina)
	config.set_value("achievements", "cleared_part_1", persistent_cleared_part_1)
	config.set_value("achievements", "game_100_percent", persistent_game_100_percent)
	
	
	config.set_value("collections", "microchips", persistent_microchips)
	config.set_value("collections", "magic_stones", persistent_magic_stones)
	config.set_value("collections", "video_tapes", persistent_video_tapes)
	
	config.set_value("achievements", "video_tape_1_collected", persistent_video_tape_1_collected)
	config.set_value("achievements", "video_tape_2_collected", persistent_video_tape_2_collected)
	config.set_value("achievements", "video_tape_3_collected", persistent_video_tape_3_collected)
	
	config.set_value("collections", "microchip_ids", persistent_microchip_ids)
	config.set_value("collections", "magic_stone_ids", persistent_magic_stone_ids)

	config.set_value("metadata", "timestamp", Time.get_unix_time_from_system())
	config.set_value("metadata", "version", version)
	
	
	var error = config.save(persistent_data_path)
	if error == OK:
		print("Persistent data saved successfully")
	else:
		printerr("Failed to save persistent data: ", error)

func load_persistent_data():
	var config = ConfigFile.new()
	var error = config.load(persistent_data_path)
	
	if error == OK:
		# Load all persistent variables
		var file_version = config.get_value("metadata", "version", version)
		version = float(file_version)

		
		persistent_ending_magus = config.get_value("achievements", "ending_magus", false)
		persistent_ending_cyber = config.get_value("achievements", "ending_cyber", false)
		persistent_ending_genocide = config.get_value("achievements", "ending_genocide", false)
		persistent_ending_true = config.get_value("achievements", "ending_true", false)
		persistent_ending_pacifist = config.get_value("achievements", "ending_pacifist", false)
		persistent_collected_all_microchips = config.get_value("achievements", "collected_all_microchips", false)
		persistent_collected_all_magic_stones = config.get_value("achievements", "collected_all_magic_stones", false)
		persistent_collected_all_video_tapes = config.get_value("achievements", "collected_all_video_tapes", false)
		persistent_saved_alyra = config.get_value("achievements", "saved_alyra", false)
		persistent_alyra_dead = config.get_value("achievements", "alyra_dead", false)
		persistent_saved_lux = config.get_value("achievements", "saved_lux", false)
		persistent_saved_nora = config.get_value("achievements", "saved_nora", false)
		persistent_saved_valentina = config.get_value("achievements", "saved_valentina", false)
		persistent_cleared_part_1 = config.get_value("achievements", "cleared_part_1", false)
		persistent_game_100_percent = config.get_value("achievements", "game_100_percent", false)
		
		
		persistent_microchips = config.get_value("collections", "microchips", 0)
		persistent_magic_stones = config.get_value("collections", "magic_stones", 0)
		persistent_video_tapes = config.get_value("collections", "video_tapes", 0)

		persistent_video_tape_1_collected = config.get_value("achievements", "video_tape_1_collected", false)
		persistent_video_tape_2_collected = config.get_value("achievements", "video_tape_2_collected", false)
		persistent_video_tape_3_collected = config.get_value("achievements", "video_tape_3_collected", false)
		
		persistent_microchip_ids = config.get_value("collections", "microchip_ids", [])
		persistent_magic_stone_ids = config.get_value("collections", "magic_stone_ids", [])

		
		#if version < 1.1:
		#	print("Migrating persistent data from v1.0 → v1.1")

			# Add new fields introduced in patch 1.1
		#	persistent_special_collectable = false

			# bump version
		#	version = 1.1
		#	save_persistent_data()

		print("Persistent data loaded successfully")
	else:
		print("No persistent save file found, starting fresh")
		save_persistent_data()  # Create initial fil

func reset_persistent():
	persistent_ending_magus = false
	persistent_ending_cyber = false
	persistent_ending_genocide = false
	persistent_ending_true = false
	persistent_ending_pacifist = false
	persistent_collected_all_microchips = false
	persistent_collected_all_magic_stones = false
	persistent_collected_all_video_tapes = false
	persistent_saved_alyra = false
	persistent_alyra_dead = false
	persistent_saved_lux = false
	persistent_saved_nora = false
	persistent_saved_valentina = false
	persistent_cleared_part_1 = false
	persistent_game_100_percent = false


# Persistent collections
	# Collections
	persistent_microchips = 0
	persistent_magic_stones = 0
	persistent_video_tapes = 0


	persistent_video_tape_1_collected = false
	persistent_video_tape_2_collected = false
	persistent_video_tape_3_collected = false
	
	persistent_microchip_ids = []
	persistent_magic_stone_ids = []

	print("Persistent data RESET for testing.")
	save_persistent_data()
	
func check_collection_achievements():

	var total_video_tapes = 3
	var total_microchips = 10  
	var total_magic_stones = 10
	
	# Check and unlock achievements (FOR INTEGER COUNTERS)
	if persistent_video_tapes >= total_video_tapes and not persistent_collected_all_video_tapes:
		persistent_collected_all_video_tapes = true
		print("🎉 Achievement: Collected ALL video tapes! 🎉")
		
	if persistent_microchips >= total_microchips and not persistent_collected_all_microchips:
		persistent_collected_all_microchips = true
		print("🎉 Achievement: Collected ALL microchips! 🎉")
		
	if persistent_magic_stones >= total_magic_stones and not persistent_collected_all_magic_stones:
		persistent_collected_all_magic_stones = true
		print("🎉 Achievement: Collected ALL magic stones! 🎉")
	
	if (persistent_collected_all_video_tapes or 
		persistent_collected_all_microchips or 
		persistent_collected_all_magic_stones):
		save_persistent_data()
		
		
func check_100_percent_completion():
	if (persistent_ending_magus and
		persistent_ending_cyber and
		persistent_ending_genocide and
		persistent_ending_true and
		persistent_ending_pacifist and
		persistent_collected_all_microchips and
		persistent_collected_all_magic_stones and
		persistent_collected_all_video_tapes and
		persistent_saved_alyra and
		persistent_alyra_dead and
		persistent_saved_lux and
		persistent_saved_nora and
		persistent_saved_valentina and 
		persistent_cleared_part_1):
		
		if not persistent_game_100_percent:
			persistent_game_100_percent = true
			print("🎉 100% GAME COMPLETION! 🎉")
			save_persistent_data()
			
#When collectables ready put this:
#Global.persistent_microchips += 1
#Global.persistent_magic_stones += 1
#Global.persistent_video_tapes += 1
#Global.check_collection_achievements()
#Global.check_100_percent_completion()
#Global.save_persistent_data()

