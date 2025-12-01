extends Area2D

var _has_been_triggered: bool = false
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@export var play_only_once: bool = true

@onready var interaction_label = $Label 

var target_room = "Room_AerendaleTown"     # Name of the destination room (node or scene)
var target_spawn = "Spawn_FromJunkyard"    # Name of the spawn marker in the target room



var player_in_range = null

@onready var transition_manager = get_node("/root/TransitionManager")

# Called when the node enters the scene tree for the first time.
func _ready():
	interaction_label.visible = false


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if Global.timeline == 10 and (Global.route_status == "True" or Global.route_status == "Pacifist") and Global.game_cleared == false:
		collision_shape.disabled = false			
		if player_in_range and Input.is_action_just_pressed("yes") and not _has_been_triggered:
			handle_interaction()
		
	else:
		collision_shape.disabled = true


func handle_interaction():
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


		#MIGHT NEED TO MAKE DIFFERENT ANIMATION CUTSCENE FOR DIFFERENT CHOICE OPTIONS
		#Put different dialog timeline17 on animation also later
	
		if Global.route_status == "True":
			Dialogic.start("timeline28T", false)
		elif Global.route_status == "Pacifist":
			Dialogic.start("timeline28TP", false)
			
func _on_body_entered(body):
	#print("Player position: ",player_node_ref.global_position)

	interaction_label.visible = true # Show the "Press E to Save" label
	if body.name == "Player":
		player_in_range = body
	



func _on_dialogic_finished(_timeline_name = ""):
	print("CutsceneManager: Dialogic timeline finished. Initiating fade out.")
	# Dialog is done. Now, fade out the black screen.

	Global.is_cutscene_active = false
	
	Dialogic.clear(Dialogic.ClearFlags.FULL_CLEAR)
	
	# Disconnect the signal to prevent unintended calls.
	if Dialogic.timeline_ended.is_connected(_on_dialogic_finished):
		Dialogic.timeline_ended.disconnect(_on_dialogic_finished)



	Global.timeline = 10
	if Global.route_status == "True":
		Global.ending_true = true
		Global.persistent_ending_true = true
		Global.check_100_percent_completion()
		Global.save_persistent_data()
	elif Global.route_status == "Pacifist":
		Global.ending_pacifist = true
		Global.persistent_ending_pacifist = true
		Global.check_100_percent_completion()
		Global.save_persistent_data()
	Global.game_cleared = true
	#player_status & kills need to be reset from NPC
	#affinity need to be reset from NPC

#	if player_in_range:
#		transition_manager.travel_to(player_in_range, target_room, target_spawn)
	


	
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
	player_in_range = null
	interaction_label.visible = false
