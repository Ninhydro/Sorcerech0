extends MasterCutscene

#var _has_been_triggered: bool = false
#@onready var collision_shape: CollisionShape2D = $CollisionShape2D
#@export var play_only_once: bool = true

var target_room1 = "Room_AerendaleJunkyard"     # Name of the destination room (node or scene)
var target_spawn1 = "Spawn_Minigame"    # Name of the spawn marker in the target room

@onready var marker1: Marker2D = $Marker2D
@onready var marker2: Marker2D = $Marker2D2

@onready var cutscene_marker1: Marker2D = $CutsceneMarker1
@onready var cutscene_marker2: Marker2D = $CutsceneMarker2

var player_in_range = null


@onready var maya: Sprite2D =$"Maya kid"
@onready var alyra: Sprite2D = $Alyra
@onready var varek: Sprite2D = $Varek_soldier

@onready var transition_manager = get_node("/root/TransitionManager")

# Called when the node enters the scene tree for the first time.
#func _ready():
#	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	if Global.timeline == 3:
#		collision_shape.disabled = false
#	else:
#		collision_shape.disabled = true

func _on_body_entered(body):
	print("Cutscene1: Body entered - ", body.name if body else "null")
	
	# Check if timeline condition is met
	if Global.timeline == 3 and body.is_in_group("player"):
		print("Cutscene1: Conditions met, calling parent method")
		# Store player reference first
		player_in_range = body
		# Call parent's _on_body_entered
		#betael.visible = true
		#maya.visible = false
		super._on_body_entered(body)
	else:
		print("Cutscene1: Conditions not met. Global.timeline = ", Global.timeline, ", is_player = ", body.is_in_group("player") if body else "false")
		
func _setup_cutscene():
	cutscene_name = "Cutscene3"
	alyra.visible = false
	maya.visible = false
	varek.visible = false
	play_only_once = true
	area_activation_flag = ""  # No flag required
	global_flag_to_set = ""  # We'll handle this manually
	
	# IMPORTANT: Make sure your scene has these Marker2D nodes or set positions manually
	player_markers = {
		# Example positions - adjust to match your scene
		"marker1": marker1.global_position,
		"marker2": marker2.global_position
	}
	
	cutscene_markers = {
		"cutscene_marker1": cutscene_marker1.global_position,
		"cutscene_marker2": cutscene_marker2.global_position
	}
	
	
	# Simple sequence: just play dialog
	sequence = [
		{"type": "wait", "duration": 0.5},
		{"type": "fade_out", "wait": false},
		#{"type": "player_face", "direction": -1},
		#{"type": "move_player", "name": "marker2", "duration": 3, "animation": "run",  "wait": false},
		#{"type": "animation", "name": "anim1", "wait": true, "loop": false},
		#{"type": "player_animation", "name": "idle",  "wait": false},
		#{"type": "animation", "name": "anim1_idle", "wait": false, "loop": true},
		{"type": "dialog", "name": "timeline4", "wait": true},
		{"type": "move_cutscene", "name": "cutscene_marker1", "duration": 2.0, "wait": true},
		#Move the whole cutscene  new marker2d (new function)
		#{"type": "fade_in", "wait": true},
		#{"type": "animation", "name": "anim2_out", "wait": false, "loop": false},
		{"type": "wait", "duration": 0.5},		
		{"type": "fade_in"},
		

	]

func _on_cutscene_start():
	print("Cutscene1: Starting")
	# Player reference is already stored in _player_ref by parent class
	if _player_ref:
		player_in_range = _player_ref
		print("Cutscene1: Player reference stored: ", player_in_range.name)

func _on_cutscene_end():
	print("Cutscene1: Finished")
	
	# Set timeline
	Global.timeline = 3.5
	Global.add_quest_marker("Explore Tromarvelia", Vector2(-3664,-48))
	Global.add_quest_marker("Explore Exactlyion", Vector2(6256,-32))
	#if player_in_range:
	#		transition_manager.travel_to(player_in_range, target_room1, target_spawn1)
	#var minigame = get_tree().get_first_node_in_group("sorting_minigame")
	#if minigame:
	#	minigame.start_game()
		
	print("Cutscene1: Set Global.timeline = ", Global.timeline)
	
#func _on_body_entered(body):
	#print("Player position: ",player_node_ref.global_position)
#	if (body.is_in_group("player") and not _has_been_triggered):  #and Global.cutscene_finished1 == false:
#		print("Player entered cutscene trigger area. Starting cutscene.")

#		if collision_shape:
#			collision_shape.set_deferred("disabled", true)
#		else:
#			printerr("Cutscene Area2D: WARNING: CollisionShape2D is null, cannot disable it. Using Area2D monitoring instead.")
#			set_deferred("monitorable", false)
#			set_deferred("monitoring", false)

		#start_cutscene(cutscene_animation_name_to_play, 0.0)

#		if play_only_once:
#			_has_been_triggered = true
			

#		Global.is_cutscene_active = true
		#Global.cutscene_name = cutscene_animation_name
		#Global.cutscene_playback_position = start_position
		#Dialogic.start("timeline1", false)
#		if Dialogic.timeline_ended.is_connected(_on_dialogic_finished):
#			Dialogic.timeline_ended.disconnect(_on_dialogic_finished)
#		Dialogic.timeline_ended.connect(_on_dialogic_finished)


#		Dialogic.start("timeline4", false)


#func _on_dialogic_finished(_timeline_name = ""):
	#print("CutsceneManager: Dialogic timeline finished. Initiating fade out.")
	# Dialog is done. Now, fade out the black screen.

#	Global.is_cutscene_active = false
	
#	Dialogic.clear(Dialogic.ClearFlags.FULL_CLEAR)
	
	# Disconnect the signal to prevent unintended calls.
#	if Dialogic.timeline_ended.is_connected(_on_dialogic_finished):
#		Dialogic.timeline_ended.disconnect(_on_dialogic_finished)



#	Global.timeline = 3.5
#	Global.add_quest_marker("Explore Tromarvelia", Vector2(-3664,-48))
#	Global.add_quest_marker("Explore Exactlyion", Vector2(6256,-32))



#func _on_body_exited(body):
#	pass # Replace with function body.
