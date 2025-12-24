extends Area2D

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
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var spawn_point: Marker2D = $SpawnPoint
@onready var boss_camera: Camera2D = $BossCamera
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
# ---------------------------------------------------------
# READY
# ---------------------------------------------------------
func _ready() -> void:
	_deactivate_barriers()

	if health_timer:
		health_timer.one_shot = false
		if not health_timer.timeout.is_connected(_on_health_timer_timeout):
			health_timer.timeout.connect(_on_health_timer_timeout)

	if boss_camera:
		boss_camera.enabled = false

# ---------------------------------------------------------
# TRIGGER CONDITIONS (IMPORTANT)
# ---------------------------------------------------------
func _can_start_cutscene() -> bool:
	return (
		not has_been_triggered
		and not battle_active
		and Global.timeline == 8
		and (Global.route_status == "True" or Global.route_status == "Pacifist")
	)

# ---------------------------------------------------------
# AREA ENTER
# ---------------------------------------------------------
func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return

	if not _can_start_cutscene():
		return

	has_been_triggered = true
	battle_active = true
	player_in_range = body

	# HARD disable immediately
	collision_shape.set_deferred("disabled", true)

	if Global.route_status == "Pacifist":
		_start_pacifist_cutscene()
	else:
		_start_true_route_battle()

# ---------------------------------------------------------
# PACIFIST ROUTE (NO BOSS)
# ---------------------------------------------------------
func _start_pacifist_cutscene() -> void:
	Global.is_cutscene_active = true

	Dialogic.start(pacifist_timeline)
	await Dialogic.timeline_ended

	Global.is_cutscene_active = false
	Global.timeline = 9
	Global.persistent_saved_lux = true
	Global.check_100_percent_completion()
	Global.save_persistent_data()

	if player_in_range:
		transition_manager.travel_to(player_in_range, target_room, target_spawn)

	battle_active = false

# ---------------------------------------------------------
# TRUE ROUTE – INTRO
# ---------------------------------------------------------
func _start_true_route_battle() -> void:
	battle_cancelled = false
	Global.is_cutscene_active = true

	_activate_barriers()
	_switch_to_boss_camera()

	Dialogic.start(intro_timeline_true)
	if Dialogic.timeline_ended.is_connected(_on_intro_finished):
		Dialogic.timeline_ended.disconnect(_on_intro_finished)
	Dialogic.timeline_ended.connect(_on_intro_finished)
		


	#await Dialogic.timeline_ended


func _on_intro_finished(_name = ""):
	if battle_cancelled:
		return
	Global.is_cutscene_active = false
	Dialogic.clear(Dialogic.ClearFlags.FULL_CLEAR)
	
	if Dialogic.timeline_ended.is_connected(_on_intro_finished):
		Dialogic.timeline_ended.disconnect(_on_intro_finished)

	#await get_tree().process_frame
	_spawn_boss()

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
# SUCCESS
# ---------------------------------------------------------
func _finalize_success() -> void:
	_cleanup_battle()

	Global.timeline = 9
	Global.is_cutscene_active = false

	if player_in_range:
		transition_manager.travel_to(player_in_range, target_room, target_spawn)

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
	
