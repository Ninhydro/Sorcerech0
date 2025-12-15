extends Area2D

@export var gigaster_scene: PackedScene
@export var boss_barriers: Array[NodePath] = []

@export var intro_timeline := "timeline20M"
@export var outro_timeline := "timeline20_5M"

@export var target_room := "Room_Restart"
@export var target_spawn := "Spawn_FromReality"

@onready var spawn_point: Marker2D = $SpawnPoint
@onready var boss_camera: Camera2D = $BossCamera
#@onready var boss_timer: Timer = $Timer_BossFail
@onready var health_spawn_marker: Marker2D = $HealthSpawnMarker
@export var health_pickup_scene: PackedScene = preload("res://scenes/objects/health_pickup.tscn")
@onready var health_timer: Timer = $Timer_HealthPickup
var current_health_pickup: Node2D = null

@onready var transition_manager = get_node("/root/TransitionManager")

var boss_instance: Node = null
var player_in_range: Node = null

var previous_player_camera: Camera2D = null

var battle_active := false
var battle_cancelled_on_player_death := false


# ---------------------------------------------------------
# AREA ENTER
# ---------------------------------------------------------

func _ready() -> void:
	_deactivate_barriers()

	if health_timer:
		health_timer.one_shot = false
		health_timer.wait_time = 60.0  # health drop every 30 seconds
		if not health_timer.timeout.is_connected(_on_health_timer_timeout):
			health_timer.timeout.connect(_on_health_timer_timeout)
	
	if boss_camera:
		boss_camera.add_to_group("gigaster_boss_camera")
		
func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return

	player_in_range = body

	if _can_start_cutscene():
		_start_intro_cutscene()

# ---------------------------------------------------------
func _can_start_cutscene() -> bool:
	return (
		Global.timeline == 8.8
		and Global.route_status == "Magus"
		and not battle_active
	)

# ---------------------------------------------------------
# INTRO CUTSCENE
# ---------------------------------------------------------
func _start_intro_cutscene() -> void:
	battle_active = true
	battle_cancelled_on_player_death = false
	Global.is_cutscene_active = true

	_activate_barriers()
	_switch_to_boss_camera()

	Dialogic.start(intro_timeline)
	await Dialogic.timeline_ended

	if battle_cancelled_on_player_death:
		return
	
	_spawn_gigaster()

# ---------------------------------------------------------
# BOSS SPAWN
# ---------------------------------------------------------
func _spawn_gigaster() -> void:
	print("GigasterCutscene: Attempting to spawn boss...")
	if not gigaster_scene:
		push_error("Gigaster scene not assigned!")
		return
	if not spawn_point:
		push_error("Spawn point not found!")
		return
	
	Global.is_cutscene_active = false
	Global.health = Global.health_max
	if is_instance_valid(Global.player):
		Global.player.health_changed.emit(Global.health, Global.health_max)
	
	print("GigasterCutscene: Instantiating boss scene")
	boss_instance = gigaster_scene.instantiate()
	get_tree().current_scene.add_child(boss_instance)
	print("GigasterCutscene: Boss added to scene tree")
	
	boss_instance.global_position = spawn_point.global_position
	print("GigasterCutscene: Boss positioned at: ", boss_instance.global_position)
	
	#add_child(boss_instance)
	boss_instance.tree_exited.connect(_on_boss_died)
	#if boss_instance.has_signal("boss_died"):
	#	print("GigasterCutscene: Connecting to boss_died signal")
	#	boss_instance.connect("boss_died", _on_boss_died)

	
	# Start boss battle
	if boss_instance.has_method("reset_for_battle"):
		print("GigasterCutscene: Calling reset_for_battle")
		boss_instance.reset_for_battle()
	

	if health_timer and not health_timer.is_stopped():
		health_timer.start()

	# Safety: mark this controller so Player can cancel it
	add_to_group("gigaster_boss_cutscene")
	print("GigasterCutscene: Boss spawn complete!")

# ---------------------------------------------------------
# BOSS DEFEATED
# ---------------------------------------------------------
func _on_boss_died() -> void:
	if not battle_active:
		return

	battle_active = false
	Global.is_cutscene_active = true

	Dialogic.start(outro_timeline)
	await Dialogic.timeline_ended

	_finalize_success()

