extends Area2D

var _has_been_triggered: bool = false
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@export var play_only_once: bool = true

var player_in_range: Node = null

# --- Boss 2 stuff ---
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var boss2_spawn_marker: Marker2D = $Boss2SpawnMarker
@onready var boss2_timer: Timer = $Boss2Timer
@onready var timer_label: Label = $CanvasLayer/TimerLabel
@onready var timer_color = $CanvasLayer/ColorRect


var boss2_scene: PackedScene    = preload("res://scenes/enemies/CyberSoldierEnemy.tscn")
@export var next_cutscene_path: NodePath   # optional: cutscene after boss2

var boss2_instance: Node = null
var battle_active: bool = false

var battle_cancelled_on_player_death: bool = false

func _ready() -> void:
	# Only active when Global.timeline == 5.2
	
	if timer_label:
		timer_label.visible = false
	if timer_color:
		timer_color.visible = false
	
	if boss2_timer:
		boss2_timer.one_shot = true
		boss2_timer.wait_time = 60.0   # 2 minutes (change if you want 60s)
		
		# 🔹 Make sure timeout is connected
		if not boss2_timer.timeout.is_connected(_on_boss2_timer_timeout):
			boss2_timer.timeout.connect(_on_boss2_timer_timeout)


func _process(delta: float) -> void:
	# Enable trigger only on specific timeline
	if Global.timeline == 5.2:
		collision_shape.disabled = false
	else:
		collision_shape.disabled = true
	
	# Update timer label during battle
	if battle_active and boss2_timer and timer_label:
		var remaining: int = int(ceil(boss2_timer.time_left))
		var minutes: int = remaining / 60
		var seconds: int = remaining % 60
		timer_label.text = "%02d:%02d" % [minutes, seconds]


func _on_body_entered(body: Node) -> void:
	#if body.is_in_group("player") and not _has_been_triggered:
	#	player_in_range = body
	#	if collision_shape:
	#		collision_shape.set_deferred("disabled", true)
	#	else:
	#		printerr("Cutscene2: CollisionShape2D is null, disabling monitoring instead.")
	#		set_deferred("monitorable", false)
	#		set_deferred("monitoring", false)
		
	#	if play_only_once:
	#		_has_been_triggered = true
	pass	
	#	start_cutscene()


# This can be called from boss1 script to go straight into this scene:
#   cutscene2_node.start_cutscene()
func start_cutscene() -> void:
	# If no player stored (e.g. called directly), try to find one
	#var tree := get_tree()
	#if tree == null:
	#	print("Boss2Cutscene: start_cutscene() called but node not in scene tree, ignoring.")
	#	return

	# If no player stored (e.g. called directly), try to find one
	#if player_in_range == null:
	#	var players := tree.get_nodes_in_group("player")
	#	if players.size() > 0:
	#		player_in_range = players[0]
	#	else:
	#		print("Boss2Cutscene: No player found in group 'player', aborting.")
	#		return
	Global.is_cutscene_active = true

	# Choose dialog based on Global.first_boss_dead
	if Dialogic.timeline_ended.is_connected(_on_dialogic_finished):
		Dialogic.timeline_ended.disconnect(_on_dialogic_finished)
	Dialogic.timeline_ended.connect(_on_dialogic_finished)
	
	if Global.first_boss_dead:
		Dialogic.start("timeline10v2", false)
	else:
		Dialogic.start("timeline10", false)

	# Optional: play different animations here:
	# if anim_player:
	#     if Global.first_boss_dead and anim_player.has_animation("intro_alyra_dead"):
	#         anim_player.play("intro_alyra_dead")
	#     elif not Global.first_boss_dead and anim_player.has_animation("intro_alyra_alive"):
	#         anim_player.play("intro_alyra_alive")


func _on_dialogic_finished(_timeline_name: String = "") -> void:
	print("Cutscene2: Dialogic timeline finished, starting Boss 2 battle.")
	
	Global.is_cutscene_active = false

	Dialogic.clear(Dialogic.ClearFlags.FULL_CLEAR)
	
	if Dialogic.timeline_ended.is_connected(_on_dialogic_finished):
		Dialogic.timeline_ended.disconnect(_on_dialogic_finished)

	start_boss2_battle()


