extends Area2D

var _has_been_triggered: bool = false
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@export var play_only_once: bool = true

var player_in_range: Node = null
var previous_player_camera: Camera2D = null

@onready var transition_manager = get_node("/root/TransitionManager")

# --- Optional camera / intro animation ---
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var boss_camera: Camera2D = $BossCamera2D

# --- Boss spawn / timers / UI ---
@onready var boss_spawn_marker: Marker2D = $BossSpawnMarker
@onready var boss_timer: Timer = $BossTimer        # acts as fail timer
@onready var health_spawn_marker: Marker2D = $HealthSpawnMarker
@onready var health_timer: Timer = $HealthTimer

@onready var timer_label: Label = $CanvasLayer/TimerLabel
@onready var timer_color: ColorRect = $CanvasLayer/ColorRect

# --- Boss / health pickup ---
@export var boss_scene: PackedScene                 # assign a simple BaseEnemy scene in Inspector
@export var health_pickup_scene: PackedScene = preload("res://scenes/objects/health_pickup.tscn")

var boss_instance: Node2D = null
var current_health_pickup: Node2D = null

var battle_active: bool = false
var battle_cancelled_on_player_death: bool = false

# Barriers that block player in arena during boss fight
@export var boss_barriers: Array[NodePath] = []

# Story / route control
var battle_used_fail_route: bool = false


func _ready() -> void:
	_reset_visuals()

	if boss_timer:
		boss_timer.one_shot = true
		if not boss_timer.timeout.is_connected(_on_boss_timer_timeout):
			boss_timer.timeout.connect(_on_boss_timer_timeout)

	if health_timer:
		health_timer.one_shot = false
		health_timer.wait_time = 60.0  # health drop every 30 seconds
		if not health_timer.timeout.is_connected(_on_health_timer_timeout):
			health_timer.timeout.connect(_on_health_timer_timeout)
	
	if boss_camera:
		boss_camera.add_to_group("gawr_boss_camera")

func _reset_visuals() -> void:
	_deactivate_barriers()
	if timer_label:
		timer_label.visible = false
	if timer_color:
		timer_color.visible = false


func _process(delta: float) -> void:
	# Only active before first Gawr battle
	if Global.timeline == 6.5 and Global.meet_gawr == false:
		collision_shape.disabled = false
	else:
		collision_shape.disabled = true

	# Update timer label while battle active
	if battle_active and boss_timer and timer_label:
		var remaining: int = int(ceil(boss_timer.time_left))
		var minutes: int = remaining / 60
		var seconds: int = remaining % 60
		timer_label.text = "%02d:%02d" % [minutes, seconds]


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if play_only_once and _has_been_triggered:
		return

	player_in_range = body
	print("GawrCutscene: Player entered Gawr intro trigger.")

	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	else:
		printerr("GawrCutscene: CollisionShape2D is null, disabling Area2D instead.")
		set_deferred("monitorable", false)
		set_deferred("monitoring", false)

	if play_only_once:
		_has_been_triggered = true

	_start_intro_cutscene()


func _start_intro_cutscene() -> void:
	Global.is_cutscene_active = true

	# Store and disable player camera
	if player_in_range:
		var player_cam: Camera2D = player_in_range.get_node_or_null("CameraPivot/Camera2D")
		if player_cam:
			previous_player_camera = player_cam
			player_cam.enabled = false

	# Switch to boss camera
	if boss_camera:
		boss_camera.enabled = true
		boss_camera.make_current()

	# Optional intro anim
	if anim_player and anim_player.has_animation("intro"):
		anim_player.play("intro")

	# Start Gawr intro dialog
	if Dialogic.timeline_ended.is_connected(_on_intro_dialog_finished):
		Dialogic.timeline_ended.disconnect(_on_intro_dialog_finished)
	Dialogic.timeline_ended.connect(_on_intro_dialog_finished)

	Dialogic.start("timeline15M", false)  # Gawr intro timeline


func _on_intro_dialog_finished(_timeline_name := "") -> void:
	print("GawrCutscene: Intro dialog finished.")
	Global.is_cutscene_active = false

	Dialogic.clear(Dialogic.ClearFlags.FULL_CLEAR)
	if Dialogic.timeline_ended.is_connected(_on_intro_dialog_finished):
		Dialogic.timeline_ended.disconnect(_on_intro_dialog_finished)

	_start_boss_battle()


