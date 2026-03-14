extends MasterCutscene

#var _has_been_triggered: bool = false
#@onready var collision_shape: CollisionShape2D = $CollisionShape2D
#@export var play_only_once: bool = true



var target_room = "Room_AerendaleTown"     # Name of the destination room (node or scene)
var target_spawn = "Spawn_FromJunkyard"    # Name of the spawn marker in the target room

var player_in_range = null

@onready var transition_manager = get_node("/root/TransitionManager")

func start_cutscene2() -> void:
	player_in_range = Global.player
	_setup_cutscene()
	start_cutscene(player_in_range)
	
# Called when the node enters the scene tree for the first time.



# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	if Global.timeline == 8.5 and (Global.route_status == "True" or Global.route_status == "Pacifist") :
#		collision_shape.disabled = false
#	else:
#		collision_shape.disabled = true


func _setup_cutscene():
	cutscene_name = "magusbossfinal"
	#nataly.visible = false
	#maya.visible = false
	#fini.visible = false
	#sterling.visible = false
	play_only_once = true
	area_activation_flag = ""  # No flag required
	global_flag_to_set = ""  # We'll handle this manually
	
	# IMPORTANT: Make sure your scene has these Marker2D nodes or set positions manually

	#player_markers = {
		# Example positions - adjust to match your scene
	#	"marker1": marker1.global_position,
	#	"marker2": marker2.global_position,
		#"marker3": marker3.global_position,
		#"marker4": marker4.global_position,
		#"marker5": marker5.global_position,
		#"marker6": marker6.global_position
		
	#}
	
	if Global.route_status == "True":
		if Global.alyra_dead == true:
			sequence = [
			#{"type": "move_player", "name": "marker1",  "duration": 0.1, "animation": "run", "wait": false},
			#{"type": "player_face", "direction": -1}, #1 is right, -1 is left
			{"type": "wait", "duration": 0.5},
			{"type": "fade_out", "wait": false},
			
			{"type": "dialog", "name": "timeline19T", "wait": true},

			
			{"type": "wait", "duration": 0.1},		
			{"type": "fade_in"},
			#{"type": "animation", "name": "anim3", "wait": false, "loop": false},
			

			]
			#Dialogic.start("timeline19T", false)
		else:
			sequence = [
			#{"type": "move_player", "name": "marker1",  "duration": 0.1, "animation": "run", "wait": false},
			#{"type": "player_face", "direction": -1}, #1 is right, -1 is left
			{"type": "wait", "duration": 0.5},
			{"type": "fade_out", "wait": false},
			
			{"type": "dialog", "name": "timeline19TV2", "wait": true},

			
			{"type": "wait", "duration": 0.1},		
			{"type": "fade_in"},
			#{"type": "animation", "name": "anim3", "wait": false, "loop": false},
			

			]
	elif Global.route_status == "Pacifist":
		if Global.alyra_dead == true:
			sequence = [
				#{"type": "move_player", "name": "marker1",  "duration": 0.1, "animation": "run", "wait": false},
				#{"type": "player_face", "direction": -1}, #1 is right, -1 is left
				{"type": "wait", "duration": 0.5},
				{"type": "fade_out", "wait": false},
				
				{"type": "dialog", "name": "timeline19TP", "wait": true},

				
				{"type": "wait", "duration": 0.1},		
				{"type": "fade_in"},
				#{"type": "animation", "name": "anim3", "wait": false, "loop": false},
				

				]
			#Dialogic.start("timeline19TP", false)
			Global.persistent_saved_lux = true
			Global.check_100_percent_completion()
			Global.save_persistent_data()
		else:
			sequence = [
				#{"type": "move_player", "name": "marker1",  "duration": 0.1, "animation": "run", "wait": false},
				#{"type": "player_face", "direction": -1}, #1 is right, -1 is left
				{"type": "wait", "duration": 0.5},
				{"type": "fade_out", "wait": false},
				
				{"type": "dialog", "name": "timeline19TPV2", "wait": true},

				
				{"type": "wait", "duration": 0.1},		
				{"type": "fade_in"},
				#{"type": "animation", "name": "anim3", "wait": false, "loop": false},
				

				]
			#Dialogic.start("timeline19TP", false)
			Global.persistent_saved_lux = true
			Global.check_100_percent_completion()
			Global.save_persistent_data()

		#Dialogic.start("timeline10v2", false)

		#Dialogic.start("timeline10", false)

	# Simple sequence: just play dialog


func _on_cutscene_start():
	print("Cutscene1boss: Starting")
	# Player reference is already stored in _player_ref by parent class
	if _player_ref:
		player_in_range = _player_ref
		print("Cutscene1: Player reference stored: ", player_in_range.name)

func _on_cutscene_end():
	print("Cutscene1boss: Finished")
	#nataly.visible = false
	#maya.visible = false
	#fini.visible = false
	#sterling.visible = false
	Global.attacking = false
	Global.is_cutscene_active = false

	Global.timeline = 9
	if player_in_range:
		transition_manager.travel_to(player_in_range, target_room, target_spawn)




	
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
