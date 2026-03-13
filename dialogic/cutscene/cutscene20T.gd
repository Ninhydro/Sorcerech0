extends MasterCutscene

#var _has_been_triggered: bool = false
#@onready var collision_shape: CollisionShape2D = $CollisionShape2D
#@export var play_only_once: bool = true



var target_room = "Room_AerendaleTown"     # Name of the destination room (node or scene)
var target_spawn = "Spawn_FromJunkyard"    # Name of the spawn marker in the target room

var player_in_range = null

@onready var transition_manager = get_node("/root/TransitionManager")

# Called when the node enters the scene tree for the first time.
#func _ready():
#	pass

func _on_body_entered(body):
	print("Cutscene17: Body entered - ", body.name if body else "null")
	
	# Check if timeline condition is met
	if Global.timeline == 9 and (Global.route_status == "True" or Global.route_status == "Pacifist") and body.is_in_group("player"):
		print("Cutscene17: Conditions met, calling parent method")
		# Store player reference first
		player_in_range = body
		# Call parent's _on_body_entered
		#betael.visible = true
		#maya.visible = false
		_setup_cutscene()
		super._on_body_entered(body)
	else:
		print("Cutscene17: Conditions not met. Global.timeline = ", Global.timeline, ", is_player = ", body.is_in_group("player") if body else "false")
		
func _setup_cutscene():
	cutscene_name = "Cutscene17"
	#alyra.visible = false
	#varek.visible = false
	play_only_once = true
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
	if Global.route_status == "True":
			sequence = [
			{"type": "wait", "duration": 0.5},
			{"type": "fade_out", "wait": false},
			
			#{"type": "player_face", "direction": 1}, #1 is right, -1 is left
			{"type": "player_animation", "name": "idle",  "wait": false},
			{"type": "animation", "name": "anim1", "wait": true, "loop": false},
			{"type": "animation", "name": "anim1_idle", "wait": false, "loop": true},
			{"type": "dialog", "name": "timeline20T", "wait": true},
			
			{"type": "wait", "duration": 0.5},		
			{"type": "fade_in"},
			#{"type": "animation", "name": "anim2", "wait": false, "loop": false},
			

			]
			#Dialogic.start("timeline20T", false)
	elif Global.route_status == "Pacifist":
			sequence = [
			{"type": "wait", "duration": 0.5},
			{"type": "fade_out", "wait": false},
			
			#{"type": "player_face", "direction": 1}, #1 is right, -1 is left
			{"type": "player_animation", "name": "idle",  "wait": false},
			{"type": "animation", "name": "anim1", "wait": true, "loop": false},
			{"type": "animation", "name": "anim1_idle", "wait": false, "loop": true},
			{"type": "dialog", "name": "timeline20TP", "wait": true},
			
			{"type": "wait", "duration": 0.5},		
			{"type": "fade_in"},
			#{"type": "animation", "name": "anim2", "wait": false, "loop": false},
			

			]
			#Dialogic.start("timeline20TP", false)
	# Simple sequence: just play dialog


func _on_cutscene_start():
	print("Cutscene17: Starting")
	# Player reference is already stored in _player_ref by parent class
	if _player_ref:
		player_in_range = _player_ref
		print("Cutscene17: Player reference stored: ", player_in_range.name)

func _on_cutscene_end():
	print("Cutscene17: Finished")
	Global.timeline = 10
	Global.remove_quest_marker("Find the the other way with Lux")



	


	
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
