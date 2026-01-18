extends CharacterCutscene
class_name NoraNPC

@export var movement_speed: float = 50.0 * Global.global_time_scale
@export var minigame_stations: Array[NodePath] = []

# Control flags
@export var minigame_enabled: bool = false  # Set this to true AFTER intro dialogue
@export var allow_reset: bool = true  # Can be turned off if needed

@onready var sprite_2d = $Sprite2D
#@onready var animation_player = $AnimationPlayer
@onready var interaction_area = $InteractionArea

@onready var nora: Sprite2D = $Nora
@onready var alyra: Sprite2D = $Alyra
@onready var varek: Sprite2D = $Varek_soldier
@onready var marker1: Marker2D = $Marker2D
@onready var marker2: Marker2D = $Marker2D
@onready var cutscene_marker1: Marker2D = $CutsceneMarker1

var current_station_index: int = 0
var is_moving: bool = false
var target_position: Vector2
var current_goal: ColorObject.ColorType
var goals_completed: int = 0
var minigame_active: bool = false
var player_is_near: bool = false

var player_in_range = null

var station_goals = [
	ColorObject.ColorType.GREEN,
	ColorObject.ColorType.PURPLE, 
	ColorObject.ColorType.GOLD
]

signal minigame_started(goal_color, station_index)
signal minigame_completed(station_index, success)
signal nora_moved_to_station(station_index)

var stations_completed: Array[bool] = []  # Track which stations are completed locally

@export var final_position_marker: NodePath  # Path to a Marker2D for Nora's final po

@export var speech_bubble_scene: PackedScene  # Drag your SpeechBubble.tscn here
@export var bubble_y_offset: float = -80  # Adjust bubble position
@export var bubble_x_offset: float = 0

# Add these with other variables
var current_bubble = null
var bubble_timer: Timer
var instruction_timer: Timer
var final_position_bubble_texts: Array[String] = [
	"Ah you're back",
	"That Phina is really a special one", 
	"Please be quiet I'm busy with my spells",
	"The magic here is so vibrant today",
	"I wonder what color I should create next..."
]


func _ready():
	alyra.visible = false
	nora.visible = false
	varek.visible = false
	interaction_area.body_entered.connect(_on_player_entered)
	interaction_area.body_exited.connect(_on_player_exited)
	
	# Initialize stations completed array
	stations_completed.resize(minigame_stations.size())
	for i in range(stations_completed.size()):
		stations_completed[i] = false
	
	# CHECK GLOBAL COMPLETION FLAGS
	if Global.minigame_nora_completed:
		# Minigame already completed - disable everything
		#minigame_enabled = false
		#minigame_active = false
		#goals_completed = minigame_stations.size()
		
		# Set all stations as completed
		#for i in range(stations_completed.size()):
		#	stations_completed[i] = true
		
		# Move Nora to the final station position
		#if minigame_stations.size() > 0:
		#	var final_station = get_node(minigame_stations[minigame_stations.size() - 1])
		#	global_position = final_station.global_position
		move_to_final_position()
		start_final_position_bubbles()
		print("Nora: Minigame already completed (from Global flag) - disabled")
	else:
		# Check individual station completions from global flags
		check_individual_station_completions()
		
		# Find the first incomplete station
		var first_incomplete_station = find_first_incomplete_station()
		if first_incomplete_station != -1:
			goals_completed = first_incomplete_station
			move_to_station(first_incomplete_station)
			print("Nora: Resuming at station ", first_incomplete_station)
		else:
			# All stations completed but global flag not set (shouldn't happen normally)
			if minigame_stations.size() > 0:
				move_to_station(0)
			print("Nora: Starting minigame from beginning")


func _process(delta):
	if Global.meet_nora_one == false or Global.is_cutscene_active == true:
		sprite_2d.visible = false
	else:
		sprite_2d.visible = true
		
	if $AnimationPlayer:
		$AnimationPlayer.speed_scale = Global.global_time_scale

