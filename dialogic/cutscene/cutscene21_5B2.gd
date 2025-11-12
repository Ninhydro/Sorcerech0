extends Area2D

var _has_been_triggered: bool = false
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@export var play_only_once: bool = true


var target_room0 = "Room_TromarveliaCastle"     # Name of the destination room (node or scene)
var target_spawn0 = "Spawn_FromTBattlefield"    # Name of the spawn marker in the target room

var target_room1 = "Room_TromarveliaBattlefield"     # Name of the destination room (node or scene)
var target_spawn1 = "Spawn_FromTromarveliaTown"   # Name of the spawn marker in the target room



@onready var door = $Label

var player_in_range = null

@onready var transition_manager = get_node("/root/TransitionManager")

# Called when the node enters the scene tree for the first time.
func _ready():
	collision_shape.disabled = false

func _process(delta):
	if Global.timeline == 10:
		collision_shape.disabled = false
	else:
		collision_shape.disabled = true


func _on_body_entered(body):
	#print("Player position: ",player_node_ref.global_position)
	if body.name == "Player" and  not _has_been_triggered:  #and Global.cutscene_finished1 == false:
		player_in_range = body
		print("Player entered cutscene trigger area. Starting cutscene.")



		#start_cutscene(cutscene_animation_name_to_play, 0.0)

		#if play_only_once:
		#	_has_been_triggered = true
			

		Global.is_cutscene_active = true
		#Global.cutscene_name = cutscene_animation_name
		#Global.cutscene_playback_position = start_position
		#Dialogic.start("timeline1", false)
		if Dialogic.timeline_ended.is_connected(_on_dialogic_finished):
			Dialogic.timeline_ended.disconnect(_on_dialogic_finished)
		Dialogic.timeline_ended.connect(_on_dialogic_finished)

	# Start your dialog timeline.
		Dialogic.start("timeline21TB3", false)


func _on_dialogic_finished(_timeline_name = ""):
	print("CutsceneManager: Dialogic timeline finished. Initiating fade out.")
	# Dialog is done. Now, fade out the black screen.

	Global.is_cutscene_active = false
	
	Dialogic.clear(Dialogic.ClearFlags.FULL_CLEAR)
	
	# Disconnect the signal to prevent unintended calls.
	if Dialogic.timeline_ended.is_connected(_on_dialogic_finished):
		Dialogic.timeline_ended.disconnect(_on_dialogic_finished)



	if Global.timeline == 10:
		if Global.teleport_last == 2.1:
			if player_in_range:
				transition_manager.travel_to(player_in_range, target_room0, target_spawn0)
		elif Global.teleport_last == 2.2:
			if player_in_range:
				transition_manager.travel_to(player_in_range, target_room1, target_spawn1)
		elif Global.teleport_last == 2.3:
			pass


func _on_body_exited(body):
	player_in_range = null
