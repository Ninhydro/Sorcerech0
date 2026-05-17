extends MasterCutscene

#var _has_been_triggered: bool = false
#@onready var collision_shape: CollisionShape2D = $CollisionShape2D
#@export var play_only_once: bool = true
var player_in_range = null

@onready var transition_manager = get_node("/root/TransitionManager")


@onready var lux: Sprite2D = $Lux
@onready var luxanim: AnimationPlayer = $Lux/AnimationPlayer
# Called when the node enters the scene tree for the first time.

#var lux_encounter = false
@export var maguspos = false 

func _ready():
	luxanim.play("idle")
	if maguspos == true:
		lux.flip_h = true
	elif maguspos == false:
		lux.flip_h = false
	super._ready()
	
func _process(delta):
	if Global.timeline <= 6.5:
		if maguspos == true:
			if Global.lux_encounter_magus == false:
				lux.visible = true
			else:
				lux.visible = false
		elif maguspos == false:
			if Global.lux_encounter_cyber == false:
				lux.visible = true
			else:
				lux.visible = false
	else:
		lux.visible = false
	
	
func _on_body_entered(body):
	print("Cutscene1: Body entered - ", body.name if body else "null")
	#Global.timeline == 6.5
	# Check if timeline condition is met
	if Global.timeline <= 6.5 and body.is_in_group("player"):
		if maguspos == true:
			if Global.lux_encounter_magus == false:
				player_in_range = body
				super._on_body_entered(body)
			else:
				pass
				#lux.visible = false
		elif maguspos == false:
			if Global.lux_encounter_cyber == false:
				player_in_range = body
				super._on_body_entered(body)
			else:
				pass
				#lux.visible = false
				
		#print("Cutscene1: Conditions met, calling parent method")
		# Store player reference first
		#player_in_range = body
		# Call parent's _on_body_entered
		#betael.visible = true
		#maya.visible = false
		#super._on_body_entered(body)
	else:
		print("Cutscene1: Conditions not met. Global.timeline = ", Global.timeline, ", is_player = ", body.is_in_group("player") if body else "false")
		
func _setup_cutscene():
	cutscene_name = "Cutscenelux"

	play_only_once = true
	area_activation_flag = ""  # No flag required
	global_flag_to_set = ""  # We'll handle this manually
	
	# IMPORTANT: Make sure your scene has these Marker2D nodes or set positions manually

	
	if maguspos == true:
	# Simple sequence: just play dialog
		sequence = [
			{"type": "wait", "duration": 0.5},
			{"type": "fade_out", "wait": false},
			
			#{"type": "player_face", "direction": 1}, #1 is right, -1 is left
			{"type": "player_animation", "name": "idle",  "wait": false},
			{"type": "animation", "name": "anim1", "wait": true, "loop": false},
			#{"type": "animation", "name": "anim1_idle", "wait": false, "loop": true},
			#{"type": "dialog", "name": "timeline5C", "wait": true},
			
			{"type": "wait", "duration": 0.5},		
			{"type": "fade_in"},
			{"type": "animation", "name": "anim2", "wait": false, "loop": false},
			

		]
	elif maguspos == false:
	# Simple sequence: just play dialog
		sequence = [
			{"type": "wait", "duration": 0.5},
			{"type": "fade_out", "wait": false},
			
			#{"type": "player_face", "direction": 1}, #1 is right, -1 is left
			{"type": "player_animation", "name": "idle",  "wait": false},
			{"type": "animation", "name": "anim1v2", "wait": true, "loop": false},
			#{"type": "animation", "name": "anim1_idle", "wait": false, "loop": true},
			#{"type": "dialog", "name": "timeline5C", "wait": true},
			
			{"type": "wait", "duration": 0.5},		
			{"type": "fade_in"},
			{"type": "animation", "name": "anim2", "wait": false, "loop": false},
			

		]

func _on_cutscene_start():
	print("Cutscene1: Starting")
	# Player reference is already stored in _player_ref by parent class
	if _player_ref:
		player_in_range = _player_ref
		print("Cutscene1: Player reference stored: ", player_in_range.name)

func _on_cutscene_end():
	print("Cutscene1: Finished")
	if maguspos == true:
		Global.lux_encounter_magus = true
	elif maguspos == false:
		Global.lux_encounter_cyber = true
	lux.visible = false
	Global.attacking= false
	# Set timeline
	#Global.timeline = 4
	#Global.first_exactlyion = true
	#if player_in_range:
	#		transition_manager.travel_to(player_in_range, target_room1, target_spawn1)
	#var minigame = get_tree().get_first_node_in_group("sorting_minigame")
	#if minigame:
	#	minigame.start_game()
		
	print("Cutscene1: Set Global.timeline = ", Global.timeline)

# Called every frame. 'delta' is the elapsed time since the previous frame.