func check_individual_station_completions():
	# Update local completion array from global flags
	if Global.nora_station_1_completed and stations_completed.size() > 0:
		stations_completed[0] = true
		goals_completed = max(goals_completed, 1)
	
	if Global.nora_station_2_completed and stations_completed.size() > 1:
		stations_completed[1] = true
		goals_completed = max(goals_completed, 2)
	
	if Global.nora_station_3_completed and stations_completed.size() > 2:
		stations_completed[2] = true
		goals_completed = max(goals_completed, 3)
	
	print("Nora: Station completion status - ", stations_completed)

# Helper function to find first incomplete station
func find_first_incomplete_station() -> int:
	for i in range(stations_completed.size()):
		if not stations_completed[i]:
			return i
	return -1  # All stations completed
	
func _physics_process(delta):
	#print("player_is_near",player_is_near)
	#print("is_moving",is_moving)
	if is_moving:
		move_to_target(delta)
	
func move_to_target(delta):
	var direction = (target_position - global_position).normalized()
	var distance = global_position.distance_to(target_position)
	if distance > 5.0:
		velocity = direction * movement_speed
		move_and_slide()
		if animation_player:
			if direction.x != 0:
				sprite_2d.flip_h = direction.x < 0
			animation_player.play("walk")
	else:
		is_moving = false
		velocity = Vector2.ZERO
		global_position = target_position
		if animation_player:
			animation_player.play("idle")
		
		if not Global.minigame_nora_completed:
			setup_current_station()
			nora_moved_to_station.emit(current_station_index)
		else:
			print("Nora: Arrived at final position")
			
		#setup_current_station()
		#nora_moved_to_station.emit(current_station_index)

func move_to_station(station_index: int):
	if station_index >= minigame_stations.size():
		return
	stop_instruction_timer()
	current_station_index = station_index
	var station = get_node(minigame_stations[station_index])
	target_position = station.global_position
	is_moving = true
	current_goal = station_goals[station_index]
	player_is_near = false

func setup_current_station():
	print("Nora: Arrived at station ", current_station_index)
	print("Nora: Current goal: ", ColorObject.ColorType.keys()[current_goal])
	
	player_is_near = false
	# Check if this station is already completed
	var station_already_completed = false
	if stations_completed.size() > current_station_index:
		station_already_completed = stations_completed[current_station_index]
	
	if station_already_completed:
		print("Nora: This station is already completed!")
		stop_instruction_timer() 
	else:
		
		setup_station_objects()
	
	# Only auto-start if minigame is enabled AND station not completed
	if minigame_enabled and not station_already_completed:
		minigame_active = true
		print("Nora: Minigame AUTO-STARTED! Goal: ", ColorObject.ColorType.keys()[current_goal])
	else:
		minigame_active = false
		if station_already_completed:
			print("Nora: Station already completed - minigame not active")
		else:
			print("Nora: Minigame disabled - waiting for intro to finish")
	
	if station_already_completed:
		print("Nora: Station %d completed! Great job!" % current_station_index)
	else:
		show_station_speech()
		print("Nora: Please create %s for me!" % ColorObject.ColorType.keys()[current_goal])

func setup_station_objects():
	var station = get_node(minigame_stations[current_station_index])
	
	# Clear any old connections first
	for mixer in get_tree().get_nodes_in_group("ColorMixers"):
		if mixer.mixing_completed.is_connected(_on_mixing_completed):
			mixer.mixing_completed.disconnect(_on_mixing_completed)
	
	# Find and connect to all mixers at current station
	for child in station.get_children():
		if child is ColorMixer:
			print("Nora: Connected to mixer at station ", current_station_index)
			if not child.mixing_completed.is_connected(_on_mixing_completed):
				child.mixing_completed.connect(_on_mixing_completed)

func _on_player_entered(body):
	
	if body == Global.player and not is_moving:
		player_in_range = body
		player_is_near = true
		print("near player")
		show_interaction_prompt(true)

func _on_player_exited(body):
	if body == Global.player:
		player_is_near = false
		show_interaction_prompt(false)

func show_interaction_prompt(show: bool):
	if show and player_is_near:
		if not minigame_enabled:
			print("Talk to Nora to start")
		elif minigame_active:
			print("Press E to reset colors")
		else:
			print("Press E to start minigame")