# ---------------------------------------------------------
# SUCCESS FLOW
# ---------------------------------------------------------
func _finalize_success() -> void:
	
	if current_health_pickup and is_instance_valid(current_health_pickup):
		current_health_pickup.queue_free()
		current_health_pickup = null
		
	Global.timeline = 9
	Global.ending_magus = true
	Global.persistent_ending_magus = true
	
	Global.check_100_percent_completion()
	Global.save_persistent_data()
	Global.remove_quest_marker("Fight for the Magus")
	Global.is_cutscene_active = false
	_cleanup_battle()

	if player_in_range:
		transition_manager.travel_to(
			player_in_range,
			target_room,
			target_spawn
		)

# ---------------------------------------------------------
# PLAYER DEATH CANCEL
# ---------------------------------------------------------
func cancel_gigaster_boss_battle_on_player_death() -> void:
	# Call from Player.handle_death()
	if not battle_active:
		return

	print("GigasterCutscene: Battle cancelled due to player death.")

	Global.is_cutscene_active = false
	battle_active = false
	battle_cancelled_on_player_death = true


	if health_timer:
		health_timer.stop()

	if current_health_pickup and is_instance_valid(current_health_pickup):
		current_health_pickup.queue_free()
		current_health_pickup = null

	if boss_instance and is_instance_valid(boss_instance):
		if boss_instance.tree_exited.is_connected(_on_boss_died):
			boss_instance.tree_exited.disconnect(_on_boss_died)
		boss_instance.queue_free()
		boss_instance = null

	_cleanup_battle()

# ---------------------------------------------------------
# CLEANUP
# ---------------------------------------------------------
func _cleanup_battle() -> void:
	_deactivate_barriers()
	_restore_player_camera()
	remove_from_group("gigaster_boss_cutscene")

# ---------------------------------------------------------
# CAMERA HANDLING
# ---------------------------------------------------------
func _switch_to_boss_camera() -> void:
	if player_in_range:
		var player_cam := player_in_range.get_node_or_null("CameraPivot/Camera2D")
		if player_cam:
			previous_player_camera = player_cam
			player_cam.enabled = false

	if boss_camera:
		boss_camera.enabled = true
		boss_camera.make_current()

# ---------------------------------------------------------
func _restore_player_camera() -> void:
	if boss_camera:
		boss_camera.enabled = false

	var player := player_in_range
	if player == null and Global.playerBody:
		player = Global.playerBody

	if player:
		var cam := player.get_node_or_null("CameraPivot/Camera2D")
		if cam:
			cam.enabled = true
			cam.make_current()

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

# ---------------------------------------------------------
func _deactivate_barriers() -> void:
	for path in boss_barriers:
		if has_node(path):
			var b = get_node(path)
			if b is CollisionObject2D:
				b.set_deferred("collision_layer", 0)
				b.set_deferred("collision_mask", 0)
			if b is CanvasItem:
				b.visible = false

func _on_health_timer_timeout() -> void:
	if not battle_active or not Global.playerAlive:
		return

	if current_health_pickup and is_instance_valid(current_health_pickup):
		return

	if not health_pickup_scene:
		printerr("GawrCutscene: health_pickup_scene not assigned!")
		return
	if not health_spawn_marker:
		printerr("GawrCutscene: health_spawn_marker not assigned!")
		return

	var parent := get_parent()
	if parent == null:
		parent = get_tree().current_scene

	current_health_pickup = health_pickup_scene.instantiate()
	parent.add_child(current_health_pickup)

	var spawn_pos := health_spawn_marker.global_position
	spawn_pos.y -= 8
	current_health_pickup.global_position = spawn_pos

	if not current_health_pickup.tree_exited.is_connected(_on_health_pickup_removed):
		current_health_pickup.tree_exited.connect(_on_health_pickup_removed)

	print("GawrCutscene: spawned health pickup at ", current_health_pickup.global_position)


func _on_health_pickup_removed() -> void:
	current_health_pickup = null

