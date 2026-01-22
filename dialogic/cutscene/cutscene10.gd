extends MasterCutscene

#var _has_been_triggered: bool = false
#@onready var collision_shape: CollisionShape2D = $CollisionShape2D
#@export var play_only_once: bool = true

var player_in_range: Node = null

@onready var anim_player: AnimationPlayer = $AnimationPlayer
#@onready var cutscene_camera: Camera2D = $CutsceneCamera2D

# Travel data
@export var target_room: String = "Room_AerendaleJunkyard"
@export var target_spawn: String = "Spawn_ToMaya"

@onready var transition_manager: Node = get_node("/root/TransitionManager")

@onready var alyra: Sprite2D = $Alyra
@onready var varek: Sprite2D = $Varek_soldier
@onready var magus: Sprite2D = $"Magus soldier"


@onready var marker1: Marker2D = $Marker2D

func _ready() -> void:
	super._ready()


func _process(delta: float) -> void:
	# Only active when timeline == 5.3
	if Global.timeline == 5.3:
		collision_shape.disabled = false
	else:
		collision_shape.disabled = true


func _mark_triggered() -> void:
	# Helper so both body_entered & manual start behave the same
	if _has_been_triggered:
		return
	
	_has_been_triggered = true
	
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	else:
		set_deferred("monitorable", false)
		set_deferred("monitoring", false)


#func _on_body_entered(body: Node) -> void:
#	if body.is_in_group("player") and not _has_been_triggered:
#		player_in_range = body
#		print("Player entered FINAL cutscene trigger area.")
#	pass		
#		_mark_triggered()
#		start_cutscene()


func start_cutscene3() -> void:
	player_in_range = Global.player
	_setup_cutscene()
	start_cutscene(player_in_range)
#   final_cutscene_node.start_cutscene()
#func start_cutscene() -> void:

