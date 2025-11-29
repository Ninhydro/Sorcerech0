extends Area2D

var _has_been_triggered: bool = false
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@export var play_only_once: bool = true



var target_room1 = "Room_ExactlyionTown"     # Name of the destination room (node or scene)
var target_spawn1 = "Spawn_FromABattlefield"    # Name of the spawn marker in the target room

var target_room2 = "Room_TromarveliaTown"     # Name of the destination room (node or scene)
var target_spawn2 = "Spawn_FromABattlefield"    # Name of the spawn marker in the target room

var target_room3 = "Room_AerendaleCapital"     # Name of the destination room (node or scene)
var target_spawn3 = "Spawn_Genocide"    # Name of the spawn marker in the target room


var target_room4 = "Room_HiddenRuins"     # Name of the destination room (node or scene)
var target_spawn4 = "Spawn_FromCapital"    # Name of the spawn marker in the target room

var player_in_range = null

@onready var transition_manager = get_node("/root/TransitionManager")

# Called when the node enters the scene tree for the first time.
func _ready():
	#Global.player_status = "Pacifist"
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	#print(Global.player_status)
	if Global.timeline == 7 and Global.ult_cyber_form == true and Global.ult_magus_form == true:
		collision_shape.disabled = false
		
	else:
		collision_shape.disabled = true
	
	

func _on_body_entered(body):
	#print("Player position: ",player_node_ref.global_position)
	if (body.is_in_group("player") and not _has_been_triggered):  #and Global.cutscene_finished1 == false:
		player_in_range = body
		print("Player entered cutscene trigger area. Starting cutscene.")

		if collision_shape:
			collision_shape.set_deferred("disabled", true)
		else:
			printerr("Cutscene Area2D: WARNING: CollisionShape2D is null, cannot disable it. Using Area2D monitoring instead.")
			set_deferred("monitorable", false)
			set_deferred("monitoring", false)

		#start_cutscene(cutscene_animation_name_to_play, 0.0)

		if play_only_once:
			_has_been_triggered = true
			

		Global.is_cutscene_active = true
		#Global.cutscene_name = cutscene_animation_name
		#Global.cutscene_playback_position = start_position
		#Dialogic.start("timeline1", false)
		if Dialogic.timeline_ended.is_connected(_on_dialogic_finished):
			Dialogic.timeline_ended.disconnect(_on_dialogic_finished)
		Dialogic.timeline_ended.connect(_on_dialogic_finished)

	# Start your dialog timeline.
		#MIGHT NEED TO MAKE DIFFERENT ANIMATION CUTSCENE FOR DIFFERENT CHOICE OPTIONS
		Dialogic.start("timeline16_9", false)
		#if Global.alyra_dead == false:
		#	Dialogic.start("timeline13V2", false) #alive alive

		#elif Global.alyra_dead == true:
		#	Dialogic.start("timeline13", false) #alive dead



