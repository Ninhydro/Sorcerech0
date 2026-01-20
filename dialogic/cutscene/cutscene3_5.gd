extends MasterCutscene

#var _has_been_triggered: bool = false
#@onready var collision_shape: CollisionShape2D = $CollisionShape2D
#@export var play_only_once: bool = true

var target_room0 = "Room_TromarveliaTown"     # Name of the destination room (node or scene)
var target_spawn0 = "Spawn_FromABattlefield"   # Name of the spawn marker in the target room

var target_room1 = "Room_ExactlyionTown"     # Name of the destination room (node or scene)
var target_spawn1 = "Spawn_FromABattlefield"    # Name of the spawn marker in the target room

var player_in_range = null

@onready var transition_manager = get_node("/root/TransitionManager")

@onready var alyra: Sprite2D = $Alyra
@onready var varek: Sprite2D = $Varek_soldier

# Called when the node enters the scene tree for the first time.
#func _ready():
#	pass


func _on_body_entered(body):
	print("Cutscene1: Body entered - ", body.name if body else "null")
	
	# Check if timeline condition is met
	if Global.timeline == 3.5 and body.is_in_group("player"):
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
	varek.visible = false
	play_only_once = true
	area_activation_flag = ""  # No flag required
	global_flag_to_set = ""  # We'll handle this manually
	
	# IMPORTANT: Make sure your scene has these Marker2D nodes or set positions manually

	
	
	# Simple sequence: just play dialog
	sequence = [
		{"type": "wait", "duration": 0.5},
		{"type": "fade_out", "wait": false},
		
		{"type": "player_face", "direction": 1}, #1 is right, -1 is left
		{"type": "player_animation", "name": "idle",  "wait": false},
		{"type": "animation", "name": "anim1", "wait": true, "loop": false},
		{"type": "animation", "name": "anim1_idle", "wait": false, "loop": true},
		{"type": "dialog", "name": "timeline4_5", "wait": true},
		
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
	alyra.visible = false
	varek.visible = false
	# Set timeline
	Global.timeline = 4
	if Global.teleport_first == 0.0:
		if player_in_range:
			transition_manager.travel_to(player_in_range, target_room0, target_spawn0)
	elif Global.teleport_first == 1.0:
		if player_in_range:
			transition_manager.travel_to(player_in_range, target_room1, target_spawn1)
	#if player_in_range:
	#		transition_manager.travel_to(player_in_range, target_room1, target_spawn1)
	#var minigame = get_tree().get_first_node_in_group("sorting_minigame")
	#if minigame:
	#	minigame.start_game()
		
	print("Cutscene1: Set Global.timeline = ", Global.timeline)
# Called every frame. 'delta' is the elapsed time since the previous frame.

