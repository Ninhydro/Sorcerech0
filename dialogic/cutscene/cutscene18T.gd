extends MasterCutscene

# ---------------------------------------------------------
# CONFIG
# ---------------------------------------------------------
@export var boss_scene: PackedScene
@export var boss_barriers: Array[NodePath] = []

@export var intro_timeline_true := "timeline18T"
@export var pacifist_timeline := "timeline18TP"
@export var outro_timeline := "timeline19T"
#@export var outro_timelineP := "timeline19TP" this will be included/combine with timeline18TP

#@export var target_room := "Room_Restart"
#@export var target_spawn := "Spawn_FromReality"

var target_room = "Room_AerendaleTown"     # Name of the destination room (node or scene)
var target_spawn = "Spawn_FromJunkyard"    # Name of the spawn marker in the target room

@export var health_pickup_scene: PackedScene

# ---------------------------------------------------------
# NODES
# ---------------------------------------------------------
#@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var spawn_point: Marker2D = $SpawnPoint
@onready var boss_camera: Camera2D = $Camera2D
@onready var health_spawn_marker: Marker2D = $HealthSpawnMarker
@onready var health_timer: Timer = $HealthTimer

@onready var transition_manager = get_node("/root/TransitionManager")

# ---------------------------------------------------------
# STATE
# ---------------------------------------------------------
var player_in_range: Node = null
var boss_instance: Node = null
var previous_player_camera: Camera2D = null

var battle_active := false
var battle_cancelled := false
var has_been_triggered := false
var current_health_pickup: Node2D = null

var platform_spawner: FallingPlatformSpawner

@export var new_cutscene_path: NodePath

@onready var nataly: Sprite2D = $Nataly
@onready var maya: Sprite2D = $Maya
@onready var lux: Sprite2D = $Lux

@onready var marker1: Marker2D = $Marker2D
@onready var marker2: Marker2D = $Marker2D2
@onready var marker3: Marker2D = $Marker2D3

# ---------------------------------------------------------
# READY
# ---------------------------------------------------------
func _ready() -> void:
	_deactivate_barriers()

	if health_timer:
		health_timer.one_shot = false
		if not health_timer.timeout.is_connected(_on_health_timer_timeout):
			health_timer.timeout.connect(_on_health_timer_timeout)

	#if boss_camera:
	#	boss_camera.enabled = false


	
func _on_body_entered(body):
	print("Cutscene1: Body entered - ", body.name if body else "null")
	
	# Check if timeline condition is met
	if not has_been_triggered and not battle_active and Global.timeline == 8.2 and (Global.route_status == "True" or Global.route_status == "Pacifist") and body.is_in_group("player"):
		print("Cutscene1: Conditions met, calling parent method")
		# Store player reference first
		player_in_range = body
		# Call parent's _on_body_entered
		#betael.visible = true
		#maya.visible = false
		_setup_cutscene()
		super._on_body_entered(body)
	else:
		print("Cutscene1: Conditions not met. Global.timeline = ", Global.timeline, ", is_player = ", body.is_in_group("player") if body else "false")
		