func _on_dialogic_finished(_timeline_name = ""):
	print("CutsceneManager: Dialogic timeline finished. Initiating fade out.")
	# Dialog is done. Now, fade out the black screen.

	Global.is_cutscene_active = false
	
	Dialogic.clear(Dialogic.ClearFlags.FULL_CLEAR)
	
	# Disconnect the signal to prevent unintended calls.
	if Dialogic.timeline_ended.is_connected(_on_dialogic_finished):
		Dialogic.timeline_ended.disconnect(_on_dialogic_finished)

	
	
	#Global.timeline = 8
	#Global.remove_quest_marker("Make decision at Maya's house")

	if Global.route_status == "Magus":
		Global.timeline = 8
		Global.remove_quest_marker("Make decision at Maya's house")
		if Global.alyra_dead == true:
			Dialogic.start("timeline17M", false)
		elif Global.alyra_dead == false:
			Dialogic.start("timeline17MV2", false)
		if player_in_range:
			transition_manager.travel_to(player_in_range, target_room1, target_spawn1)
		Global.add_quest_marker("Fight for the Magus", Vector2(6744,-2416))
		
		Global.current_scene_path = get_tree().current_scene.scene_file_path
		var manual_save_slot_name = SaveLoadManager.MANUAL_SAVE_SLOT_PREFIX + "1" # Example: Save to slot 1
		Global.health = Global.health_max
		player_in_range.health_changed.emit(Global.health, Global.health_max) 
		if SaveLoadManager.save_game(player_in_range, manual_save_slot_name): # Pass the player node and slot name
			print("Game saved successfully at SaveSpot to manual slot 1!") # Updated print statement
			# Optionally, display a temporary "Game Saved!" message on the screen
		else:
			printerr("Failed to save game at SaveSpot (SaveLoadManager returned false).") # Updated print statement

	elif Global.route_status == "Cyber":
		Global.timeline = 8
		Global.remove_quest_marker("Make decision at Maya's house")
		Dialogic.start("timeline17C", false)
		if player_in_range:
			transition_manager.travel_to(player_in_range, target_room2, target_spawn2)
		Global.add_quest_marker("Fight for the Cyber", Vector2(-704,3896))
		
		Global.current_scene_path = get_tree().current_scene.scene_file_path
		var manual_save_slot_name = SaveLoadManager.MANUAL_SAVE_SLOT_PREFIX + "1" # Example: Save to slot 1
		Global.health = Global.health_max
		player_in_range.health_changed.emit(Global.health, Global.health_max) 
		if SaveLoadManager.save_game(player_in_range, manual_save_slot_name): # Pass the player node and slot name
			print("Game saved successfully at SaveSpot to manual slot 1!") # Updated print statement
			# Optionally, display a temporary "Game Saved!" message on the screen
		else:
			printerr("Failed to save game at SaveSpot (SaveLoadManager returned false).") # Updated print statement
		
	elif Global.route_status == "True" or Global.route_status == "Pacifist":
		Global.timeline = 8
		Global.remove_quest_marker("Make decision at Maya's house")
		Dialogic.start("timeline17T", false)
		if player_in_range:
			transition_manager.travel_to(player_in_range, target_room4, target_spawn4)
		Global.add_quest_marker("Find the the other way with Lux", Vector2(6032,3520))
		
		Global.current_scene_path = get_tree().current_scene.scene_file_path
		var manual_save_slot_name = SaveLoadManager.MANUAL_SAVE_SLOT_PREFIX + "1" # Example: Save to slot 1
		Global.health = Global.health_max
		player_in_range.health_changed.emit(Global.health, Global.health_max) 
		if SaveLoadManager.save_game(player_in_range, manual_save_slot_name): # Pass the player node and slot name
			print("Game saved successfully at SaveSpot to manual slot 1!") # Updated print statement
			# Optionally, display a temporary "Game Saved!" message on the screen
		else:
			printerr("Failed to save game at SaveSpot (SaveLoadManager returned false).") # Updated print statement
			
	elif Global.route_status == "Genocide":
		Global.timeline = 8
		Global.remove_quest_marker("Make decision at Maya's house")
		Dialogic.start("timeline17G", false)
		if player_in_range:
			transition_manager.travel_to(player_in_range, target_room3, target_spawn3)
		Global.add_quest_marker("Destroy Everyone!", Vector2(-3376,1280))
		
		Global.current_scene_path = get_tree().current_scene.scene_file_path
		var manual_save_slot_name = SaveLoadManager.MANUAL_SAVE_SLOT_PREFIX + "1" # Example: Save to slot 1
		Global.health = Global.health_max
		player_in_range.health_changed.emit(Global.health, Global.health_max) 
		if SaveLoadManager.save_game(player_in_range, manual_save_slot_name): # Pass the player node and slot name
			print("Game saved successfully at SaveSpot to manual slot 1!") # Updated print statement
			# Optionally, display a temporary "Game Saved!" message on the screen
		else:
			printerr("Failed to save game at SaveSpot (SaveLoadManager returned false).") # Updated print statement
	
	else:
		Global.timeline = 7
	_has_been_triggered = false
	

	
	#if player_in_range:
	#		transition_manager.travel_to(player_in_range, target_room, target_spawn)
	#End Demo/Part 1
	
	
	#Global.magus_form = true
	#player_in_range.unlock_state("Magus")
	#player_in_range.switch_state("Magus")
	#Global.selected_form_index = 1
	#player_in_range.current_state_index = Global.selected_form_index
	#player_in_range.combat_fsm.change_state(IdleState.new(player_in_range))
	
	#Global.set_player_form(get_current_form_id())
	#Global.current_form = get_current_form_id()
	#Global.first_tromarvelia = true



func _on_body_exited(body):
	pass # Replace with function body.
