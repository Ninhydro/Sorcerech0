extends Node

# 🔹 Simple boss to spawn (BaseEnemy-like)
@export var boss_scene: PackedScene

# 🔹 Where to spawn the boss
@onready var boss_spawn_marker: Marker2D = $BossSpawnMarker

# 🔹 Timer for fail → Nora route
@onready var fail_timer: Timer = $FailTimer
@export var battle_time_limit: float = 60.0  # seconds

# 🔹 Where to send player after a *win* (Tromarvelia Town)
@export var target_room := "Room_TromarveliaTown"
@export var target_spawn := "Spawn_FromTBattlefield"

@onready var transition_manager = get_node("/root/TransitionManager")

var battle_running: bool = false
var battle_used_fail_route: bool = false

var boss_instance: Node2D = null
var player_ref: Node = null
var player_camera: Camera2D = null


func _ready() -> void:
	fail_timer.one_shot = true
	if not fail_timer.timeout.is_connected(_on_fail_timer_timeout):
		fail_timer.timeout.connect(_on_fail_timer_timeout)


func start_battle(player: Node, player_cam: Camera2D) -> void:
	if battle_running:
		return

	print("GawrBossController: starting SIMPLE Gawr battle (BaseEnemy).")

	player_ref = player
	player_camera = player_cam

	battle_running = true

	# STORY FLAGS on entering the fight
	Global.meet_gawr = true          # met Gawr at least once
	Global.ult_magus_form = false
	Global.gawr_dead = false
	Global.is_boss_battle = true

	# Spawn simple boss instance
	if not boss_scene:
		push_error("GawrBossController: boss_scene is not assigned!")
		return

	boss_instance = boss_scene.instantiate()
	var parent := get_parent()
	if parent == null:
		parent = get_tree().current_scene
	parent.add_child(boss_instance)

	if boss_spawn_marker and boss_instance is Node2D:
		boss_instance.global_position = boss_spawn_marker.global_position

	# Listen for boss death via tree_exited (like Replica)
	if not boss_instance.tree_exited.is_connected(_on_boss_died):
		boss_instance.tree_exited.connect(_on_boss_died)

	# Start fail timer
	fail_timer.start(battle_time_limit)
	print("GawrBossController: fail timer started with ", battle_time_limit, " seconds.")


func _on_boss_died() -> void:
	if not battle_running:
		boss_instance = null
		return

	print("GawrBossController: Gawr (simple boss) died → Ult Magus route.")

	battle_running = false
	fail_timer.stop()
	boss_instance = null

	# Story flags: player actually killed Gawr
	Global.ult_magus_form = true
	Global.gawr_dead = true
	Global.affinity += 1
	Global.increment_kills()
	Global.is_boss_battle = false

	# After the fight, we use your old Gawr win dialog: timeline16M
	if Dialogic.timeline_ended.is_connected(_on_gawr_win_dialog_finished):
		Dialogic.timeline_ended.disconnect(_on_gawr_win_dialog_finished)
	Dialogic.timeline_ended.connect(_on_gawr_win_dialog_finished)

	Dialogic.start("timeline16M", false)


func _on_gawr_win_dialog_finished(_timeline_name := "") -> void:
	print("GawrBossController: Gawr win-dialog finished.")
	Dialogic.clear(Dialogic.ClearFlags.FULL_CLEAR)
	if Dialogic.timeline_ended.is_connected(_on_gawr_win_dialog_finished):
		Dialogic.timeline_ended.disconnect(_on_gawr_win_dialog_finished)

	# Match your old post-Gawr win logic
	Global.timeline = 6.5
	Global.after_battle_gawr = true

	# Ensure flags are in the winning state
	Global.ult_magus_form = true
	Global.gawr_dead = true

	# Give Ultimate Magus + travel to Tromarvelia
	if player_ref:
		player_ref.unlock_and_force_form("UltimateMagus")

	_restore_player_camera()

	if player_ref:
		transition_manager.travel_to(player_ref, target_room, target_spawn)

	Global.remove_quest_marker("Meet the Magus King")


func _on_fail_timer_timeout() -> void:
	if not battle_running:
		return
	if boss_instance == null:
		# Boss died exactly as timer ended → treat as win
		print("GawrBossController: timer expired but boss already dead → ignoring as fail.")
		return

	print("GawrBossController: time up, boss still alive → Nora route setup.")

	battle_running = false
	Global.is_boss_battle = false

	# Simple fail flags (pre-Nora)
	Global.ult_magus_form = false
	Global.gawr_dead = false
	Global.affinity -= 1

	# Mark this route as used (you mentioned “only once”)
	if not battle_used_fail_route:
		battle_used_fail_route = true
		Global.gawr_failed_route_used = true

	# Use your old “Gawr fail” dialog timeline16MV2
	if Dialogic.timeline_ended.is_connected(_on_gawr_fail_dialog_finished):
		Dialogic.timeline_ended.disconnect(_on_gawr_fail_dialog_finished)
	Dialogic.timeline_ended.connect(_on_gawr_fail_dialog_finished)

	Dialogic.start("timeline16MV2", false)


func _on_gawr_fail_dialog_finished(_timeline_name := "") -> void:
	print("GawrBossController: Gawr fail-dialog finished → enable Nora cutscene.")
	Dialogic.clear(Dialogic.ClearFlags.FULL_CLEAR)
	if Dialogic.timeline_ended.is_connected(_on_gawr_fail_dialog_finished):
		Dialogic.timeline_ended.disconnect(_on_gawr_fail_dialog_finished)

	# Match what Nora cutscene expects:
	# if Global.timeline == 6.5 and Global.after_battle_gawr == true
	# and Global.gawr_dead == false and Global.ult_magus_form == false
	Global.timeline = 6.5
	Global.after_battle_gawr = true

	_restore_player_camera()

	# ⚠️ We DO NOT teleport here.
	# Your existing Nora Area2D in this room will now become active
	# and handle timelines16_5M / 16_5MV2 + UltMagus + travel.


func _restore_player_camera() -> void:
	if player_camera:
		player_camera.enabled = true
		player_camera.make_current()
