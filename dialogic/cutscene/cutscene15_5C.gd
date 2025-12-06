extends Area2D

var _has_been_triggered: bool = false
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@export var play_only_once: bool = true

var target_room := "Room_ExactlyionTown"
var target_spawn := "Spawn_FromExactlyionValentina"

var player_in_range: Node = null

@onready var transition_manager = get_node("/root/TransitionManager")
@onready var fail_timer: Timer = $FailTimer

# ⏱️ Timer UI
@onready var timer_label: Label = $CanvasLayer/TimerLabel
@onready var timer_color: ColorRect = $CanvasLayer/ColorRect

# Moving rocket / goal the player must touch
@onready var goal_area: Area2D = $GoalArea  # This has Rocket.gd attached

var rocket_reached: bool = false
var outcome_resolved: bool = false


func _ready() -> void:
	add_to_group("valentina_minigame_controller")

	var should_be_active := (
		not Global.replica_fini_dead
		and not Global.ult_cyber_form
	)

	if not should_be_active:
		if collision_shape:
			collision_shape.disabled = true
			monitoring = false
		set_process(false)
		if timer_label:
			timer_label.visible = false
		if timer_color:
			timer_color.visible = false
		return

	# Timer
	if fail_timer:
		fail_timer.stop()
		fail_timer.one_shot = true
		fail_timer.wait_time = 20.0  # adjust as you like
		if not fail_timer.timeout.is_connected(_on_fail_timer_timeout):
			fail_timer.timeout.connect(_on_fail_timer_timeout)

	# Hook rocket Area2D
	if goal_area:
		print("ValentinaRocket: goal_area =", goal_area, "script =", goal_area.get_script())
		if not goal_area.body_entered.is_connected(_on_goal_area_body_entered):
			goal_area.body_entered.connect(_on_goal_area_body_entered)
	else:
		push_warning("ValentinaRocket: goal_area is NULL – make sure there's a child node named GoalArea.")

	if timer_label:
		timer_label.visible = false
	if timer_color:
		timer_color.visible = false

	set_process(true)
	print("ValentinaRocket: minigame ready. Timer wait_time =", fail_timer.wait_time)


func _on_body_entered(body: Node) -> void:
	if outcome_resolved:
		return
	if not body.is_in_group("player"):
		return
	if play_only_once and _has_been_triggered:
		return

	_has_been_triggered = true
	player_in_range = body
	print("ValentinaRocket: player entered rocket minigame zone.")

	if fail_timer and fail_timer.is_stopped():
		fail_timer.start()
		print("ValentinaRocket: fail timer started (wait_time =", fail_timer.wait_time, ")")

	if timer_label:
		timer_label.visible = true
	if timer_color:
		timer_color.visible = true

	# 🚀 Activate the moving rocket
	if goal_area and goal_area.has_method("activate"):
		print("ValentinaRocket: activating rocket via GoalArea.activate()")
		goal_area.call_deferred("activate")
	else:
		print("ValentinaRocket: WARNING – goal_area missing or has no activate() method.")

		
func _process(delta: float) -> void:
	if not fail_timer or fail_timer.is_stopped() or not timer_label:
		return

	var remaining: int = int(ceil(fail_timer.time_left))
	var minutes: int = remaining / 60
	var seconds: int = remaining % 60
	timer_label.text = "%02d:%02d" % [minutes, seconds]


func _on_goal_area_body_entered(body: Node) -> void:
	print("ValentinaRocket: _on_goal_area_body_entered body =", body,
		"player_in_range =", player_in_range,
		"rocket_pos =", goal_area.global_position if goal_area else "N/A",
		"body_pos =", body.global_position if body is Node2D else "N/A")

	if outcome_resolved:
		return
	if not body.is_in_group("player"):
		return

	player_in_range = body
	on_rocket_hit_by_player()


func on_rocket_hit_by_player() -> void:
	if outcome_resolved:
		return

	rocket_reached = true
	outcome_resolved = true

	if fail_timer:
		fail_timer.stop()

	print("ValentinaRocket: Rocket hit by player in time → Valentina saved route.")

	Global.ult_cyber_form = true
	Global.valentina_dead = false
	Global.affinity += 1
	Global.persistent_saved_valentina = true
	Global.check_100_percent_completion()
	Global.save_persistent_data()

	if Dialogic.timeline_ended.is_connected(_on_valentina_save_finished):
		Dialogic.timeline_ended.disconnect(_on_valentina_save_finished)
	Dialogic.timeline_ended.connect(_on_valentina_save_finished)

	Dialogic.start("timeline16_5C", false)


func _on_valentina_save_finished(_timeline_name: String = "") -> void:
	print("ValentinaRocket: valentina_save_cutscene3 finished.")
	Dialogic.clear(Dialogic.ClearFlags.FULL_CLEAR)
	if Dialogic.timeline_ended.is_connected(_on_valentina_save_finished):
		Dialogic.timeline_ended.disconnect(_on_valentina_save_finished)

	Global.ult_cyber_form = true

	if player_in_range:
		player_in_range.unlock_and_force_form("UltimateCyber")

	Global.remove_quest_marker("Meet the Cyber Queen")

	# Hide timer UI
	if timer_label:
		timer_label.visible = false
	if timer_color:
		timer_color.visible = false

	# Optional: hide rocket
	if goal_area:
		goal_area.visible = false

	if player_in_range:
		transition_manager.travel_to(player_in_range, target_room, target_spawn)


func _on_fail_timer_timeout() -> void:
	if outcome_resolved:
		return

	outcome_resolved = true

	print("ValentinaRocket: Timer expired, goal not reached → Valentina dead route.")

	Global.ult_cyber_form = true
	Global.valentina_dead = true

	if Dialogic.timeline_ended.is_connected(_on_valentina_dead_finished):
		Dialogic.timeline_ended.disconnect(_on_valentina_dead_finished)
	Dialogic.timeline_ended.connect(_on_valentina_dead_finished)

	Dialogic.start("timeline16_5CV2", false)


func _on_valentina_dead_finished(_timeline_name: String = "") -> void:
	print("ValentinaRocket: valentina_dead_cutscene3 finished.")
	Dialogic.clear(Dialogic.ClearFlags.FULL_CLEAR)
	if Dialogic.timeline_ended.is_connected(_on_valentina_dead_finished):
		Dialogic.timeline_ended.disconnect(_on_valentina_dead_finished)

	Global.ult_cyber_form = true

	if player_in_range:
		player_in_range.unlock_and_force_form("UltimateCyber")

	Global.remove_quest_marker("Meet the Cyber Queen")

	# Hide timer UI
	if timer_label:
		timer_label.visible = false
	if timer_color:
		timer_color.visible = false

	# Optional: hide rocket
	if goal_area:
		goal_area.visible = false

	if player_in_range:
		transition_manager.travel_to(player_in_range, target_room, target_spawn)


func _on_body_exited(body: Node) -> void:
	pass
