extends MasterCutscene

#var _has_been_triggered: bool = false
#@onready var collision_shape: CollisionShape2D = $CollisionShape2D
#@export var play_only_once: bool = true



var target_room1 = "Room_ExactlyionTown"     # Name of the destination room (node or scene)
var target_spawn1 = "Spawn_FromABattlefield"    # Name of the spawn marker in the target room

var target_room2 = "Room_TromarveliaTown"     # Name of the destination room (node or scene)
var target_spawn2 = "Spawn_FromABattlefield"    # Name of the spawn marker in the target room

var target_room3 = "Room_AerendaleCapital"     # Name of the destination room (node or scene)
var target_spawn3 = "Spawn_Genocide"    # Name of the spawn marker in the target room


var target_room4 = "Room_HiddenRuins"     # Name of the destination room (node or scene)
var target_spawn4 = "Spawn_FromCapital"    # Name of the spawn marker in the target room

var target_room5 = "Room_AerendaleJunkyard"     # Name of the destination room (node or scene)
var target_spawn5 = "Spawn_FromMaya"    # Name of the spawn marker in the target room


var player_in_range = null

@onready var transition_manager = get_node("/root/TransitionManager")

var _teleport_cooldown: bool = false

@onready var nataly: Sprite2D = $Nataly
@onready var maya: Sprite2D = $Maya
#@onready var lux: Sprite2D = $Lux
#@onready var gawr: Node2D = $BodyPivot
#@onready var nora: Node2D = $Nora

#@onready var marker1: Marker2D = $Marker2D
#@onready var marker2: Marker2D = $Marker2D2
#@onready var marker3: Marker2D = $Marker2D3
#@onready var marker4: Marker2D = $Marker2D4

#@onready var cutscene_marker1: Marker2D = $CutsceneMarker1

# Called when the node enters the scene tree for the first time.
func _on_body_entered(body):
	print("Cutscene17: Body entered - ", body.name if body else "null")
	if _teleport_cooldown:
		print("Cutscene17: In cooldown, ignoring trigger")
		return
	# Check if timeline condition is met
	if Global.timeline == 7 and Global.ult_cyber_form == true and Global.ult_magus_form == true and body.is_in_group("player"):
		print("Cutscene17: Conditions met, calling parent method")
		# Store player reference first
		player_in_range = body
		#play_only_once = false
		# Call parent's _on_body_entered
		#betael.visible = true
		#maya.visible = false
		_setup_cutscene()
		super._on_body_entered(body)
	else:
		print("Cutscene17: Conditions not met. Global.timeline = ", Global.timeline, ", is_player = ", body.is_in_group("player") if body else "false")
		
func _setup_cutscene():
	cutscene_name = "Cutscene17"
	nataly.visible = false
	maya.visible = false
	play_only_once = false
	area_activation_flag = ""  # No flag required
	global_flag_to_set = ""  # We'll handle this manually
	
	# IMPORTANT: Make sure your scene has these Marker2D nodes or set positions manually

	#player_markers = {
		# Example positions - adjust to match your scene
	#	"marker1": marker1.global_position,
	#	"marker2": marker2.global_position,
	#	"marker3": marker3.global_position,
	#	"marker4": marker4.global_position,
		#"marker5": marker5.global_position,
		#"marker6": marker6.global_position
		
	#}
	
	#cutscene_markers = {
	#	"cutscene_marker1": cutscene_marker1.global_position,
		#"cutscene_marker2": cutscene_marker2.global_position
	#}
	
	# Simple sequence: just play dialog
	sequence = [
		{"type": "wait", "duration": 0.5},
		{"type": "fade_out", "wait": false},
		
		#{"type": "player_face", "direction": 1}, #1 is right, -1 is left
		{"type": "player_animation", "name": "idle",  "wait": false},
		{"type": "animation", "name": "anim1", "wait": true, "loop": false},
		{"type": "animation", "name": "anim1_idle", "wait": false, "loop": true},
		{"type": "dialog", "name": "timeline16_9", "wait": true},
		
		{"type": "wait", "duration": 0.5},		
		{"type": "fade_in"},
		{"type": "animation", "name": "anim2", "wait": false, "loop": false},
		

	]

func _on_cutscene_start():
	print("Cutscene17: Starting")
	# Player reference is already stored in _player_ref by parent class
	if _player_ref:
		player_in_range = _player_ref
		print("Cutscene17: Player reference stored: ", player_in_range.name)

