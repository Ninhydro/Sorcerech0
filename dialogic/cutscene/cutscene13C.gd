extends MasterCutscene

#var _has_been_triggered: bool = false
#@onready var collision_shape: CollisionShape2D = $CollisionShape2D
#@export var play_only_once: bool = true



var target_room = "Room_AerendaleJunkyard"     # Name of the destination room (node or scene)
var target_spawn = "Spawn_ToMaya"    # Name of the spawn marker in the target room

var player_in_range = null

@onready var transition_manager = get_node("/root/TransitionManager")


@onready var maya: Sprite2D = $Maya
@onready var nataly: Sprite2D = $Nataly


@onready var marker1: Marker2D = $Marker2D
@onready var marker2: Marker2D = $Marker2D2

# Called when the node enters the scene tree for the first time.


func _on_body_entered(body):
	print("Cutscene13c: Body entered - ", body.name if body else "null")
	
	# Check if timeline condition is met
	if Global.timeline == 6.5 and Global.exactlyion_two == false and body.is_in_group("player"):
		print("Cutscene13c: Conditions met, calling parent method")
		# Store player reference first
		player_in_range = body
		# Call parent's _on_body_entered
		#betael.visible = true
		#maya.visible = false
		
		_setup_cutscene()
		super._on_body_entered(body)
	else:
		print("Cutscene13c: Conditions not met. Global.timeline = ", Global.timeline, ", is_player = ", body.is_in_group("player") if body else "false")


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	if Global.timeline == 2:
#		collision_shape.disabled = false
#	else:
#		collision_shape.disabled = true


func _setup_cutscene():
	cutscene_name = "Cutscene13c"
	maya.visible = false
	nataly.visible = false
	play_only_once = true
	area_activation_flag = ""  # No flag required
	global_flag_to_set = ""  # We'll handle this manually
	
	# IMPORTANT: Make sure your scene has these Marker2D nodes or set positions manually
	player_markers = {
		# Example positions - adjust to match your scene
		"marker1": marker1.global_position,
		"marker2": marker2.global_position
	}
	
	# Simple sequence: just play dialog
	#if Global.alyra_dead == false:
	#		Dialogic.start("timeline12V2", false) #alive alive

	#	elif Global.alyra_dead == true:
	#		Dialogic.start("timeline12", false) #alive dead
	#if Global.demo == true:
	sequence = [
		{"type": "wait", "duration": 0.5},
		{"type": "fade_out", "wait": false},
		#{"type": "player_face", "direction": -1},
		#{"type": "move_player", "name": "marker2", "duration": 3, "animation": "run",  "wait": false},
		{"type": "animation", "name": "anim1", "wait": true, "loop": false},
		{"type": "player_animation", "name": "idle",  "wait": false},
		{"type": "animation", "name": "anim1_idle", "wait": false, "loop": true},
		{"type": "dialog", "name": "timeline14C", "wait": true},
		#{"type": "fade_in", "wait": true},
		#{"type": "animation", "name": "anim2_out", "wait": false, "loop": false},
		{"type": "wait", "duration": 0.5},	
		{"type": "fade_in"},
		
		#{"type": "fade_out"}
		]
			#Dialogic.start("Demo_end", false) #alive dead

				

func _on_cutscene_start():
	print("Cutscene13c: Starting")
	# Player reference is already stored in _player_ref by parent class
	if _player_ref:
		player_in_range = _player_ref
		print("Cutscene13c: Player reference stored: ", player_in_range.name)

func _on_cutscene_end():
	print("Cutscene13c: Finished")
	Global.timeline = 6.5
	Global.exactlyion_two = true
	


# Called every frame. 'delta' is the elapsed time since the previous frame.




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