func _setup_cutscene():
	cutscene_name = "cyberbosspart1"
	alyra.visible = false
	varek.visible = false
	magus.visible = false
	play_only_once = true
	area_activation_flag = ""  # No flag required
	global_flag_to_set = ""  # We'll handle this manually
	
	# IMPORTANT: Make sure your scene has these Marker2D nodes or set positions manually

	player_markers = {
		# Example positions - adjust to match your scene
		"marker1": marker1.global_position,
		#"marker2": marker2.global_position,
		#"marker3": marker3.global_position,
		#"marker4": marker4.global_position,
		#"marker5": marker5.global_position,
		#"marker6": marker6.global_position
		
	}
	if Global.alyra_dead == false: # boss dead
		sequence = [
		{"type": "wait", "duration": 0.5},
		{"type": "fade_out", "wait": false},
		
		{"type": "player_face", "direction": -1}, #1 is right, -1 is left
		{"type": "move_player", "name": "marker1",  "duration": 2, "animation": "run", "wait": false},
		{"type": "animation", "name": "anim1v2", "wait": true, "loop": false},
		{"type": "player_animation", "name": "idle",  "wait": false},
		{"type": "animation", "name": "anim1v2_idle", "wait": false, "loop": true},
		{"type": "dialog", "name": "timeline11V2", "wait": true},
		{"type": "animation", "name": "anim2v2", "wait": true, "loop": false},
		#{"type": "animation", "name": "anim2_idle", "wait": false, "loop": true},
		#{"type": "dialog", "name": "timeline10_5", "wait": true},
		
		{"type": "wait", "duration": 0.1},		
		{"type": "fade_in"},
		{"type": "animation", "name": "anim4", "wait": false, "loop": false},
		

		]
		#Dialogic.start("timeline11V2", false)  # Alyra alive route
		#Global.persistent_saved_alyra = true
		#Global.check_100_percent_completion()
		#Global.save_persistent_data()
	else: # boss not dead
		sequence = [
		{"type": "wait", "duration": 0.5},
		{"type": "fade_out", "wait": false},
		
		{"type": "player_face", "direction": -1}, #1 is right, -1 is left
		{"type": "move_player", "name": "marker1",  "duration": 2, "animation": "run", "wait": false},
		{"type": "animation", "name": "anim1", "wait": true, "loop": false},
		{"type": "player_animation", "name": "idle",  "wait": false},
		{"type": "animation", "name": "anim1_idle", "wait": false, "loop": true},
		{"type": "dialog", "name": "timeline11", "wait": true},
		{"type": "animation", "name": "anim2", "wait": true, "loop": false},
		{"type": "animation", "name": "anim2_idle", "wait": false, "loop": true},
		{"type": "dialog", "name": "timeline11_1", "wait": true},
		{"type": "animation", "name": "anim3", "wait": true, "loop": false},
		{"type": "animation", "name": "anim3_idle", "wait": false, "loop": true},
		{"type": "dialog", "name": "timeline11_2", "wait": true},
		
		{"type": "wait", "duration": 0.1},		
		{"type": "fade_in"},
		{"type": "animation", "name": "anim4", "wait": false, "loop": false},
		

		]
		#Dialogic.start("timeline11", false)    # Alyra dead route
		#Global.persistent_alyra_dead = true
		#lobal.check_100_percent_completion()
		#Global.save_persistent_data()
	
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
	alyra.visible = false
	varek.visible = false
	magus.visible = false
	if Global.alyra_dead == false:
		#Dialogic.start("timeline11V2", false)  # Alyra alive route
		Global.persistent_saved_alyra = true
		Global.check_100_percent_completion()
		Global.save_persistent_data()
	else:
		#Dialogic.start("timeline11", false)    # Alyra dead route
		Global.persistent_alyra_dead = true
		Global.check_100_percent_completion()
		Global.save_persistent_data()
	
	Global.timeline = 6

	if player_in_range:
		transition_manager.travel_to(player_in_range, target_room, target_spawn)

	Global.remove_quest_marker("Go back to New Aerendale!")
	Global.persistent_cleared_part_1 = true
	Global.check_100_percent_completion()
	Global.save_persistent_data()
	Global.enable_health_regeneration() 
	Global.health_regeneration_rate = 0.25
	
	# Set timeline
	#start_boss2_battle()
	
	#var tree := get_tree()
	#if tree == null:
	#	print("FinalCutscene: start_cutscene() called but node not in scene tree, ignoring.")
	#	return

	#if _has_been_triggered == false:
	#	_mark_triggered()

	#if player_in_range == null:
	#	var players := tree.get_nodes_in_group("player")
	#	if players.size() > 0:
	#		player_in_range = players[0]
	
	#Global.is_cutscene_active = true

	# Switch to cutscene camera if present
	#if cutscene_camera:
	#	cutscene_camera.make_current()

	# Connect Dialogic finished
	#if Dialogic.timeline_ended.is_connected(_on_dialogic_finished):
	#	Dialogic.timeline_ended.disconnect(_on_dialogic_finished)
	#Dialogic.timeline_ended.connect(_on_dialogic_finished)

	# Choose dialog branch + persistent flags based on Alyra
	#if Global.alyra_dead == false:
	#	Dialogic.start("timeline11V2", false)  # Alyra alive route
	#	Global.persistent_saved_alyra = true
	#	Global.check_100_percent_completion()
	#	Global.save_persistent_data()
	#else:
	#	Dialogic.start("timeline11", false)    # Alyra dead route
	#	Global.persistent_alyra_dead = true
	#	Global.check_100_percent_completion()
	#	Global.save_persistent_data()

	# Optional animation branching
	# if anim_player:
	# 	if Global.alyra_dead == false and anim_player.has_animation("final_alyra_saved"):
	# 		anim_player.play("final_alyra_saved")
	# 	elif Global.alyra_dead == true and anim_player.has_animation("final_alyra_dead"):
	# 		anim_player.play("final_alyra_dead")


func _restore_player_camera() -> void:
	# Try local reference first
	var player := player_in_range
	
	# Fallback to Global.playerBody if set
	if player == null and Global.playerBody:
		player = Global.playerBody
	
	if player:
		var cam: Camera2D = player.get_node_or_null("Camera2D")
		if cam:
			cam.make_current()


#func _on_dialogic_finished(_timeline_name: String = "") -> void:
#	print("FinalCutscene: Dialogic finished. Wrapping up and returning to world.")
	
#	Global.is_cutscene_active = false

#	Dialogic.clear(Dialogic.ClearFlags.FULL_CLEAR)
	
#	if Dialogic.timeline_ended.is_connected(_on_dialogic_finished):
#		Dialogic.timeline_ended.disconnect(_on_dialogic_finished)

	# Always restore the player camera BEFORE traveling
#	_restore_player_camera()

	# Set timeline and original logic
#	Global.timeline = 6

#	if player_in_range:
#		transition_manager.travel_to(player_in_range, target_room, target_spawn)

#	Global.remove_quest_marker("Go back to New Aerendale!")
#	Global.persistent_cleared_part_1 = true
#	Global.check_100_percent_completion()
#	Global.save_persistent_data()
#	Global.enable_health_regeneration() 
#	Global.health_regeneration_rate = 0.25
	# Make absolutely sure this cutscene can NEVER trigger again
	#queue_free()


#func _on_body_exited(body: Node) -> void:
	#pass
