extends Area2D

var _has_been_triggered: bool = false
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@export var play_only_once: bool = true

# Called when the node enters the scene tree for the first time.
func _ready():
	pass



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_body_entered(body):
	#print("Player position: ",player_node_ref.global_position)
	if Global.magus_form or Global.cyber_form:
		pass
	else:
		if (body.is_in_group("player") and not _has_been_triggered):  #and Global.cutscene_finished1 == false:
			print("Player entered cutscene trigger area. Starting cutscene.")

			#if collision_shape:
			#	collision_shape.set_deferred("disabled", true)
			#else:
			#	printerr("Cutscene Area2D: WARNING: CollisionShape2D is null, cannot disable it. Using Area2D monitoring instead.")
			#	set_deferred("monitorable", false)
			#	set_deferred("monitoring", false)

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
			Dialogic.start("timeline1_5", false)


func _on_dialogic_finished(_timeline_name = ""):
	print("CutsceneManager: Dialogic timeline finished. Initiating fade out.")
	# Dialog is done. Now, fade out the black screen.

	Global.is_cutscene_active = false
	
	Dialogic.clear(Dialogic.ClearFlags.FULL_CLEAR)
	
	# Disconnect the signal to prevent unintended calls.
	if Dialogic.timeline_ended.is_connected(_on_dialogic_finished):
		Dialogic.timeline_ended.disconnect(_on_dialogic_finished)







func _on_body_exited(body):
	pass # Replace with function body.
