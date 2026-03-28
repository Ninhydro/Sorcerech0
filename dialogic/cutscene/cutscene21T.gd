extends MasterCutscene

#var _has_been_triggered: bool = false
#@onready var collision_shape: CollisionShape2D = $CollisionShape2D
#@export var play_only_once: bool = false

@onready var interaction_label = $Label 

var target_room = "Room_AerendaleTown"     # Name of the destination room (node or scene)
var target_spawn = "Spawn_FromJunkyard"    # Name of the spawn marker in the target room



var player_in_range = null

@onready var transition_manager = get_node("/root/TransitionManager")

@onready var nataly: Sprite2D = $Nataly
@onready var maya: Sprite2D = $Maya
@onready var lux: Sprite2D = $Lux

@onready var anim_lux: AnimationPlayer = $Lux/AnimationPlayer
@onready var anim_nataly: AnimationPlayer = $Nataly/AnimationPlayer
@onready var anim_maya: AnimationPlayer = $Maya/AnimationPlayer

@onready var marker1: Marker2D = $Marker2D
# Called when the node enters the scene tree for the first time.
func _ready():
	interaction_label.visible = false
	#player_in_range = Global.player
	super._ready()


#func _on_body_entered(body):
#	print("Cutscene17: Body entered - ", body.name if body else "null")
	
	# Check if timeline condition is met
#	if Global.timeline == 10 and (Global.route_status == "True" or Global.route_status == "Pacifist") and Global.game_cleared == false and body.is_in_group("player"):
#		print("Cutscene17: Conditions met, calling parent method")
		# Store player reference first
#		player_in_range = body
		# Call parent's _on_body_entered
		#betael.visible = true
		#maya.visible = false
#		_setup_cutscene()
#		super._on_body_entered(body)
#	else:
#		print("Cutscene17: Conditions not met. Global.timeline = ", Global.timeline, ", is_player = ", body.is_in_group("player") if body else "false")


func _on_body_entered(body):
	#print("Player position: ",player_node_ref.global_position)

	interaction_label.visible = true # Show the "Press E to Save" label
	if body.name == "Player":
		player_in_range = body

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if Global.timeline == 10 and (Global.route_status == "True" or Global.route_status == "Pacifist") and Global.game_cleared == false:
		collision_shape.disabled = false			
		if player_in_range and Input.is_action_just_pressed("yes") and not _has_been_triggered:
			#handle_interaction()
			_setup_cutscene()
			start_cutscene(player_in_range)
			nataly.visible = true
			maya.visible = true
			lux.visible = true
			anim_lux.play("idle")
			anim_nataly.play("idle")
			anim_maya.play("idle")
			
	else:
		collision_shape.disabled = true
		
func _setup_cutscene():
	cutscene_name = "Cutscene17"
	#nataly.visible = false
	#maya.visible = false
	#lux.visible = false
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
	#if Global.route_status == "True":
	#		Dialogic.start("timeline28T", false)
	#elif Global.route_status == "Pacifist":
	#		Dialogic.start("timeline28TP", false)
	if Global.route_status == "True":
			sequence = [
			{"type": "wait", "duration": 0.5},
			{"type": "fade_out", "wait": false},
			
			#{"type": "player_face", "direction": 1}, #1 is right, -1 is left
			{"type": "player_animation", "name": "idle",  "wait": false},
			#{"type": "animation", "name": "anim1", "wait": true, "loop": false},
			#{"type": "animation", "name": "anim1_idle", "wait": false, "loop": true},
			
			{"type": "dialog", "name": "timeline28T", "wait": true},
			
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
		#	{"type": "animation", "name": "anim1p_idle", "wait": true, "loop": false},
			
			#{"type": "dialog", "name": "timeline19TP_1", "wait": true},{"type": "animation", "name": "anim1_idle", "wait": false, "loop": true},
			{"type": "dialog", "name": "timeline28TP", "wait": true},
			
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
	#Global.timeline = 10
	#Global.remove_quest_marker("Find the the other way with Lux")
	nataly.visible = false
	maya.visible = false
	lux.visible = false
	Global.timeline = 10
	if Global.game_cleared == true:
		var main_menu_scene_path = "res://scenes/ui/MainMenu.tscn"
		var main_menu_packed_scene = load(main_menu_scene_path)
		if Global.route_status == "True":
			Global.ending_true = true
			Global.persistent_ending_true = true
			Global.check_100_percent_completion()
			Global.save_persistent_data()
			get_tree().change_scene_to_packed(main_menu_packed_scene)
		elif Global.route_status == "Pacifist":
			Global.ending_pacifist = true
			Global.persistent_ending_pacifist = true
			Global.check_100_percent_completion()
			Global.save_persistent_data()
			get_tree().change_scene_to_packed(main_menu_packed_scene)
	elif Global.game_cleared == false:
		pass


#func handle_interaction():
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


		#MIGHT NEED TO MAKE DIFFERENT ANIMATION CUTSCENE FOR DIFFERENT CHOICE OPTIONS
		#Put different dialog timeline17 on animation also later
	
#		if Global.route_status == "True":
#			Dialogic.start("timeline28T", false)
#		elif Global.route_status == "Pacifist":
#			Dialogic.start("timeline28TP", false)
			

	


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
