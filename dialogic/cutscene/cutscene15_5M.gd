extends Area2D
class_name NoraMinigameController

var _has_been_triggered := false
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@export var play_only_once := true

var target_room := "Room_TromarveliaTown"
var target_spawn := "Spawn_FromTBattlefield"

var player_in_range: Node = null
var outcome_resolved := false   # prevents double-resolves

@onready var transition_manager = get_node("/root/TransitionManager")

# Timers
@onready var success_timer: Timer = $SuccessTimer   # set wait_time = 60, one_shot = true
@onready var charge_timer: Timer  = $ChargeTimer    # set wait_time = 10, one_shot = true

# Platforms parent (all floating platforms under here)
@onready var platforms_root: Node = $Platforms

# Boss ref (spawned from PackedScene, found via group)
var boss: Node = null

@onready var timer_label: Label = $CanvasLayer/TimerLabel
@onready var charge_label: Label = $CanvasLayer/ChargeLabel
@onready var timer_color: ColorRect = $CanvasLayer/ColorRect

@onready var final_flame_marker: Marker2D = $FinalFlameMarker

var boss_camera: Camera2D = null
var player_camera: Camera2D = null

var minigame_started := false

@export var new_cutscene_path: NodePath

func _show_ui(show: bool) -> void:
	#if timer_label: timer_label.visible = show
	if charge_label: charge_label.visible = show
	if timer_color: timer_color.visible = show
	
func _ready() -> void:
	_set_platforms_enabled(false)
	
	# timers setup
	if success_timer:
		success_timer.stop()
		success_timer.one_shot = true
		if not success_timer.timeout.is_connected(_on_success_timer_timeout):
			success_timer.timeout.connect(_on_success_timer_timeout)

	if charge_timer:
		charge_timer.stop()
		charge_timer.one_shot = true
		if not charge_timer.timeout.is_connected(_on_charge_timer_timeout):
			charge_timer.timeout.connect(_on_charge_timer_timeout)

	set_process(true)
	_show_ui(false)

func _process(_delta: float) -> void:
	# match your original activation condition
	if Global.timeline == 6.5 and Global.after_battle_gawr and (not Global.gawr_dead) and (not Global.ult_magus_form):
		if collision_shape:
			collision_shape.disabled = false
	else:
		if collision_shape:
			collision_shape.disabled = true
	
	if not outcome_resolved:
		if success_timer and not success_timer.is_stopped() and timer_label:
			timer_label.text = "SAVE: %02d" % int(ceil(success_timer.time_left))
		if charge_timer and not charge_timer.is_stopped() and charge_label:
			charge_label.text = "CHARGE: %02d" % int(ceil(charge_timer.time_left))
			
	#if not outcome_resolved and boss == null:
	#	boss = _find_boss()
	#	if boss:
	#		_start_boss_minigame_mode()

func _on_body_entered(body: Node) -> void:
	if outcome_resolved:
		return
	if not body.is_in_group("player"):
		return
	if play_only_once and _has_been_triggered:
		return

	_has_been_triggered = true
	player_in_range = body

	print("NoraMinigame: Player entered → starting minigame.")
	
	# cache player camera (your player camera path is NOT "Camera2D" in your Player.gd — it’s CameraPivot/Camera2D)
	if player_in_range and player_in_range is Node:
		player_camera = player_in_range.get_node_or_null("CameraPivot/Camera2D") as Camera2D
		if player_camera:
			player_camera.enabled = false
		player_in_range.global_position = $PlayerStart.global_position
		#player_in_range.velocity = Vector2.ZERO
		#player_in_range.set_physics_process(false)

	boss_camera = get_tree().get_first_node_in_group("gawr_boss_camera") as Camera2D
	if boss_camera:
		boss_camera.enabled = true
		boss_camera.make_current()
	
	# disable retrigger
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	else:
		set_deferred("monitorable", false)
		set_deferred("monitoring", false)

	Global.is_cutscene_active = false
	Global.health = Global.health_max
	# find boss spawned from packedscene (no NodePath)
	#boss = get_tree().get_first_node_in_group("gawr_boss")
	#if boss == null:
	#	push_warning("NoraMinigame: Boss not found in group 'gawr_boss'.")
		# you can still run success timer if you want, but likely you want to abort:
		#return

	# enable platforms
	_set_platforms_enabled(true)
	_show_ui(true)

	# start timers immediately
	if charge_timer: charge_timer.start()
	if success_timer: success_timer.start()

	# now try to find boss (retry if not ready yet)
	boss = _find_boss()
	if boss and not minigame_started:
		boss.global_position = $BossStart.global_position
		minigame_started = true
		_bind_boss_signals()
		_start_boss_minigame_mode()
	else:
		push_warning("NoraMinigame: boss not found yet, will retry in _process.")

func _find_boss() -> Node:
	return get_tree().get_first_node_in_group("gawr_boss")