func _start_boss_battle() -> void:
	_activate_barriers()
	battle_cancelled_on_player_death = false
	battle_active = false

	# STORY FLAGS
	Global.meet_gawr = true
	Global.after_battle_gawr = false
	Global.ult_magus_form = false
	Global.gawr_dead = false
	Global.is_boss_battle = true

	# Heal player at start
	Global.health = Global.health_max
	if is_instance_valid(Global.player):
		Global.player.health_changed.emit(Global.health, Global.health_max)

	if not boss_scene:
		printerr("GawrCutscene: boss_scene not assigned!")
		return

	boss_instance = boss_scene.instantiate()
	boss_instance.add_to_group("gawr_boss")
	if boss_instance == null:
		printerr("GawrCutscene: Failed to instance boss_scene.")
		return

	var parent := get_parent()
	if parent:
		parent.add_child(boss_instance)
	else:
		get_tree().current_scene.add_child(boss_instance)

	# Position
	if boss_spawn_marker and boss_instance is Node2D:
		boss_instance.global_position = boss_spawn_marker.global_position

	# ---------------------------------------------------------
	# COLLISION RULES (player can pass through boss)
	# ---------------------------------------------------------
	# Layers: 1=player, 2=platform, 3=enemy, 4=gawr
	# Bits:   1<<0,     1<<1,        1<<2,    1<<3
	var LAYER_PLAYER := 1
	var LAYER_PLATFORM := 2
	var LAYER_GAWR := 4

	if boss_instance is CollisionObject2D:
		var co := boss_instance as CollisionObject2D

		# Put boss on layer 4
		co.collision_layer = 0
		co.set_collision_layer_value(LAYER_GAWR, true)

		# Only collide with platforms (layer 2), NOT player
		co.collision_mask = 0
		co.set_collision_mask_value(LAYER_PLATFORM, true)
		co.set_collision_mask_value(LAYER_PLAYER, false)

	# Also ensure any child bodies don't block the player (best-effort)
	for child in boss_instance.get_children():
		if child is CollisionObject2D:
			var cco := child as CollisionObject2D
			cco.set_collision_mask_value(LAYER_PLAYER, false)

	# ---------------------------------------------------------
	# WAKE UP THE BOSS AI
	# ---------------------------------------------------------

	# If it's your custom GawrBoss (independent script)
	if boss_instance.has_method("reset_for_battle"):
		print("GawrCutscene: calling boss.reset_for_battle()")
		boss_instance.call_deferred("reset_for_battle")

	# If it's a BaseEnemy (simple placeholder) -> force it to actually do something
	# These are variables your BaseEnemy uses.
	if "range" in boss_instance:
		boss_instance.range = true   # pretend player is inside chase range
	if "is_enemy_chase" in boss_instance:
		boss_instance.is_enemy_chase = true
	if "dir" in boss_instance:
		# pick a default roam dir so it doesn't stay idle
		boss_instance.dir = Vector2.LEFT if randf() < 0.5 else Vector2.RIGHT
	if "player_in_area" in boss_instance:
		boss_instance.player_in_area = true

	# If your BaseEnemy needs a player reference:
	if "player" in boss_instance:
		boss_instance.player = Global.playerBody

	# ---------------------------------------------------------
	# Death detection
	# ---------------------------------------------------------
	# tree_exited works for BaseEnemy (it queue_free() on death),
	# but for custom bosses it's better to use a boss_died signal if available.
	if boss_instance.has_signal("boss_died"):
		if not boss_instance.boss_died.is_connected(_on_boss_died):
			boss_instance.boss_died.connect(_on_boss_died)
	else:
		if not boss_instance.tree_exited.is_connected(_on_boss_died):
			boss_instance.tree_exited.connect(_on_boss_died)

	# Start timers/UI
	battle_active = true

	if boss_timer:
		boss_timer.start()
	if timer_label:
		timer_label.visible = true
	if timer_color:
		timer_color.visible = true
	if health_timer:
		health_timer.start()

	print("GawrCutscene: Gawr battle started (simple boss). boss=", boss_instance)


func _on_boss_timer_timeout() -> void:
	if not battle_active or battle_cancelled_on_player_death or not Global.playerAlive:
		return

	battle_active = false

	var boss_alive := is_instance_valid(boss_instance)
	if boss_alive:
		print("GawrCutscene: Timer finished, boss still alive → Nora route setup.")

		# ✅ keep boss alive for the Nora minigame
		if boss_instance and boss_instance.has_method("prepare_for_nora_minigame"):
			boss_instance.call_deferred("prepare_for_nora_minigame")

		_handle_battle_fail()
	else:
		print("GawrCutscene: Timer finished but boss already dead → treat as success.")
		_handle_battle_success()


func _on_boss_died() -> void:
	if not battle_active:
		boss_instance = null
		return

	if battle_cancelled_on_player_death or not Global.playerAlive:
		print("GawrCutscene: Boss died while player dead / battle cancelled, ignoring.")
		boss_instance = null
		return

	print("GawrCutscene: Gawr defeated by player!")
	battle_active = false

	if boss_timer:
		boss_timer.stop()

	boss_instance = null
	_handle_battle_success()