func _input(event):
	# Use "yes" action instead of "ui_accept" or "interact"
	if Input.is_action_just_pressed("yes") and player_is_near and not is_moving:
		print("=== YES BUTTON PRESSED NEAR NORA ===")
		print("Nora: minigame_enabled = ", minigame_enabled)
		print("Nora: minigame_active = ", minigame_active)
		print("Nora: allow_reset = ", allow_reset)
		handle_player_interaction()

func handle_player_interaction():
	print("Nora: E pressed - minigame_enabled:", minigame_enabled, " minigame_active:", minigame_active)
	
	# Check if minigame is fully completed
	if Global.minigame_nora_completed:
		print("Nora: The color mixing challenges are complete! Thank you for your help!")
		return
	
	# Check if current station is already completed
	if stations_completed.size() > current_station_index and stations_completed[current_station_index]:
		print("Nora: This station is already completed! Let's move to the next one.")

		return
	
	if not minigame_enabled:
		print("Nora: Starting intro dialogue...")
		# After dialogue, call enable_minigame()
	elif not minigame_active:
		start_minigame()
	elif minigame_active and allow_reset:
		reset_current_minigame()

func start_minigame():
	minigame_active = true
	minigame_started.emit(current_goal, current_station_index)
	print("Nora: Minigame STARTED! Create %s!" % ColorObject.ColorType.keys()[current_goal])
	start_instruction_timer()
	
func _on_mixing_completed(result_color):
	if not minigame_active or not minigame_enabled:
		return
		
	print("=== NORA MIXING DETECTED ===")
	print("Nora: Received color: ", ColorObject.ColorType.keys()[result_color])
	print("Nora: Expected color: ", ColorObject.ColorType.keys()[current_goal])
	
	if result_color == current_goal and minigame_active and not is_moving:
		print("Nora: SUCCESS! Goal color created!")
		complete_minigame(true)
	else:
		print("Nora: Wrong color, keep trying!")
		
func complete_minigame(success: bool):
	minigame_active = false
	minigame_completed.emit(current_station_index, success)
	
	if success:
		goals_completed += 1
		
		# Mark this station as completed locally
		if stations_completed.size() > current_station_index:
			stations_completed[current_station_index] = true
		
		# SET INDIVIDUAL STATION GLOBAL FLAGS
		set_station_global_flag(current_station_index, true)
		
		print("Nora: Wonderful! You made %s!" % ColorObject.ColorType.keys()[current_goal])
		print("Nora: Station %d completed! Global flag set." % current_station_index)
		
		show_completion_speech() 
		stop_instruction_timer()
		
		if goals_completed < minigame_stations.size():
			await get_tree().create_timer(2.0).timeout
			move_to_station(goals_completed)
		else:
			# ALL STATIONS COMPLETED
			Global.minigame_nora_completed = true
			print("Nora: You completed all challenges! You're a color master!")
			
			#Global.is_cutscene_active = true
			#if Dialogic.timeline_ended.is_connected(_on_dialogic_finished):
			#	Dialogic.timeline_ended.disconnect(_on_dialogic_finished)
			#Dialogic.timeline_ended.connect(_on_dialogic_finished)
			#Dialogic.start("timeline7M", false)
			_setup_cutscene()
			
			# Start the cutscene with the player
			#if player_in_range:
			player_in_range = Global.player
			start_cutscene(player_in_range)
				
func set_station_global_flag(station_index: int, completed: bool):
	match station_index:
		0:  # Station 1 - Green
			Global.nora_station_1_completed = completed
			print("Global.nora_station_1_completed set to: ", completed)
		1:  # Station 2 - Purple
			Global.nora_station_2_completed = completed
			print("Global.nora_station_2_completed set to: ", completed)
		2:  # Station 3 - Gold
			Global.nora_station_3_completed = completed
			print("Global.nora_station_3_completed set to: ", completed)
		_:
			print("Warning: Unknown station index: ", station_index)
			




	