func _on_cutscene_end():
	print("Cutscene17: Finished")
	nataly.visible = false
	maya.visible = false
	if Global.route_status == "Magus":
		_teleport_cooldown = true
		Global.timeline = 8
		Global.remove_quest_marker("Make decision at Maya's house")
		#if Global.alyra_dead == true:
		#	Dialogic.start("timeline17M", false)
		#elif Global.alyra_dead == false:
		#	Dialogic.start("timeline17MV2", false)
		if player_in_range:
			transition_manager.travel_to(player_in_range, target_room2, target_spawn2)
		Global.add_quest_marker("Fight for the Magus", Vector2(6744,-2416))
		await get_tree().create_timer(1).timeout
		_teleport_cooldown = false
		#Global.current_scene_path = get_tree().current_scene.scene_file_path
		#var manual_save_slot_name = SaveLoadManager.MANUAL_SAVE_SLOT_PREFIX + "1" # Example: Save to slot 1
		#Global.health = Global.health_max
		#player_in_range.health_changed.emit(Global.health, Global.health_max) 
		#if SaveLoadManager.save_game(player_in_range, manual_save_slot_name): # Pass the player node and slot name
		#	print("Game saved successfully at SaveSpot to manual slot 1!") # Updated print statement
			# Optionally, display a temporary "Game Saved!" message on the screen
		#else:
		#	printerr("Failed to save game at SaveSpot (SaveLoadManager returned false).") # Updated print statement

	elif Global.route_status == "Cyber":
		_teleport_cooldown = true
		Global.timeline = 8
		Global.remove_quest_marker("Make decision at Maya's house")
		#Dialogic.start("timeline17C", false)
		if player_in_range:
			transition_manager.travel_to(player_in_range, target_room1, target_spawn1)
		Global.add_quest_marker("Fight for the Cyber", Vector2(-704,3896))
		await get_tree().create_timer(1).timeout
		_teleport_cooldown = false
		#Global.current_scene_path = get_tree().current_scene.scene_file_path
		#var manual_save_slot_name = SaveLoadManager.MANUAL_SAVE_SLOT_PREFIX + "1" # Example: Save to slot 1
		#Global.health = Global.health_max
		#player_in_range.health_changed.emit(Global.health, Global.health_max) 
		#if SaveLoadManager.save_game(player_in_range, manual_save_slot_name): # Pass the player node and slot name
		#	print("Game saved successfully at SaveSpot to manual slot 1!") # Updated print statement
			# Optionally, display a temporary "Game Saved!" message on the screen
		#else:
		#	printerr("Failed to save game at SaveSpot (SaveLoadManager returned false).") # Updated print statement
		
	elif Global.route_status == "True" or Global.route_status == "Pacifist":
		_teleport_cooldown = true
		Global.timeline = 8
		Global.remove_quest_marker("Make decision at Maya's house")
		#Dialogic.start("timeline17T", false)
		if player_in_range:
			transition_manager.travel_to(player_in_range, target_room4, target_spawn4)
		Global.add_quest_marker("Find the the other way with Lux", Vector2(6032,3520))
		await get_tree().create_timer(1).timeout
		_teleport_cooldown = false
		#Global.current_scene_path = get_tree().current_scene.scene_file_path
		#var manual_save_slot_name = SaveLoadManager.MANUAL_SAVE_SLOT_PREFIX + "1" # Example: Save to slot 1
		#Global.health = Global.health_max
		#player_in_range.health_changed.emit(Global.health, Global.health_max) 
		#if SaveLoadManager.save_game(player_in_range, manual_save_slot_name): # Pass the player node and slot name
		#	print("Game saved successfully at SaveSpot to manual slot 1!") # Updated print statement
			# Optionally, display a temporary "Game Saved!" message on the screen
		#else:
		#	printerr("Failed to save game at SaveSpot (SaveLoadManager returned false).") # Updated print statement
			
	elif Global.route_status == "Genocide":
		_teleport_cooldown = true
		Global.timeline = 8
		Global.remove_quest_marker("Make decision at Maya's house")
		#Dialogic.start("timeline17G", false)
		if player_in_range:
			transition_manager.travel_to(player_in_range, target_room3, target_spawn3)
		Global.add_quest_marker("Destroy Everyone!", Vector2(-3376,1280))
		await get_tree().create_timer(1).timeout
		_teleport_cooldown = false
		#Global.current_scene_path = get_tree().current_scene.scene_file_path
		#var manual_save_slot_name = SaveLoadManager.MANUAL_SAVE_SLOT_PREFIX + "1" # Example: Save to slot 1
		#Global.health = Global.health_max
		#player_in_range.health_changed.emit(Global.health, Global.health_max) 
		#if SaveLoadManager.save_game(player_in_range, manual_save_slot_name): # Pass the player node and slot name
		#	print("Game saved successfully at SaveSpot to manual slot 1!") # Updated print statement
			# Optionally, display a temporary "Game Saved!" message on the screen
		#else:
		#	printerr("Failed to save game at SaveSpot (SaveLoadManager returned false).") # Updated print statement
	
	else:
		
		#if collision_shape:
		#	collision_shape.set_deferred("disabled", true)
		
		# Small delay to ensure collision is disabled before teleport
		#await get_tree().create_timer(0.1).timeout
		_teleport_cooldown = true
		
		if player_in_range:
			transition_manager.travel_to(player_in_range, target_room5, target_spawn5)
		#_has_been_triggered = false
		await get_tree().create_timer(1).timeout
		Global.timeline = 7
		_teleport_cooldown = false
		#player_in_range = null
		#play_only_once = false
		#_has_been_triggered = false
		#await get_tree().create_timer(0.5).timeout
		#if collision_shape:
		#	collision_shape.set_deferred("disabled", false)
		
	# Override the parent's play_only_once behavior for this route
		
	
	
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
	
	




func _on_body_exited(body):
	#if body.is_in_group("player"):
	#	print("player exiting")
	#	await get_tree().create_timer(0.5).timeout
	#	player_in_range = null
	#	play_only_once = false
	#	_has_been_triggered = false
	pass