func start_boss2_battle() -> void:
	battle_cancelled_on_player_death = false   # 🔹 reset
	Global.health = Global.health_max
	Global.player.health_changed.emit(Global.health, Global.health_max) 
	if boss2_scene == null:
		printerr("Cutscene2: boss2_scene is not assigned in the Inspector!")
		return
	
	boss2_instance = boss2_scene.instantiate()
	if boss2_instance == null:
		printerr("Cutscene2: Failed to instance boss2_scene.")
		return
	
	var parent := get_parent()
	if parent:
		parent.add_child(boss2_instance)
	else:
		get_tree().current_scene.add_child(boss2_instance)
	
	if boss2_spawn_marker:
		boss2_instance.global_position = boss2_spawn_marker.global_position
	
	# Listen for boss2 death (tree_exited works as generic signal)
	if not boss2_instance.tree_exited.is_connected(_on_boss2_died):
		boss2_instance.tree_exited.connect(_on_boss2_died)
	
	# Start timer + show label
	battle_active = true
	if boss2_timer:
		boss2_timer.start()
	if timer_label:
		timer_label.visible = true
	if timer_color:
		timer_color.visible = true
	
	print("Boss 2 battle started. 2-minute timer ticking.")


func _on_boss2_timer_timeout() -> void:
	print("DEBUG: Boss2 timer timeout fired")
	if not battle_active or battle_cancelled_on_player_death:
		return
	
	battle_active = false
	
	var boss_alive := is_instance_valid(boss2_instance)
	if boss_alive:
		print("Boss 2 survived timer. Player failed condition.")
		if boss2_instance:
			boss2_instance.queue_free()
			boss2_instance = null
		_handle_boss2_fail()
	else:
		print("Timer finished but Boss 2 already dead. Treat as success.")
		_handle_boss2_success()


func _on_boss2_died() -> void:
	if not battle_active:
		boss2_instance = null
		return
	
	if battle_cancelled_on_player_death:
		print("Boss2: Boss freed after player death, ignoring.")
		boss2_instance = null
		return
	
	print("Boss 2 defeated within time!")
	battle_active = false
	
	if boss2_timer:
		boss2_timer.stop()
	
	boss2_instance = null
	_handle_boss2_success()


func _handle_boss2_success() -> void:
	# Player killed boss2 within time
	Global.timeline = 5.3
	Global.affinity -= 1
	Global.increment_kills()
	Global.alyra_dead = false
	
	_finish_battle_and_start_outro()


func _handle_boss2_fail() -> void:
	# Player failed to kill boss2 in time
	Global.timeline = 5.3
	Global.affinity += 1
	Global.alyra_dead = true
	
	_finish_battle_and_start_outro()
 
func _finish_battle_and_start_outro() -> void:
	if timer_label:
		timer_label.visible = false
	if timer_color:
		timer_color.visible = false
	# Optionally re-lock or unlock gameplay here if needed
	# Global.is_cutscene_active = true
	

	if next_cutscene_path != NodePath("") and has_node(next_cutscene_path):
		var cs_node: Node = get_node(next_cutscene_path)
		print("DEBUG: Starting final cutscene from boss2, alyra_dead = ", Global.alyra_dead)
		if cs_node.has_method("start_cutscene"):
			cs_node.call("start_cutscene")
		elif cs_node is CanvasItem:
			cs_node.visible = true
	else:
		print("Cutscene2: No next cutscene node assigned after Boss 2.")

func _on_body_exited(body: Node) -> void:
	pass


func _on_boss_2_timer_timeout():
	print("DEBUG: Boss2 timer timeout fired")  # just to be sure
	if not battle_active:
		print("DEBUG: battle_active is false, ignoring timeout")
		return
	
	battle_active = false
	
	var boss_alive := is_instance_valid(boss2_instance)
	if boss_alive:
		print("Boss 2 survived timer. Player failed condition.")
		if boss2_instance:
			boss2_instance.queue_free()
			boss2_instance = null
		_handle_boss2_fail()
	else:
		print("Timer finished but Boss 2 already dead. Treat as success.")
		_handle_boss2_success()

func cancel_boss2_battle_on_player_death() -> void:
	if not battle_active:
		return
	
	print("Boss2: Battle cancelled due to player death.")
	battle_active = false
	battle_cancelled_on_player_death = true
	
	Global.timeline = 5
	Global.first_boss_dead = false
	Global.alyra_dead = false
	
	if boss2_timer:
		boss2_timer.stop()
	
	if boss2_instance and is_instance_valid(boss2_instance):
		if boss2_instance.tree_exited.is_connected(_on_boss2_died):
			boss2_instance.tree_exited.disconnect(_on_boss2_died)
		boss2_instance.queue_free()
		boss2_instance = null
	
	if timer_label:
		timer_label.visible = false
	if timer_color:
		timer_color.visible = false
		