func reset_current_minigame():
	if not allow_reset or not minigame_active:
		print("Nora: Reset not allowed or minigame not active")
		return
		
	var station = get_node(minigame_stations[current_station_index])
	var reset_count = 0
	
	print("Nora: Starting RESET at station ", current_station_index)
	
	# STEP 0: Reset all mixers
	for child in station.get_children():
		if child is ColorMixer:
			child.reset_mixer()
			print("Nora: Reset mixer ", child.name)
	
	# STEP 1: Wait one frame to ensure all objects are properly removed
	await get_tree().process_frame
	
	# STEP 2: Find all Marker2D nodes to determine what objects should exist
	var markers = []
	for child in station.get_children():
		if child is Marker2D and child.name.begins_with("Marker_"):
			markers.append(child)
	
	print("Nora: Found ", markers.size(), " markers for recreation")
	
	# STEP 3: Remove ALL ColorObjects from station (double check after frame wait)
	var objects_to_remove = []
	for child in station.get_children():
		if child is ColorObject:
			objects_to_remove.append(child)
	
	for obj in objects_to_remove:
		if is_instance_valid(obj):
			print("Nora: Removing object ", obj.name)
			obj.queue_free()
	
	# STEP 4: Wait another frame to ensure cleanup is complete
	await get_tree().process_frame
	
	# STEP 5: Recreate objects based on markers
	for marker in markers:
		# Extract object name from marker name (Marker_ColorObject -> ColorObject)
		var object_name = marker.name.replace("Marker_", "")
		
		# Determine color based on object name AND station
		var color_type = get_correct_color_for_object(object_name, current_station_index)
		
		# Recreate the object
		var color_object_scene = load("res://scenes/objects/color_object.tscn")
		if color_object_scene:
			var new_object = color_object_scene.instantiate()
			station.add_child(new_object)
			
			# Force the name immediately and set owner
			new_object.name = object_name
			new_object.set_owner(station)
			
			new_object.set_color_type(color_type)
			new_object.global_position = marker.global_position
			new_object.linear_velocity = Vector2.ZERO
			new_object.angular_velocity = 0
			new_object.freeze = false
			new_object.set_is_in_mixer(false)
			
			reset_count += 1
			print("Nora: Recreated ", new_object.name, " as ", ColorObject.ColorType.keys()[color_type], " at station ", current_station_index)
	
	# STEP 6: Force scene tree update
	await get_tree().process_frame
	await get_tree().process_frame
	show_station_speech()
	
	print("Nora: RESET COMPLETE! Recreated ", reset_count, " objects")


func get_correct_color_for_object(object_name: String, station_index: int) -> ColorObject.ColorType:
	match station_index:
		0:  # Station 0 - Green goal (3 objects)
			match object_name:
				"ColorObject": return ColorObject.ColorType.RED
				"ColorObject2": return ColorObject.ColorType.BLUE
				"ColorObject3": return ColorObject.ColorType.YELLOW
		
		1:  # Station 1 - Purple goal (3 objects)
			match object_name:
				"ColorObject": return ColorObject.ColorType.RED
				"ColorObject2": return ColorObject.ColorType.BLUE
				"ColorObject3": return ColorObject.ColorType.YELLOW
		
		2:  # Station 2 - Gold goal (6 objects)
			match object_name:
				"ColorObject": return ColorObject.ColorType.RED
				"ColorObject2": return ColorObject.ColorType.BLUE
				"ColorObject3": return ColorObject.ColorType.YELLOW
				"ColorObject4": return ColorObject.ColorType.YELLOW  # Extra yellow
				"ColorObject5": return ColorObject.ColorType.RED     # Extra red
				"ColorObject6": return ColorObject.ColorType.BLUE    # Extra blue
	
	# Default fallback
	return ColorObject.ColorType.RED
	
func determine_color_from_name(object_name: String) -> ColorObject.ColorType:
	# Determine color based on object name pattern

	if "ColorObject" in object_name:
		match object_name:
			"ColorObject", "ColorObject5":
				return ColorObject.ColorType.RED
			"ColorObject2", "ColorObject6":
				return ColorObject.ColorType.BLUE
			"ColorObject3", "ColorObject4":
				return ColorObject.ColorType.YELLOW
			_:
				# Default for any other objects
				return ColorObject.ColorType.RED
	return ColorObject.ColorType.RED
	
