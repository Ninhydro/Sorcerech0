extends CharacterBody2D
class_name NoraNPC

@export var movement_speed: float = 50.0
@export var minigame_stations: Array[NodePath] = []

# Control flags
@export var minigame_enabled: bool = false  # Set this to true AFTER intro dialogue
@export var allow_reset: bool = true  # Can be turned off if needed

@onready var sprite_2d = $Sprite2D
@onready var animation_player = $AnimationPlayer
@onready var interaction_area = $InteractionArea

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


func _ready():
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

# New function to check individual station completions from global flags
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
		# You could skip setup or show different message
		# For now, we'll still set it up but maybe show different UI
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
		# You could auto-advance here if you want
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
		
		if goals_completed < minigame_stations.size():
			await get_tree().create_timer(2.0).timeout
			move_to_station(goals_completed)
		else:
			# ALL STATIONS COMPLETED
			Global.minigame_nora_completed = true
			print("Nora: You completed all challenges! You're a color master!")
			
			Global.is_cutscene_active = true
			if Dialogic.timeline_ended.is_connected(_on_dialogic_finished):
				Dialogic.timeline_ended.disconnect(_on_dialogic_finished)
			Dialogic.timeline_ended.connect(_on_dialogic_finished)
			Dialogic.start("timeline7M", false)

# New function to set individual station global flags
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
			



func _on_dialogic_finished(_timeline_name = ""):
	print("CutsceneManager: Dialogic timeline finished. Initiating fade out.")
	# Dialog is done. Now, fade out the black screen.

	Global.is_cutscene_active = false
	
	Dialogic.clear(Dialogic.ClearFlags.FULL_CLEAR)
	
	# Disconnect the signal to prevent unintended calls.
	if Dialogic.timeline_ended.is_connected(_on_dialogic_finished):
		Dialogic.timeline_ended.disconnect(_on_dialogic_finished)



	Global.timeline = 4
	Global.magus_form = true
	player_in_range.unlock_state("Magus")
	player_in_range.switch_state("Magus")
	Global.selected_form_index = 1
	player_in_range.current_state_index = Global.selected_form_index
	player_in_range.combat_fsm.change_state(IdleState.new(player_in_range))
	print("Global.magus_form ",Global.magus_form )
	Global.remove_quest_marker("Explore Tromarvelia")
	
	move_to_final_position_animated()
	
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
	
	print("Nora: RESET COMPLETE! Recreated ", reset_count, " objects")

# NEW FUNCTION: Get the correct color for each object at each station
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
	# Adjust this based on your naming convention
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
	# Adjust this based on your actual station setups
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
	# Adjust this based on your actual station setups
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
	# Adjust this based on your actual naming convention
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
		
		# Move to final position
		global_position = final_marker.global_position
		
		# Ensure idle animation is playing
		if animation_player:
			animation_player.play("idle")
		
		print("Nora: Moved to final position at ", global_position)
	else:
		print("Nora: Final position marker not found")

# ADD THIS NEW FUNCTION
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
		
		# Start moving to final position
		target_position = final_marker.global_position
		is_moving = true
		print("Nora: Moving to final position...")
	else:
		print("Nora: Final position marker not found")

