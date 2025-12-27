extends Area2D

# ---------------------------------------------------------
# CONFIG
# ---------------------------------------------------------
@export var intro_timeline := "timeline18G"
@export var outro_timeline := "timeline19G"

@export var maya_scene: PackedScene
@export var nataly_scene: PackedScene
@export var lux_scene: PackedScene

@export var boss_spawn_markers: Array[NodePath] = [] # [Maya, Nataly, Lux]
@export var boss_barriers: Array[NodePath] = []

@export var health_pickup_scene: PackedScene
@export var target_room := "Room_Restart"
@export var target_spawn := "Spawn_FromReality"

# ---------------------------------------------------------
# NODES
# ---------------------------------------------------------
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var boss_camera: Camera2D = $BossCamera
@onready var health_timer: Timer = $HealthTimer
@onready var transition_manager = get_node("/root/TransitionManager")
@onready var health_spawn_marker: Marker2D = $HealthSpawnMarker

# ---------------------------------------------------------
# STATE
# ---------------------------------------------------------
var player: Node
var active_bosses: Array = []
var previous_player_camera: Camera2D

var battle_active := false
var triggered := false
var current_health_pickup: Node2D

var phase := 1
var dead_helpers := 0

# Signals for phase completion
signal phase_1_completed
signal phase_2_completed  
signal phase_3_completed

# ---------------------------------------------------------
# READY
# ---------------------------------------------------------
func _ready():
	_deactivate_barriers()
	boss_camera.enabled = false
	health_timer.timeout.connect(_on_health_timer_timeout)
	health_timer.one_shot = false
# ---------------------------------------------------------
# CONDITIONS
# ---------------------------------------------------------
func _can_start() -> bool:
	return not triggered and Global.timeline == 8 and Global.route_status == "Genocide"

# ---------------------------------------------------------
# AREA ENTER
# ---------------------------------------------------------
func _on_body_entered(body):
	if not body.is_in_group("player") or not _can_start():
		return

	triggered = true
	battle_active = true
	player = body

	collision_shape.set_deferred("disabled", true)
	await _start_intro()
	await _start_battle()

# ---------------------------------------------------------
# INTRO
# ---------------------------------------------------------
func _start_intro() -> void:
	Global.health = Global.health_max
	Global.player.health_changed.emit(Global.health, Global.health_max)
	
	Global.is_cutscene_active = true
	_activate_barriers()
	_switch_camera()

	Dialogic.start(intro_timeline)
	await Dialogic.timeline_ended

	Global.is_cutscene_active = false

# ---------------------------------------------------------
# BATTLE FLOW - SIMPLIFIED APPROACH
# ---------------------------------------------------------
func _start_battle() -> void:
	health_timer.start()
	
	print("=== BATTLE STARTED ===")
	print("Initial phase: ", phase)
	#Global.health = Global.health_max
	# Phase 1: Maya + Nataly
	print("Starting Phase 1: Maya and Nataly")
	await _phase_1()
	
	# Wait for Phase 1 completion (when first helper dies)
	#print("Waiting for Phase 1 completion (first helper death)")
	#await phase_1_completed
	#print("Phase 1 completed! Current phase should be 2, actual: ", phase)
	
	# Phase 2: Lux invulnerable + remaining helper
	#print("Starting Phase 2: Lux invulnerable")
	#await _phase_2()
	
	# Wait for Phase 2 completion (when second helper dies)
	#print("Waiting for Phase 2 completion (second helper death)")
	#await phase_2_completed
	#print("Phase 2 completed! Current phase should be 3, actual: ", phase)
	
	# Phase 3: Lux alone and vulnerable
	#print("Starting Phase 3: Lux alone and vulnerable")
	#await _phase_3()
	
	# Wait for Phase 3 completion (when Lux dies)
	#print("Waiting for Phase 3 completion (Lux death)")
	#await phase_3_completed
	#print("Phase 3 completed! Battle should end now.")
	
	#print("=== BATTLE COMPLETE ===")
	
	# Battle is complete
	#await _end_battle_success()

# ---------------------------------------------------------
# PHASE 1 – Maya + Nataly
# ---------------------------------------------------------
func _phase_1() -> void:
	var maya = await _spawn_boss(maya_scene, boss_spawn_markers[0])
	var nataly = await _spawn_boss(nataly_scene, boss_spawn_markers[1])
	
	if maya:
		maya.set_meta("boss_id", "maya")
	if nataly:
		nataly.set_meta("boss_id", "nataly")
	
	print("Phase 1: Maya and Nataly spawned")

# ---------------------------------------------------------
# PHASE 2 – Lux invulnerable + one remaining helper
# ---------------------------------------------------------
func _phase_2() -> void:
	# Spawn Lux as invulnerable
	var lux = await _spawn_boss(lux_scene, boss_spawn_markers[2])
	if lux:
		lux.set_meta("boss_id", "lux")
		lux.set_invulnerable()
		print("Phase 2: Lux spawned and set to invulnerable")
	
	# Small delay before continuing
	await get_tree().create_timer(0.5).timeout