func _setup_cutscene():
	cutscene_name = "Cutscene3"
	nataly.visible = false
	maya.visible = false
	lux.visible = false
	play_only_once = true
	area_activation_flag = ""  # No flag required
	global_flag_to_set = ""  # We'll handle this manually
	
	# IMPORTANT: Make sure your scene has these Marker2D nodes or set positions manually

	player_markers = {
		# Example positions - adjust to match your scene
		"marker1": marker1.global_position,
		"marker2": marker2.global_position,
		"marker3": marker3.global_position,
		#"marker4": marker4.global_position,
		#"marker5": marker5.global_position,
		#"marker6": marker6.global_position
		
	}
	
	if Global.route_status == "Pacifist":
		sequence = [
		{"type": "move_player", "name": "marker1",  "duration": 0.1, "animation": "run", "wait": false},
		{"type": "wait", "duration": 0.5},
		{"type": "fade_out", "wait": false},
		
		{"type": "player_face", "direction": -1}, #1 is right, -1 is left
		{"type": "player_animation", "name": "idle",  "wait": false},
		{"type": "animation", "name": "anim1", "wait": true, "loop": false},
		{"type": "animation", "name": "anim1_idle", "wait": false, "loop": true},
		{"type": "dialog", "name": "timeline18T", "wait": true},
		
		{"type": "move_player", "name": "marker2",  "duration": 0.5, "animation": "jump", "wait": false},
		{"type": "animation", "name": "anim2p", "wait": true, "loop": false},
		{"type": "move_player", "name": "marker3",  "duration": 0.5, "animation": "jump", "wait": false},
		{"type": "animation", "name": "anim2p_idle", "wait": false, "loop": true},
		{"type": "player_animation", "name": "idle",  "wait": false},
		{"type": "player_face", "direction": 1},
		{"type": "dialog", "name": "timeline18TP", "wait": true},
		
		{"type": "wait", "duration": 0.5},		
		{"type": "fade_in"},
		{"type": "animation", "name": "anim3", "wait": false, "loop": false},
		

		]
		#_start_pacifist_cutscene()
	else:
		sequence = [
		{"type": "move_player", "name": "marker1",  "duration": 0.1, "animation": "run", "wait": false},
		{"type": "wait", "duration": 0.5},
		{"type": "fade_out", "wait": false},
		
		{"type": "player_face", "direction": -1}, #1 is right, -1 is left
		{"type": "player_animation", "name": "idle",  "wait": false},
		{"type": "animation", "name": "anim1", "wait": true, "loop": false},
		{"type": "animation", "name": "anim1_idle", "wait": false, "loop": true},
		{"type": "dialog", "name": "timeline18T", "wait": true},
		
		{"type": "animation", "name": "anim2", "wait": true, "loop": false},
		
		{"type": "wait", "duration": 0.5},		
		{"type": "fade_in"},
		{"type": "animation", "name": "anim3", "wait": false, "loop": false},
		

		]
		#_start_true_route_battle()
	# Simple sequence: just play dialog


func _on_cutscene_start():
	print("Cutscene1: Starting")
	# Player reference is already stored in _player_ref by parent class
	if _player_ref:
		player_in_range = _player_ref
		print("Cutscene1: Player reference stored: ", player_in_range.name)

func _on_cutscene_end():
	print("Cutscene1: Finished")
	nataly.visible = false
	maya.visible = false
	lux.visible = false
	if Global.route_status == "Pacifist":
		#_start_pacifist_cutscene()
		Global.timeline = 8.5
		Global.persistent_saved_lux = true
		Global.check_100_percent_completion()
		Global.save_persistent_data()

		if player_in_range:
			transition_manager.travel_to(player_in_range, target_room, target_spawn)

		battle_active = false
	
	else:
		#_start_true_route_battle()
		
		battle_active = true
		_activate_barriers()
	#battle_cancelled_on_player_death = false
		Global.timeline = 8.5
		Global.health = Global.health_max
		Global.player.health_changed.emit(Global.health, Global.health_max)
	
		_spawn_boss()
	#_switch_to_boss_camera()
	
	#_spawn_magus_king()
		health_timer.start()
	#Global.timeline = 7
	#Global.add_quest_marker("Make decision at Maya's house", Vector2(-1352, 2264))
	#if player_in_range:
	#		transition_manager.travel_to(player_in_range, target_room1, target_spawn1)
	#var minigame = get_tree().get_first_node_in_group("sorting_minigame")
	#if minigame:
	#	minigame.start_game()
		
	print("Cutscene1: Set Global.timeline = ", Global.timeline)


# ---------------------------------------------------------
# TRIGGER CONDITIONS (IMPORTANT)
# ---------------------------------------------------------


# ---------------------------------------------------------
# BOSS SPAWN
# ---------------------------------------------------------
func _spawn_boss() -> void:
	
	
	Global.is_cutscene_active = false

	Global.health = Global.health_max
	Global.player.health_changed.emit(Global.health, Global.health_max)

	boss_instance = boss_scene.instantiate()
	boss_instance.global_position = spawn_point.global_position
	get_tree().current_scene.add_child.call_deferred(boss_instance)

	if boss_instance.has_signal("boss_died"):
		boss_instance.boss_died.connect(_on_boss_died)
	else:
	 # Fallback: connect to tree_exiting
		boss_instance.tree_exiting.connect(_on_boss_died)

	if boss_instance.has_method("reset_for_battle"):
		boss_instance.reset_for_battle()

	health_timer.start()
	
	var all_spawners = get_tree().get_nodes_in_group("falling_platform_spawner")
	print("=== BOSS: Found ", all_spawners.size(), " platform spawners ===")
	
	# Configure each spawner with different delays
	var delay = 0.0
	for i in range(all_spawners.size()):
		var spawner = all_spawners[i]
		spawner.spawner_id = "Spawner" + str(i+1)
		spawner.start_delay = delay
		delay += 1.0  # Stagger starts by 1 second each
		
		print("Starting ", spawner.spawner_id, " with delay: ", spawner.start_delay, "s")
		spawner.start_spawning()
	
	print("=== BOSS: All spawners started ===")
	
	# Test timers after 10 seconds
	await get_tree().create_timer(10.0).timeout
	print("=== BOSS: Testing timers after 10 seconds ===")
	for spawner in all_spawners:
		spawner.test_timer()


	
