extends Area2D

@export var magus_king_scene: PackedScene
@export var boss_barriers: Array[NodePath] = []

var _has_been_triggered: bool = false
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@export var play_only_once: bool = true


@export var intro_timeline := "timeline20C"
@export var outro_timeline := "timeline20_5C"

@export var target_room := "Room_Restart"
@export var target_spawn := "Spawn_FromReality"

@onready var spawn_point: Marker2D = $SpawnPoint
@onready var boss_camera: Camera2D = $BossCamera
@onready var health_spawn_marker: Marker2D = $HealthSpawnMarker
@onready var health_timer: Timer = $Timer_HealthPickup

@export var health_pickup_scene: PackedScene

var player_in_range = null

@onready var transition_manager = get_node("/root/TransitionManager")

var boss_instance: Node = null
var previous_player_camera: Camera2D = null

var battle_active := false
var battle_cancelled_on_player_death := false

# Called when the node enters the scene tree for the first time.
func _ready():
	_deactivate_barriers()

	if health_timer:
		health_timer.one_shot = false
		if not health_timer.timeout.is_connected(_on_health_timer_timeout):
			health_timer.timeout.connect(_on_health_timer_timeout)



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return

	player_in_range = body
	if _can_start_cutscene():
		_start_intro_cutscene()
	
	health_timer.start()
# ---------------------------------------------------------
func _can_start_cutscene() -> bool:
	return (
		Global.timeline == 8.8
		and Global.route_status == "Cyber"
		and not battle_active
	)

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

	_spawn_magus_king()

# ---------------------------------------------------------
# BOSS SPAWN
# ---------------------------------------------------------
func _spawn_magus_king() -> void:
	if not magus_king_scene or not spawn_point:
		push_error("MagusKingCutscene: Missing boss scene or spawn point")
		return

	Global.is_cutscene_active = false
	Global.health = Global.health_max
	Global.player.health_changed.emit(Global.health, Global.health_max)

	boss_instance = magus_king_scene.instantiate()
	get_tree().current_scene.add_child(boss_instance)

	boss_instance.global_position = spawn_point.global_position

	boss_instance.set_platform_markers(
		get_node("../PlatformMarkers/Platform_Low"),
		get_node("../PlatformMarkers/Platform_Mid"),
		get_node("../PlatformMarkers/Platform_High")
	)
	if boss_instance.has_signal("boss_died"):
		boss_instance.boss_died.connect(_on_boss_died)
	else:
	 # Fallback: connect to tree_exiting
		boss_instance.tree_exiting.connect(_on_boss_died)

	if boss_instance.has_method("reset_for_battle"):
		boss_instance.reset_for_battle()

	add_to_group("magus_king_boss_cutscene")

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
func _finalize_success() -> void:
	Global.timeline = 9
	Global.ending_cyber = true
	Global.persistent_ending_cyber = true
	Global.check_100_percent_completion()
	Global.save_persistent_data()
	Global.remove_quest_marker("Fight for the Cyber")
	
	Global.is_cutscene_active = false
	_cleanup_battle()

	if player_in_range:
		transition_manager.travel_to(player_in_range, target_room, target_spawn)

# ---------------------------------------------------------
# PLAYER DEATH CANCEL
# ---------------------------------------------------------
func cancel_magus_king_boss_battle_on_player_death() -> void:
	if not battle_active:
		return

	battle_active = false
	battle_cancelled_on_player_death = true
	Global.is_cutscene_active = false

	if health_timer:
		health_timer.stop()

	if boss_instance and is_instance_valid(boss_instance):
		boss_instance.queue_free()
		boss_instance = null

	_cleanup_battle()

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
		var cam = player_in_range.get_node_or_null("CameraPivot/Camera2D")
		if cam:
			previous_player_camera = cam
			cam.enabled = false

	if boss_camera:
		boss_camera.enabled = true
		boss_camera.make_current()

func _restore_player_camera() -> void:
	if boss_camera:
		boss_camera.enabled = false

	var player = player_in_range if player_in_range else Global.playerBody
	if player:
		var cam = player.get_node_or_null("CameraPivot/Camera2D")
		if cam:
			cam.enabled = true
			cam.make_current()

# ---------------------------------------------------------
# BARRIERS
# ---------------------------------------------------------
func _activate_barriers() -> void:
	for p in boss_barriers:
		if has_node(p):
			var b = get_node(p)
			if b is CollisionObject2D:
				b.set_deferred("collision_layer", 1)
				b.set_deferred("collision_mask", 1)
			if b is CanvasItem:
				b.visible = true

func _deactivate_barriers() -> void:
	for p in boss_barriers:
		if has_node(p):
			var b = get_node(p)
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
	if not health_pickup_scene or not health_spawn_marker:
		return

	var pickup := health_pickup_scene.instantiate()
	get_tree().current_scene.add_child(pickup)
	pickup.global_position = health_spawn_marker.global_position
	

	
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