func _start_boss_minigame_mode() -> void:
	if boss and boss.has_method("start_nora_minigame"):
		var charge_time := 10.0
		if charge_timer:
			charge_time = charge_timer.wait_time  # should be 10 in inspector
		
		boss.call_deferred("start_nora_minigame", charge_time, final_flame_marker)

# ----------------------------
# PLATFORM VISIBILITY / COLLISION
# ----------------------------
func _set_platforms_enabled(enabled: bool) -> void:
	if not platforms_root:
		return

	platforms_root.visible = enabled

	# disable every CollisionShape2D under Platforms so player can't stand on them
	for cs in platforms_root.find_children("*", "CollisionShape2D", true, false):
		(cs as CollisionShape2D).set_deferred("disabled", not enabled)


# ----------------------------
# MINIGAME OUTCOMES
# ----------------------------
func _on_success_timer_timeout() -> void:
	if outcome_resolved:
		return

	# If the player died, treat as fail (adjust to your real player health system)
	if player_in_range == null or not is_instance_valid(player_in_range):
		_fail_nora()
		return

	# Important: if charge already expired, don’t succeed
	if charge_timer and charge_timer.time_left <= 0.0:
		_fail_nora()
		return

	_success_nora()


func _on_charge_timer_timeout() -> void:
	if outcome_resolved:
		return

	# Tell boss to do final flame (then fail)
	if boss and is_instance_valid(boss) and boss.has_method("do_final_flame_at"):
		boss.call_deferred("do_final_flame_at", final_flame_marker.global_position)

	_fail_nora()

func _success_nora() -> void:
	outcome_resolved = true
	print("NoraMinigame: SUCCESS (timer ran out, player alive).")

	_stop_all_timers()
	_end_minigame_mode_on_boss()

	# Apply your success flags
	Global.nora_dead = false
	Global.affinity -= 1
	Global.persistent_saved_nora = true
	Global.check_100_percent_completion()
	Global.save_persistent_data()
	Global.ult_magus_form = true
	Global.remove_quest_marker("Meet the Magus King")

	# start Dialogic and wait for finish
	#if Dialogic.timeline_ended.is_connected(_on_nora_save_finished):
	#	Dialogic.timeline_ended.disconnect(_on_nora_save_finished)
	#Dialogic.timeline_ended.connect(_on_nora_save_finished)

	#Dialogic.start("timeline16_5M", false)
	_show_ui(false)
	if player_in_range:
		player_in_range.set_physics_process(true)
		player_in_range.velocity = Vector2.ZERO
		
	boss.queue_free()
	
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

func _fail_nora() -> void:
	outcome_resolved = true
	print("NoraMinigame: FAIL (charge expired or player died).")

	_stop_all_timers()
	_end_minigame_mode_on_boss()

	# Apply your fail flags
	Global.nora_dead = true
	Global.ult_magus_form = true
	Global.remove_quest_marker("Meet the Magus King")

	#if Dialogic.timeline_ended.is_connected(_on_nora_dead_finished):
	#	Dialogic.timeline_ended.disconnect(_on_nora_dead_finished)
	#Dialogic.timeline_ended.connect(_on_nora_dead_finished)

	#Dialogic.start("timeline16_5MV2", false)
	
	_show_ui(false)
	if player_in_range:
		player_in_range.set_physics_process(true)
		player_in_range.velocity = Vector2.ZERO
	
	boss.queue_free()
	
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
				
func _stop_all_timers() -> void:
	if success_timer: success_timer.stop()
	if charge_timer: charge_timer.stop()


func _end_minigame_mode_on_boss() -> void:
	# hide platforms after resolve (optional)
	_set_platforms_enabled(false)

	# tell boss to exit minigame mode (optional)
	if boss and is_instance_valid(boss) and boss.has_method("stop_nora_minigame"):
		boss.call_deferred("stop_nora_minigame")


# ----------------------------
# DIALOGIC FINISHED HANDLERS (LIKE YOUR VALENTINA EXAMPLE)
# ----------------------------



func _restore_player_camera() -> void:
	if boss_camera:
		boss_camera.enabled = false

	if player_camera and is_instance_valid(player_camera):
		player_camera.enabled = true
		player_camera.make_current()
		
func _bind_boss_signals() -> void:
	if boss == null or not is_instance_valid(boss):
		return

	# Connect only once
	if boss.has_signal("minigame_head_hit"):
		if not boss.minigame_head_hit.is_connected(_on_boss_minigame_head_hit):
			boss.minigame_head_hit.connect(_on_boss_minigame_head_hit)

func _on_boss_minigame_head_hit() -> void:
	if outcome_resolved:
		return
	if not charge_timer:
		return

	# Reset back to full time
	charge_timer.start(charge_timer.wait_time)

	# Optional: tiny UI feedback
	if charge_label:
		charge_label.text = "CHARGE: %02d" % int(charge_timer.wait_time)