# ---------------------------------------------------------
# BOSS DEFEATED
# ---------------------------------------------------------
func _on_boss_died() -> void:
	if not battle_active:
		return

	battle_active = false
	#Global.is_cutscene_active = true
	_cleanup_battle()
	#Global.timeline = 9
	#Dialogic.start(outro_timeline)
	#await Dialogic.timeline_ended
	var node_path: NodePath = new_cutscene_path 
	print("finishing battle cutscene1")
	if node_path != NodePath("") and has_node(node_path):
		var cs_node: Node = get_node(node_path)
		print("get nodepath1")
		if cs_node.has_method("start_cutscene2"):
			cs_node.call("start_cutscene2")
			print("get start_cutscene2")
		else:
			if cs_node is CanvasItem:
				cs_node.visible = true
				
	#_finalize_success()

# ---------------------------------------------------------
# SUCCESS
# ---------------------------------------------------------
#func _finalize_success() -> void:
#	_cleanup_battle()

#	Global.timeline = 9
#	Global.is_cutscene_active = false

#	if player_in_range:
#		transition_manager.travel_to(player_in_range, target_room, target_spawn)

# ---------------------------------------------------------
# PLAYER DEATH CANCEL (CALLED FROM PLAYER)
# ---------------------------------------------------------
func cancel_boss_battle_on_player_death() -> void:
	if not battle_active:
		return

	battle_cancelled = true
	battle_active = false
	Global.is_cutscene_active = false

	if health_timer:
		health_timer.stop()

	if current_health_pickup and is_instance_valid(current_health_pickup):
		current_health_pickup.queue_free()

	if boss_instance and is_instance_valid(boss_instance):
		boss_instance.queue_free()

	_cleanup_battle()

# ---------------------------------------------------------
# CLEANUP
# ---------------------------------------------------------
func _cleanup_battle() -> void:
	_deactivate_barriers()
	_restore_player_camera()
	remove_from_group("magus_king_boss_cutscene")

# ---------------------------------------------------------
# CAMERA
# ---------------------------------------------------------
func _switch_to_boss_camera() -> void:
	if player_in_range:
		var cam := player_in_range.get_node_or_null("CameraPivot/Camera2D")
		if cam:
			previous_player_camera = cam
			cam.enabled = false

	boss_camera.enabled = true
	boss_camera.make_current()

func _restore_player_camera() -> void:
	if boss_camera:
		boss_camera.enabled = false

	if previous_player_camera:
		previous_player_camera.enabled = true
		previous_player_camera.make_current()

# ---------------------------------------------------------
# BARRIERS
# ---------------------------------------------------------
func _activate_barriers() -> void:
	for path in boss_barriers:
		if has_node(path):
			var b = get_node(path)
			if b is CollisionObject2D:
				b.set_deferred("collision_layer", 1)
				b.set_deferred("collision_mask", 1)
			if b is CanvasItem:
				b.visible = true

func _deactivate_barriers() -> void:
	for path in boss_barriers:
		if has_node(path):
			var b = get_node(path)
			if b is CollisionObject2D:
				b.set_deferred("collision_layer", 0)
				b.set_deferred("collision_mask", 0)
			if b is CanvasItem:
				b.visible = false

# ---------------------------------------------------------
# HEALTH PICKUP
# ---------------------------------------------------------
func _on_health_timer_timeout() -> void:
	if not battle_active or not Global.playerAlive:
		return

	if current_health_pickup:
		return

	current_health_pickup = health_pickup_scene.instantiate()
	get_tree().current_scene.add_child(current_health_pickup)
	current_health_pickup.global_position = health_spawn_marker.global_position

	current_health_pickup.tree_exited.connect(
		func(): current_health_pickup = null
	)
	