func get_original_colors_for_station(station_index: int) -> Dictionary:
	# Define what color each object should be at each station

	match station_index:
		0:  # Station 1 (Green goal)
			return {
				"ColorObject": ColorObject.ColorType.RED,
				"ColorObject2": ColorObject.ColorType.BLUE, 
				"ColorObject3": ColorObject.ColorType.YELLOW
			}
		1:  # Station 2 (Purple goal)
			return {
				"ColorObject": ColorObject.ColorType.RED,
				"ColorObject2": ColorObject.ColorType.BLUE,
				"ColorObject3": ColorObject.ColorType.YELLOW
			}
		2:  # Station 3 (Gold goal)
			return {
				"ColorObject": ColorObject.ColorType.RED,
				"ColorObject2": ColorObject.ColorType.BLUE,
				"ColorObject3": ColorObject.ColorType.YELLOW,
				"ColorObject4": ColorObject.ColorType.YELLOW,  # Extra yellow for gold
				"ColorObject5": ColorObject.ColorType.RED,     # Extra red
				"ColorObject6": ColorObject.ColorType.BLUE     # Extra blue
			}
		_:
			return {}
			
# Helper functions for the reset system
func get_expected_objects_for_station(station_index: int) -> Array:
	# Define which objects should exist at each station

	match station_index:
		0:  # Station 1 (Green goal)
			return ["ColorObject", "ColorObject2", "ColorObject3"]
		1:  # Station 2 (Purple goal) 
			return ["ColorObject", "ColorObject2", "ColorObject3"]
		2:  # Station 3 (Gold goal)
			return ["ColorObject", "ColorObject2", "ColorObject3", "ColorObject4", "ColorObject5", "ColorObject6"]
		_:
			return []

func get_color_from_object_name(object_name: String) -> ColorObject.ColorType:
	# Determine color based on object name pattern

	if "ColorObject" in object_name:
		# Default colors for numbered objects
		match object_name:
			"ColorObject", "ColorObject4":
				return ColorObject.ColorType.RED
			"ColorObject2", "ColorObject5":
				return ColorObject.ColorType.BLUE
			"ColorObject3", "ColorObject6":
				return ColorObject.ColorType.YELLOW
			_:
				return ColorObject.ColorType.RED
	return ColorObject.ColorType.RED
	
func enable_minigame():
	"""Call this after intro dialogue to enable the minigame"""
	minigame_enabled = true
	minigame_active = true
	print("Nora: Minigame ENABLED after intro dialogue!")

func disable_minigame():
	"""Call this to temporarily disable the minigame"""
	minigame_enabled = false
	minigame_active = false
	print("Nora: Minigame DISABLED")

func set_allow_reset(allowed: bool):
	"""Call this to enable/disable reset functionality"""
	allow_reset = allowed
	print("Nora: Reset allowed = ", allowed)

func skip_to_station(station_index: int):
	"""Call this to jump to a specific station (for debugging)"""
	if station_index < minigame_stations.size():
		goals_completed = station_index
		move_to_station(station_index)
		
# ADD THIS NEW FUNCTION
func move_to_final_position():
	"""Move Nora to her final resting position after minigame completion"""
	if final_position_marker.is_empty():
		print("Nora: No final position marker set, staying at current position")
		return
	
	var final_marker = get_node(final_position_marker)
	if final_marker:
		# Disable minigame functionality
		minigame_enabled = false
		minigame_active = false
		allow_reset = false
		stop_instruction_timer() 
		# Move to final position
		global_position = final_marker.global_position
		
		# Ensure idle animation is playing
		if animation_player:
			animation_player.play("idle")
		
		start_final_position_bubbles()
		print("Nora: Moved to final position at ", global_position)
	else:
		print("Nora: Final position marker not found")