# ---------------------------------------------------------
# PHASE 3 – Lux alone (vulnerable and enraged)
# ---------------------------------------------------------
func _phase_3() -> void:
	# Find existing Lux
	print("Starting Phase 3: Lux alone and vulnerable")
	
	# Find existing Lux
	var lux = _get_active_boss("Lux")
	if lux:
		# Make sure Lux is vulnerable
		lux.set_vulnerable()
		print("Phase 3: Lux is now vulnerable")
		#else:
		#	print("ERROR: Lux doesn't have set_invulnerable method!")
		
		# Add rage mode if you have that method
		if lux.has_method("enter_rage_mode"):
			lux.enter_rage_mode()
			print("Phase 3: Lux entered rage mode")
	else:
		print("ERROR: Could not find Lux in Phase 3!")

# ---------------------------------------------------------
# SPAWNING (COROUTINE)
# ---------------------------------------------------------
func _spawn_boss(scene: PackedScene, marker_path: NodePath) -> Node:
	if not scene or not has_node(marker_path):
		return null
		
	var marker := get_node(marker_path)
	var boss := scene.instantiate()

	get_tree().current_scene.add_child.call_deferred(boss)
	await boss.tree_entered

	boss.global_position = marker.global_position
	active_bosses.append(boss)

	if boss.has_signal("boss_died"):
		boss.boss_died.connect(_on_boss_died.bind(boss))
	else:
		boss.tree_exiting.connect(_on_boss_died.bind(boss))

	return boss

# ---------------------------------------------------------
# HELPERS
# ---------------------------------------------------------
func _wait_until_bosses_dead(bosses: Array) -> void:
	while true:
		var alive := false
		for b in bosses:
			if is_instance_valid(b):
				alive = true
				break
		if not alive:
			return
		await get_tree().process_frame

func _get_active_boss(name: String) -> Node:
	for b in active_bosses:
		if is_instance_valid(b) and b.name.contains(name):
			return b
	return null

func _on_boss_died(boss):
	if not battle_active:
		return

	if boss in active_bosses:
		active_bosses.erase(boss)

	var id = boss.get_meta("boss_id", "")
	print("Boss died: ", id, " | Current phase: ", phase, " | Dead helpers: ", dead_helpers)
	
	# Debug: print all active bosses
	print("Active bosses count: ", active_bosses.size())
	for b in active_bosses:
		if is_instance_valid(b):
			print("  - ", b.get_meta("boss_id", "unknown"))

	if id in ["maya", "nataly"]:
		dead_helpers += 1
		print("Helper died: ", id, " Total dead helpers: ", dead_helpers)
		
		# Check for phase transitions based on helper deaths
		if phase == 1 and dead_helpers == 1:
			print("First helper died - Phase 1 complete")
			phase = 2  # Update phase immediately
			emit_signal("phase_1_completed")
			await get_tree().create_timer(0.1).timeout
			_phase_2()
			
		elif phase == 2 and dead_helpers == 2:
			print("Second helper died - Phase 2 complete")
			phase = 3  # Update phase immediately
			emit_signal("phase_2_completed")
			await get_tree().create_timer(0.1).timeout
			_phase_3()
			
	elif id == "lux":
		print("Lux died!")
		if phase == 3:
			print("Lux died in Phase 3 - Battle complete!")
			emit_signal("phase_3_completed")
			await get_tree().create_timer(0.1).timeout
			_end_battle_success()
		else:
			print("ERROR: Lux died in phase ", phase, " but should only die in Phase 3!")
# ---------------------------------------------------------
# END
# ---------------------------------------------------------
func _end_battle_success() -> void:
	print("Ending battle successfully")
	Global.is_cutscene_active = true
	Dialogic.start(outro_timeline)
	await Dialogic.timeline_ended

	_cleanup()

	Global.timeline = 9
	Global.ending_genocide = true
	Global.persistent_ending_genocide = true
	Global.save_persistent_data()

	transition_manager.travel_to(player, target_room, target_spawn)

# ---------------------------------------------------------
# CLEANUP / CAMERA / BARRIERS / HEALTH
# ---------------------------------------------------------
func _cleanup():
	print("Cleaning up battle")
	battle_active = false
	_deactivate_barriers()
	_restore_camera()
	health_timer.stop()
	dead_helpers = 0
	
func _switch_camera():
	var cam := player.get_node_or_null("CameraPivot/Camera2D")
	if cam:
		previous_player_camera = cam
		cam.enabled = false
	boss_camera.enabled = true
	boss_camera.make_current()

func _restore_camera():
	boss_camera.enabled = false
	if previous_player_camera:
		previous_player_camera.enabled = true
		previous_player_camera.make_current()

func _activate_barriers():
	for p in boss_barriers:
		var b = get_node(p)
		if b is CollisionObject2D:
			b.set_deferred("collision_layer", 1)
			b.set_deferred("collision_mask", 1)
		if b is CanvasItem:
			b.visible = true

func _deactivate_barriers():
	for p in boss_barriers:
		var b = get_node(p)
		if b is CollisionObject2D:
			b.set_deferred("collision_layer", 0)
			b.set_deferred("collision_mask", 0)
		if b is CanvasItem:
			b.visible = false

func _on_health_timer_timeout():
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
		

func cancel_boss_battle_on_player_death() -> void:
	if not battle_active:
		return

	#battle_cancelled = true
	battle_active = false
	Global.is_cutscene_active = false

	if health_timer:
		health_timer.stop()

	if current_health_pickup and is_instance_valid(current_health_pickup):
		current_health_pickup.queue_free()

	#if boss_instance and is_instance_valid(boss_instance):
	#	boss_instance.queue_free()

	_cleanup()
