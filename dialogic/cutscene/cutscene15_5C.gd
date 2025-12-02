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

# Success trigger (goal area the player must touch)
@onready var goal_area: Area2D = $GoalArea

var rocket_reached: bool = false
var outcome_resolved: bool = false


func _ready() -> void:
	add_to_group("valentina_minigame_controller")

	# Only active if we are in the Valentina route:
	var should_be_active := (
		not Global.replica_fini_dead
		and not Global.ult_cyber_form
	)

	if not should_be_active:
		if collision_shape:
			collision_shape.disabled = true
			monitoring = false
		set_process(false)
		# Hide UI just in case
		if timer_label:
			timer_label.visible = false
		if timer_color:
			timer_color.visible = false
		return

	# Force sane timer settings
	if fail_timer:
		fail_timer.stop()
		fail_timer.one_shot = true
		fail_timer.wait_time = 15.0  # ← adjust if you want longer
		if not fail_timer.timeout.is_connected(_on_fail_timer_timeout):
			fail_timer.timeout.connect(_on_fail_timer_timeout)

	# Connect goal area
	if goal_area and not goal_area.body_entered.is_connected(_on_goal_area_body_entered):
		goal_area.body_entered.connect(_on_goal_area_body_entered)

	# Hide timer UI until minigame actually starts
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

	player_in_range = body
	print("ValentinaRocket: player entered rocket minigame zone.")

	# Start timer + show UI
	if fail_timer and fail_timer.is_stopped():
		fail_timer.start()
		print("ValentinaRocket: fail timer started (wait_time =", fail_timer.wait_time, ")")

	if timer_label:
		timer_label.visible = true
	if timer_color:
		timer_color.visible = true


func _process(delta: float) -> void:
	# Only update label while timer is running
	if not fail_timer or fail_timer.is_stopped() or not timer_label:
		return

	var remaining: int = int(ceil(fail_timer.time_left))
	var minutes: int = remaining / 60
	var seconds: int = remaining % 60
	timer_label.text = "%02d:%02d" % [minutes, seconds]


func _on_goal_area_body_entered(body: Node) -> void:
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

	if player_in_range:
		transition_manager.travel_to(player_in_range, target_room, target_spawn)


func _on_body_exited(body: Node) -> void:
	pass