func move_to_final_position_animated():
	"""Move Nora to final position with animation"""
	if final_position_marker.is_empty():
		print("Nora: No final position marker set")
		return
	
	var final_marker = get_node(final_position_marker)
	if final_marker:
		# Disable minigame functionality
		minigame_enabled = false
		minigame_active = false
		allow_reset = false
		
		# Stop instruction timer
		stop_instruction_timer()
		
		# Start moving to final position
		target_position = final_marker.global_position
		is_moving = true
		print("Nora: Moving to final position from ", global_position, " to ", target_position)
		
		# Wait for movement to complete using a better approach
		await _wait_for_movement_completion()
		
		# Start bubbles after movement
		print("Nora: Final position movement completed, starting bubbles")
		start_final_position_bubbles()
	else:
		print("Nora: Final position marker not found")

func _wait_for_movement_completion():
	"""Wait for Nora to finish moving to target position"""
	var max_wait_time = 5.0  # Maximum time to wait (5 seconds)
	var wait_interval = 0.1  # Check every 0.1 seconds
	var elapsed_time = 0.0
	
	while is_moving and elapsed_time < max_wait_time:
		await get_tree().create_timer(wait_interval).timeout
		elapsed_time += wait_interval
		print("Nora: Waiting for movement... is_moving = ", is_moving)
	
	if not is_moving:
		print("Nora: Movement completed successfully")
	else:
		print("Nora: Movement timeout - forcing idle state")
		is_moving = false
		if animation_player:
			animation_player.play("idle")



func _setup_cutscene():
	"""Setup the cutscene sequence for when minigame is completed"""
	print("Nora: Setting up cutscene sequence")
	
	# Configure cutscene properties
	cutscene_name = "NoraMinigameCompletion"
	play_only_once = true
	global_flag_to_set = "minigame_nora_completed"
	alyra.visible = false
	nora.visible = false
	varek.visible = false
	# Setup markers if they exist
	player_markers = {
		# Example positions - adjust to match your scene
		"marker1": marker1.global_position,
		"marker2": marker2.global_position,
		#"marker2": marker2.global_position,
		#"marker3": marker3.global_position,
		#"marker4": marker4.global_position,
		#"marker5": marker5.global_position,
		#"marker6": marker6.global_position
		
	}
	
	cutscene_markers = {
		"cutscene_marker1": cutscene_marker1.global_position,
		#"cutscene_marker2": cutscene_marker2.global_position
	}
	
	# Define the sequence you want
	sequence = [
		{"type": "move_player", "name": "marker1", "duration": 0.5, "animation": "run", "wait": true},
		{"type": "wait", "duration": 0.5},
		{"type": "fade_out", "wait": false},
		{"type": "player_face", "direction": 1}, #1 is right, -1 is left
		{"type": "player_animation", "name": "idle", "wait": false},
		#{"type": "animation", "name": "anim1", "wait": true, "loop": false},
		{"type": "animation", "name": "anim1_idle", "wait": false, "loop": true},
		{"type": "dialog", "name": "timeline7M", "wait": true},
		{"type": "move_player", "name": "marker2", "duration": 1, "animation": "shine", "wait": false},
		{"type": "animation", "name": "anim2", "wait": true, "loop": false},
		#{"type": "fade_in"},
		{"type": "animation", "name": "anim3_idle", "wait": false, "loop": true},
		{"type": "dialog", "name": "timeline7M_1", "wait": true},
		{"type": "move_player", "name": "marker1", "duration": 0.5, "animation": "jump", "wait": true},
		{"type": "fade_out", "wait": false},
		#{"type": "animation", "name": "anim3_idle", "wait": false, "loop": true},
		{"type": "player_form", "name": "Magus", "wait": true},
		{"type": "player_animation", "name": "save",  "wait": true},
		#{"type": "wait", "duration": 0.5},
		{"type": "player_animation", "name": "load",  "wait": true},
		{"type": "wait", "duration": 0.5},
		{"type": "player_animation", "name": "idle", "wait": false},
		{"type": "dialog", "name": "timeline7M_2", "wait": true},
		
		#{"type": "animation", "name": "anim2_idle", "wait": false, "loop": true},
		#{"type": "move_player", "name": "marker1", "duration": 2, "animation": "run", "wait": true},
		#{"type": "player_animation", "name": "idle", "wait": false},
		#{"type": "dialog", "name": "timeline6M_1", "wait": true},
		{"type": "fade_in"},
		{"type": "animation", "name": "anim4", "wait": false, "loop": false},
		
	]

