extends MasterCutscene

#var _has_been_triggered: bool = false
#@onready var collision_shape: CollisionShape2D = $CollisionShape2D
#@export var play_only_once: bool = true

var player_in_range: Node = null
var previous_player_camera: Camera2D = null

@onready var transition_manager = get_node("/root/TransitionManager")

# --- Optional camera / intro animation ---
@onready var anim_player: AnimationPlayer = $AnimationPlayer


# Story / route control
var battle_used_fail_route: bool = false


@onready var nataly: Sprite2D = $Nataly
@onready var maya: Sprite2D = $Maya
@onready var lux: Sprite2D = $Lux
@onready var gawr: Node2D = $BodyPivot
@onready var nora: Node2D = $Nora

@onready var marker1: Marker2D = $Marker2D
@onready var marker2: Marker2D = $Marker2D2
@onready var marker3: Marker2D = $Marker2D3
@onready var marker4: Marker2D = $Marker2D4

@onready var cutscene_marker1: Marker2D = $CutsceneMarker1

var target_room := "Room_TromarveliaTown"
var target_spawn := "Spawn_FromTBattlefield"

func _ready() -> void:
	# Only active when Global.timeline == 5.2
	super._ready()

func _process(delta: float) -> void:
	# Enable trigger only on specific timeline
	#if Global.timeline == 6.5:
	#	collision_shape.disabled = false
	#else:
	#	collision_shape.disabled = true
	pass
	
func _on_body_entered(body):
	pass
	
func start_cutscene2() -> void:
	player_in_range = Global.player
	_setup_cutscene()
	start_cutscene(player_in_range)
	# If no player stored (e.g. called directly), try to find one
	#var tree := get_tree()
	#if tree == null:
	#	print("Boss2Cutscene: start_cutscene() called but node not in scene tree, ignoring.")
	#	return

	# If no player stored (e.g. called directly), try to find one
	#if player_in_range == null:
	#	var players := tree.get_nodes_in_group("player")
	#	if players.size() > 0:
	#		player_in_range = players[0]
	#	else:
	#		print("Boss2Cutscene: No player found in group 'player', aborting.")
	#		return
	#Global.is_cutscene_active = true

	# Choose dialog based on Global.first_boss_dead
	#if Dialogic.timeline_ended.is_connected(_on_dialogic_finished):
	#	Dialogic.timeline_ended.disconnect(_on_dialogic_finished)
	#Dialogic.timeline_ended.connect(_on_dialogic_finished)
	
	#if Global.first_boss_dead:
	#	Dialogic.start("timeline10v2", false)
	#else:
	#	Dialogic.start("timeline10", false)

	# Optional: play different animations here:
	# if anim_player:
	#     if Global.first_boss_dead and anim_player.has_animation("intro_alyra_dead"):
	#         anim_player.play("intro_alyra_dead")
	#     elif not Global.first_boss_dead and anim_player.has_animation("intro_alyra_alive"):
	#         anim_player.play("intro_alyra_alive")