func _handle_battle_success() -> void:
	_reset_visuals()
	if health_timer:
		health_timer.stop()
	if current_health_pickup and is_instance_valid(current_health_pickup):
		current_health_pickup.queue_free()
		current_health_pickup = null

	# Story flags: Gawr actually killed
	Global.ult_magus_form = true
	Global.gawr_dead = true
	Global.after_battle_gawr = true
	Global.affinity += 1
	Global.increment_kills()
	Global.is_boss_battle = false

	# Gawr win branch dialog
	if Dialogic.timeline_ended.is_connected(_on_gawr_win_dialog_finished):
		Dialogic.timeline_ended.disconnect(_on_gawr_win_dialog_finished)
	Dialogic.timeline_ended.connect(_on_gawr_win_dialog_finished)

	Dialogic.start("timeline16M", false)  # Gawr killed route


func _on_gawr_win_dialog_finished(_timeline_name := "") -> void:
	print("GawrCutscene: Gawr win dialog finished.")
	Dialogic.clear(Dialogic.ClearFlags.FULL_CLEAR)
	if Dialogic.timeline_ended.is_connected(_on_gawr_win_dialog_finished):
		Dialogic.timeline_ended.disconnect(_on_gawr_win_dialog_finished)

	Global.is_cutscene_active = false
	Global.timeline = 6.5
	# Ensure flags are in winning state
	Global.ult_magus_form = true
	Global.gawr_dead = true

	# Give Ultimate Magus form and send to Tromarvelia Town
	if player_in_range:
		player_in_range.unlock_and_force_form("UltimateMagus")

	_restore_player_camera()

	if player_in_range:
		var target_room := "Room_TromarveliaTown"
		var target_spawn := "Spawn_FromTBattlefield"
		transition_manager.travel_to(player_in_range, target_room, target_spawn)

	Global.remove_quest_marker("Meet the Magus King")


func _handle_battle_fail() -> void:
	_reset_visuals()

	if health_timer:
		health_timer.stop()
	if current_health_pickup and is_instance_valid(current_health_pickup):
		current_health_pickup.queue_free()
		current_health_pickup = null

	Global.is_boss_battle = false

	# Fail flags (pre-Nora)
	Global.ult_magus_form = false
	Global.gawr_dead = false
	Global.affinity -= 1

	if not battle_used_fail_route and Global.ult_magus_form == false and Global.gawr_dead == false:
		battle_used_fail_route = true
		Global.gawr_failed_route_used = true

		# Gawr fail branch dialog (before Nora)
		if Dialogic.timeline_ended.is_connected(_on_gawr_fail_dialog_finished):
			Dialogic.timeline_ended.disconnect(_on_gawr_fail_dialog_finished)
		Dialogic.timeline_ended.connect(_on_gawr_fail_dialog_finished)

		Dialogic.start("timeline16MV2", false)  # “didn’t kill Gawr” route
	else:
		print("GawrCutscene: fail route already used or flags mismatch.")


func _on_gawr_fail_dialog_finished(_timeline_name := "") -> void:
	print("GawrCutscene: Gawr fail dialog finished → Nora cutscene conditions set.")
	Dialogic.clear(Dialogic.ClearFlags.FULL_CLEAR)
	if Dialogic.timeline_ended.is_connected(_on_gawr_fail_dialog_finished):
		Dialogic.timeline_ended.disconnect(_on_gawr_fail_dialog_finished)
	Global.is_cutscene_active = false
	# Match what your Nora cutscene expects:
	# timeline == 6.5, after_battle_gawr == true, gawr_dead == false, ult_magus_form == false
	Global.timeline = 6.5
	Global.after_battle_gawr = true
	Global.ult_magus_form = false
	Global.gawr_dead = false

	_restore_player_camera()

	# ⚠️ No teleport here.
	# Your existing Nora Area2D (with timeline16_5M / 16_5MV2) in this same room
	# will now become active and handle UltMagus + travel etc.


func cancel_gawr_boss_battle_on_player_death() -> void:
	# Call this from Player.handle_death() for group "gawr_boss_cutscene"
	if not battle_active:
		return
	Global.is_cutscene_active = false
	print("GawrCutscene: Battle cancelled due to player death.")
	battle_active = false
	battle_cancelled_on_player_death = true

	if boss_timer:
		boss_timer.stop()
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

	_reset_visuals()

	_restore_player_camera()
	# No teleport; player will respawn from SaveSpot logic


func _on_body_exited(body: Node) -> void:
	pass


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


func _restore_player_camera() -> void:
	if boss_camera:
		boss_camera.enabled = false

	var player: Node = player_in_range
	if player == null and Global.playerBody:
		player = Global.playerBody

	if player:
		var cam: Camera2D = player.get_node_or_null("CameraPivot/Camera2D")

		if cam:
			cam.enabled = true
			cam.make_current()


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