func _on_cutscene_start():
	"""Called when cutscene starts"""
	print("Nora Cutscene: Starting")

func _on_cutscene_end():
	"""Called when cutscene ends"""
	print("Nora Cutscene: Finished")
	alyra.visible = false
	nora.visible = false
	varek.visible = false
	# Set your global flags and rewards
	Global.timeline = 4
	Global.magus_form = true
	
	if player_in_range and player_in_range.has_method("unlock_and_force_form"):
		player_in_range.unlock_and_force_form("Magus")
	
	Global.health_max += 10
	Global.health = Global.health_max
	if Global.player and Global.player.has_signal("health_changed"):
		Global.player.health_changed.emit(Global.health, Global.health_max)
	
	Global.remove_quest_marker("Explore Tromarvelia")
	
	# Move Nora to final position
	move_to_final_position_animated()

# Add these functions anywhere in your class (after _ready is good)
func create_speech_bubble(text: String, duration: float = 3.0):
	"""Create a speech bubble with the given text"""
	
	# Remove any existing bubble first
	remove_current_bubble()
	
	# Check if we have a speech bubble scene assigned
	if not speech_bubble_scene:
		print("ERROR: No speech_bubble_scene assigned!")
		return
	
	# Create instance from the scene
	var bubble = speech_bubble_scene.instantiate()
	
	# Add as child of Nora
	add_child(bubble)
	current_bubble = bubble
	
	# Wait a frame for the bubble to be ready
	await get_tree().process_frame
	
	# Call set_text method on the bubble
	if bubble.has_method("set_text"):
		bubble.set_text(text, duration)
		
		# Adjust bubble position using our offset variables
		bubble.position += Vector2(bubble_x_offset, bubble_y_offset)
		
		#print("Nora: Showing bubble: ", text)
	else:
		print("ERROR: Bubble scene doesn't have set_text method!")
		bubble.queue_free()
		current_bubble = null

func remove_current_bubble():
	"""Safely remove current bubble"""
	if current_bubble and is_instance_valid(current_bubble):
		current_bubble.queue_free()
		current_bubble = null

func show_station_speech():
	"""Show speech bubble based on current station"""
	if Global.meet_nora_one == true:
		match current_station_index:
			0:  # Station 1 - Green
				create_speech_bubble("Mix the orbs to create GREEN orb!")
			1:  # Station 2 - Purple
				create_speech_bubble("Alright, next one I need to get PURPLE orb")
			2:  # Station 3 - Gold
				create_speech_bubble("This is the final one, I need GOLDEN orb. You need to mix TWO TIMES!")
			_:
				pass
	else:
		pass
		
	start_instruction_timer()

func show_completion_speech():
	"""Show speech when a station is completed"""
	match current_station_index:
		0, 1:  # Station 1 or 2 completed
			create_speech_bubble("Great! Let's move on to the next mixer.")
		2:  # Station 3 completed (handled by cutscene)
			pass  # Cutscene will handle this
		_:
			pass

func start_final_position_bubbles():
	"""Start showing random bubbles when Nora is at final position"""
	print("Nora: Starting final position bubble system...")
	
	# Remove existing timer if it exists
	if bubble_timer and is_instance_valid(bubble_timer):
		bubble_timer.queue_free()
		bubble_timer = null
	
	# Create new timer
	bubble_timer = Timer.new()
	add_child(bubble_timer)
	bubble_timer.timeout.connect(_show_random_final_bubble)
	
	# Set random interval (8-15 seconds)
	var wait_time = randf_range(8.0, 15.0)
	bubble_timer.wait_time = wait_time
	bubble_timer.start()
	
	print("Nora: Started final position bubble timer (first bubble in ", wait_time, " seconds)")