func _setup_cutscene():
	cutscene_name = "gawrboss15_6"
	nataly.visible = false
	maya.visible = false
	lux.visible = false
	gawr.visible = false
	nora.visible = false
	play_only_once = true
	area_activation_flag = ""  # No flag required
	global_flag_to_set = ""  # We'll handle this manually
	
	# IMPORTANT: Make sure your scene has these Marker2D nodes or set positions manually

	player_markers = {
		# Example positions - adjust to match your scene
		"marker1": marker1.global_position,
		"marker2": marker2.global_position,
		"marker3": marker3.global_position,
		"marker4": marker4.global_position,
		#"marker5": marker5.global_position,
		#"marker6": marker6.global_position
		
	}
	
	cutscene_markers = {
		"cutscene_marker1": cutscene_marker1.global_position,
		#"cutscene_marker2": cutscene_marker2.global_position
	}
	
	if Global.nora_dead == false:#first boss dead
		# Branch: player directly killed the Replica Fini
		sequence = [
		{"type": "move_player", "name": "marker1",  "duration": 0.1, "animation": "run", "wait": false},
		{"type": "player_face", "direction": 1}, #1 is right, -1 is left
		{"type": "wait", "duration": 0.5},
		{"type": "fade_out", "wait": false},
		
		#{"type": "player_face", "direction": -1}, #1 is right, -1 is left
		#{"type": "move_player", "name": "marker1",  "duration": 2, "animation": "run", "wait": false},
		{"type": "player_animation", "name": "idle",  "wait": false},
		{"type": "move_player", "name": "marker3",  "duration": 4, "animation": "shine", "wait": false},
		{"type": "animation", "name": "anim1", "wait": true, "loop": false},
		{"type": "animation", "name": "anim1_idle", "wait": false, "loop": true},
		#{"type": "dialog", "name": "timeline10v2", "wait": true},
		#{"type": "animation", "name": "anim2v2", "wait": true, "loop": false},
		#{"type": "player_face", "direction": 1},
		#{"type": "player_animation", "name": "attack",  "wait": false},
		#{"type": "animation", "name": "anim2v2_idle", "wait": false, "loop": true},
		{"type": "dialog", "name": "timeline16_5M", "wait": true},
		
		{"type": "player_form", "name": "UltimateMagus", "wait": true},
		{"type": "move_player", "name": "marker1",  "duration": 0.5, "animation": "load", "wait": false},
		#{"type": "player_animation", "name": "save",  "wait": true},
		#{"type": "wait", "duration": 0.5},
		{"type": "wait", "duration": 0.5},
		{"type": "player_animation", "name": "idle", "wait": false},
		
		{"type": "dialog", "name": "timeline16_6M", "wait": true},
		{"type": "animation", "name": "anim2", "wait": false, "loop": false},
		
		{"type": "wait", "duration": 0.1},		
		{"type": "fade_in"},
		{"type": "animation", "name": "anim4", "wait": false, "loop": false},
		#{"type": "animation", "name": "anim3", "wait": false, "loop": false},
		

		]
		#Dialogic.start("timeline10v2", false)
	else: #first boss not dead
		# Branch: player survived timer, didn't kill Replica
		sequence = [
		{"type": "move_player", "name": "marker1",  "duration": 0.1, "animation": "run", "wait": false},
		{"type": "player_face", "direction": 1}, #1 is right, -1 is left
		{"type": "wait", "duration": 0.5}, 
		{"type": "fade_out", "wait": false},
		
		{"type": "player_animation", "name": "idle",  "wait": false},
		{"type": "animation", "name": "anim1v2", "wait": true, "loop": false},
		{"type": "animation", "name": "anim1v2_idle", "wait": false, "loop": true},
		#{"type": "dialog", "name": "timeline10", "wait": true},
		#{"type": "animation", "name": "anim2", "wait": true, "loop": false},
		#{"type": "player_face", "direction": 1},
		#{"type": "player_animation", "name": "attack",  "wait": false},
		#{"type": "animation", "name": "anim2_idle", "wait": false, "loop": true},
		{"type": "dialog", "name": "timeline16_5MV2", "wait": true},
		{"type": "animation", "name": "anim2v2", "wait": false, "loop": false},
		
		{"type": "wait", "duration": 0.1},		
		{"type": "fade_in"},
		
		{"type": "move_cutscene", "name": "cutscene_marker1", "duration": 0.2, "wait": false},
		{"type": "move_player", "name": "marker2",  "duration": 0.1, "animation": "idle", "wait": false},
		{"type": "wait", "duration": 0.5},
		{"type": "fade_out", "wait": false},
		{"type": "player_animation", "name": "idle",  "wait": false},
		{"type": "player_face", "direction": 1},
		{"type": "animation", "name": "anim3v2", "wait": true, "loop": false},
		{"type": "move_player", "name": "marker4",  "duration": 2, "animation": "shine", "wait": false},
		{"type": "animation", "name": "anim3v2_2", "wait": true, "loop": false},
		{"type": "animation", "name": "anim3v2_idle", "wait": false, "loop": false},
		{"type": "dialog", "name": "timeline16_6MV2", "wait": true},
		#{"type": "animation", "name": "anim3", "wait": false, "loop": false},
		
		
		{"type": "player_form", "name": "UltimateMagus", "wait": true},
		{"type": "move_player", "name": "marker2",  "duration": 0.5, "animation": "load", "wait": false},
		#{"type": "player_animation", "name": "save",  "wait": true},
		#{"type": "wait", "duration": 0.5},
		{"type": "wait", "duration": 0.5},
		{"type": "player_animation", "name": "idle", "wait": false},
		
		{"type": "dialog", "name": "timeline16_7MV2", "wait": true},
		{"type": "wait", "duration": 0.1},		
		{"type": "fade_in"},
		{"type": "animation", "name": "anim4", "wait": false, "loop": false},

		]
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
	nataly.visible = false
	maya.visible = false
	lux.visible = false
	gawr.visible = false
	nora.visible = false
	battling_flag = false
	player_in_range.camera.enabled = true
	player_in_range.camera.make_current()
	
	Global.is_cutscene_active = false
	Global.attacking = false
	Global.is_dialog_open = false
	
	if Global.nora_dead == false:#first boss dead
		#Global.ult_magus_form = true
		#Global.gawr_dead = true

		Global.ult_magus_form = true

		if player_in_range and is_instance_valid(player_in_range):
			player_in_range.unlock_and_force_form("UltimateMagus")
		
		Global.health_max += 10
		Global.health = Global.health_max
		Global.player.health_changed.emit(Global.health, Global.health_max)
		
		# transfer player
		if player_in_range and is_instance_valid(player_in_range):
			transition_manager.travel_to(player_in_range, target_room, target_spawn)
	else:
		Global.ult_magus_form = true

		if player_in_range and is_instance_valid(player_in_range):
			player_in_range.unlock_and_force_form("UltimateMagus")
		
		Global.health_max += 10
		Global.health = Global.health_max
		Global.player.health_changed.emit(Global.health, Global.health_max)

		# transfer player
		#if player_in_range and is_instance_valid(player_in_range):
		#	transition_manager.travel_to(player_in_range, target_room, target_spawn)
		
		#cutscene_camera.enabled = true
		#cutscene_camera.make_current()