func _show_random_final_bubble():
	"""Show a random bubble at final position"""
	#print("Nora: _show_random_final_bubble called")
	
	# Check if we should show a bubble
	if final_position_bubble_texts.size() > 0 and not is_moving and minigame_enabled == false:
		var random_text = final_position_bubble_texts[randi() % final_position_bubble_texts.size()]
		create_speech_bubble(random_text)
		#print("Nora: Showing random final position bubble: ", random_text)
	else:
		print("Nora: Cannot show final bubble - is_moving: ", is_moving, ", minigame_enabled: ", minigame_enabled)
	
	# Reset timer for next bubble
	if bubble_timer and is_instance_valid(bubble_timer) and not is_moving:
		var wait_time = randf_range(8.0, 15.0)
		bubble_timer.wait_time = wait_time
		bubble_timer.start()
		#print("Nora: Next final bubble in ", wait_time, " seconds")
		

func start_instruction_timer():
	"""Start timer to repeat station instructions"""
	# Remove existing timer if it exists
	if instruction_timer and is_instance_valid(instruction_timer):
		instruction_timer.queue_free()
	
	# Create new timer
	instruction_timer = Timer.new()
	add_child(instruction_timer)
	instruction_timer.timeout.connect(_repeat_station_instruction)
	
	# Set random interval (15-20 seconds)
	instruction_timer.wait_time = randf_range(15.0, 20.0)
	instruction_timer.start()
	print("Nora: Started instruction repeat timer for station ", current_station_index)

func _repeat_station_instruction():
	"""Repeat the current station instruction"""
	# Only repeat if:
	# 1. Station is not completed
	# 2. Minigame is active (player is working on it)
	# 3. Player is not currently moving to another station
	if not is_moving and minigame_active and not Global.minigame_nora_completed:
		# Check if current station is not completed
		if current_station_index < stations_completed.size() and not stations_completed[current_station_index]:
			print("Nora: Repeating instruction for station ", current_station_index)
			
			match current_station_index:
				0:  # Station 1 - Green
					create_speech_bubble("Remember: Create a GREEN orb!")
				1:  # Station 2 - Purple
					create_speech_bubble("Don't forget: I need a PURPLE orb!")
				2:  # Station 3 - Gold
					create_speech_bubble("Remember: GOLD requires TWO mixes!")
				_:
					pass
	
	# Reset timer for next repeat
	if instruction_timer and is_instance_valid(instruction_timer):
		instruction_timer.wait_time = randf_range(15.0, 20.0)  # Random interval
		instruction_timer.start()

func stop_instruction_timer():
	"""Stop the instruction repeat timer"""
	if instruction_timer and is_instance_valid(instruction_timer):
		instruction_timer.stop()
		instruction_timer.queue_free()
		instruction_timer = null
		print("Nora: Stopped instruction repeat timer")
		


#func _on_dialogic_finished(_timeline_name = ""):
#	print("CutsceneManager: Dialogic timeline finished. Initiating fade out.")
	# Dialog is done. Now, fade out the black screen.

#	Global.is_cutscene_active = false
	
#	Dialogic.clear(Dialogic.ClearFlags.FULL_CLEAR)
	
	# Disconnect the signal to prevent unintended calls.
#	if Dialogic.timeline_ended.is_connected(_on_dialogic_finished):
#		Dialogic.timeline_ended.disconnect(_on_dialogic_finished)



#	Global.timeline = 4
#	Global.magus_form = true
	
	
#	await get_tree().create_timer(0.1).timeout
#	player_in_range.unlock_and_force_form("Magus")
	
#	Global.health_max += 10
#	Global.health = Global.health_max
#	Global.player.health_changed.emit(Global.health, Global.health_max)
	
	#player_in_range.unlock_state("Magus")
	#player_in_range.switch_state("Magus")
	#Global.selected_form_index = 1
	#player_in_range.current_state_index = Global.selected_form_index
	#player_in_range.combat_fsm.change_state(IdleState.new(player_in_range))
#	print("Global.magus_form ",Global.magus_form )
#	Global.remove_quest_marker("Explore Tromarvelia")
	
#	move_to_final_position_animated()
