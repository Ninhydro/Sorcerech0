extends MasterCutscene

#var _has_been_triggered: bool = false
#@onready var collision_shape: CollisionShape2D = $CollisionShape2D
#@export var play_only_once: bool = true

var player_in_range: Node = null

# --- Boss / cutscene stuff ---
@onready var anim_player: AnimationPlayer = $AnimationPlayer
#@onready var boss_camera: Camera2D = $Camera2D
@onready var boss_spawn_marker: Marker2D = $BossSpawnMarker
@onready var boss_timer: Timer = $BossTimer
@onready var timer_label: Label = $CanvasLayer/TimerLabel
@onready var timer_color = $CanvasLayer/ColorRect

var previous_player_camera: Camera2D = null
var boss_instance: Node = null
var battle_active: bool = false

# Boss scene to spawn
const BOSS_SCENE: PackedScene = preload("res://scenes/enemies/MagusSoldierEnemy.tscn")

# Optional: paths to next cutscene nodes (set in Inspector later)
@export var success_cutscene_path: NodePath
@export var fail_cutscene_path: NodePath
@export var boss_barriers: Array[NodePath] = []

var battle_cancelled_on_player_death: bool = false

@onready var alyra: Sprite2D = $Alyra
@onready var varek: Sprite2D = $Varek_soldier


func _ready() -> void:
	# Timer label hidden until battle starts
	cutscene_name = "Boss1Cutscene"
	play_only_once = true
	
	# Setup battle specific components
	if timer_label:
		timer_label.visible = false
	if timer_color:
		timer_color.visible = false
	
	if boss_timer:
		boss_timer.one_shot = true
		boss_timer.wait_time = 60.0  # 2 minutes
		boss_timer.timeout.connect(_on_boss_timer_timeout)
	
	_deactivate_barriers()
	_reset_for_retry()
	
	# Call parent ready
	super._ready()

func _reset_for_retry() -> void:
	# Only reset if the boss is NOT permanently finished
	# (adjust this condition if you have a different “boss cleared” flag)
	if Global.first_boss_dead and Global.timeline > 5.2:
		# Boss already truly done → you may even want to queue_free() this trigger
		print("Boss1: already cleared, leaving trigger disabled.")
		collision_shape.disabled = true
		return

	print("Boss1: resetting state for retry")
	_has_been_triggered = false
	battle_active = false
	battle_cancelled_on_player_death = false
	boss_instance = null
	
	if boss_timer:
		boss_timer.stop()
	
	_deactivate_barriers()
	
	if timer_label:
		timer_label.visible = false
	if timer_color:
		timer_color.visible = false
		
func _process(delta: float) -> void:
	# Enable trigger only on specific timeline
	if Global.timeline == 5:
		if collision_shape.disabled:
			print("Boss1: timeline=5 but collision_shape is disabled")
		collision_shape.disabled = false
	else:
		if not collision_shape.disabled:
			print("Boss1: timeline!=5 (", Global.timeline, "), disabling trigger")
		collision_shape.disabled = true
		
	if Global.timeline == 6:
		_deactivate_barriers()
		
	
	# Update timer label during battle
	if battle_active and boss_timer and timer_label:
		var remaining: int = int(ceil(boss_timer.time_left))
		var minutes: int = remaining / 60
		var seconds: int = remaining % 60
		timer_label.text = "%02d:%02d" % [minutes, seconds]


func _on_body_entered(body: Node) -> void:
	print("Boss1: body_entered, has_been_triggered=", _has_been_triggered, " timeline=", Global.timeline)
	if body.is_in_group("player") and not _has_been_triggered:
		player_in_range = body
		print("Player entered boss cutscene trigger area. Starting intro cutscene.")

		if collision_shape:
			collision_shape.set_deferred("disabled", true)
		else:
			printerr("Cutscene Area2D: CollisionShape2D is null, disabling monitoring instead.")
			set_deferred("monitorable", false)
			set_deferred("monitoring", false)

		if play_only_once:
			_has_been_triggered = true

		#start_intro_cutscene()
		super._on_body_entered(body)

func _setup_cutscene():
	cutscene_name = "magusbosspart1"
	alyra.visible = false
	varek.visible = false
	play_only_once = true
	area_activation_flag = ""  # No flag required
	global_flag_to_set = ""  # We'll handle this manually
	
	# IMPORTANT: Make sure your scene has these Marker2D nodes or set positions manually

	
	
	# Simple sequence: just play dialog
	sequence = [
		{"type": "wait", "duration": 0.5},
		{"type": "fade_out", "wait": false},
		
		{"type": "player_face", "direction": -1}, #1 is right, -1 is left
		{"type": "player_animation", "name": "idle",  "wait": false},
		{"type": "animation", "name": "anim1", "wait": true, "loop": false},
		{"type": "animation", "name": "anim1_idle", "wait": false, "loop": true},
		{"type": "dialog", "name": "timeline9", "wait": true},
		
		{"type": "wait", "duration": 0.5},		
		{"type": "fade_in"},
		{"type": "animation", "name": "anim2", "wait": false, "loop": false},
		

	]

func _on_cutscene_start():
	print("Cutscene1: Starting")
	# Player reference is already stored in _player_ref by parent class
	if _player_ref:
		player_in_range = _player_ref
		print("Cutscene1: Player reference stored: ", player_in_range.name)

func _on_cutscene_end():
	print("Cutscene1: Finished")
	alyra.visible = false
	varek.visible = false
	# Set timeline
	start_boss_battle()

#func start_intro_cutscene() -> void:
#	Global.is_cutscene_active = true  

	# --- Remember player's camera (but don't touch its 'current' flag) ---
#	if player_in_range:
#		var player_cam: Camera2D = player_in_range.get_node_or_null("Camera2D")
#		if player_cam:
#			previous_player_camera = player_cam
	
	# --- Switch camera to boss camera ---
#	if boss_camera:
#		boss_camera.make_current()

	# --- Optional intro animation (can be empty for now) ---
#	if anim_player and anim_player.has_animation("intro"):
#		anim_player.play("intro")
		# await anim_player.animation_finished  

	# --- Start dialogic intro ---
#	if Dialogic.timeline_ended.is_connected(_on_dialogic_finished):
#		Dialogic.timeline_ended.disconnect(_on_dialogic_finished)
#	Dialogic.timeline_ended.connect(_on_dialogic_finished)

#	Dialogic.start("timeline9", false)  

#func _on_dialogic_finished(_timeline_name: String = "") -> void:
#	print("Boss intro Dialogic timeline finished. Starting battle.")

#	Global.is_cutscene_active = false

#	Dialogic.clear(Dialogic.ClearFlags.FULL_CLEAR)
	
#	if Dialogic.timeline_ended.is_connected(_on_dialogic_finished):
#		Dialogic.timeline_ended.disconnect(_on_dialogic_finished)

#	start_boss_battle()


func start_boss_battle() -> void:
	# Spawn boss at marker
	battle_cancelled_on_player_death = false   # 🔹 reset
	Global.health = Global.health_max
	Global.player.health_changed.emit(Global.health, Global.health_max) 
	if not BOSS_SCENE:
		printerr("Boss scene could not be loaded!")
		return
	
	boss_instance = BOSS_SCENE.instantiate()
	if boss_instance == null:
		printerr("Failed to instance boss scene.")
		return

	var parent := get_parent()
	if parent:
		parent.add_child(boss_instance)
	else:
		get_tree().current_scene.add_child(boss_instance)

	if boss_spawn_marker:
		boss_instance.global_position = boss_spawn_marker.global_position
	
	# Connect to boss death (using tree_exited as generic hook)
	if not boss_instance.tree_exited.is_connected(_on_boss_died):
		boss_instance.tree_exited.connect(_on_boss_died)

	# Start timer + show label
	battle_active = true
	if boss_timer:
		boss_timer.start()
	if timer_label:
		timer_label.visible = true
	if timer_color:
		timer_color.visible = true
	_activate_barriers()
	print("Boss battle started. 2-minute timer ticking.")


func _on_boss_timer_timeout() -> void:
	# Timer finished; check if boss is still alive
	if not battle_active or battle_cancelled_on_player_death:
		return
	
	battle_active = false
	
	var boss_alive := is_instance_valid(boss_instance)
	if boss_alive:
		print("Boss survived the timer. Player failed condition.")
		
		if boss_instance:
			boss_instance.queue_free()
			boss_instance = null
		
		_handle_battle_fail()
	else:
		print("Timer finished but boss is already dead. Treat as success.")
		_handle_battle_success()



func _on_boss_died() -> void:
	# Called when boss node leaves the tree
	if not battle_active:
		boss_instance = null
		return
	
	if battle_cancelled_on_player_death:
		print("Boss1: Boss freed after player death, ignoring.")
		boss_instance = null
		return
	
	print("Boss defeated within time!")
	battle_active = false
	
	if boss_timer:
		boss_timer.stop()
	
	boss_instance = null
	_handle_battle_success()
	

func _handle_battle_success() -> void:
	# Global changes for killing boss in time
	Global.timeline = 5.2
	#Global.affinity += 1
	Global.increment_kills()
	Global.first_boss_dead = true
	_finish_battle_and_start_outro(true)


func _handle_battle_fail() -> void:
	# Global changes for failing to kill boss in time
	#BOSS_SCENE.queue_free()
	Global.timeline = 5.2
	#Global.affinity -= 1
	Global.first_boss_dead = false
	_finish_battle_and_start_outro(false)


func _finish_battle_and_start_outro(success: bool) -> void:
	# Hide timer label
	if not Global.playerAlive or Global.health <= 0:
		print("Boss1: Player is dead, skipping outro cutscene and boss2 trigger.")
		return
		
	if timer_label:
		timer_label.visible = false
	if timer_color:
		timer_color.visible = false

	# Optionally switch camera back to player camera now
	#if previous_player_camera:
	#	previous_player_camera.make_current()
	#elif player_in_range:
	#	var player_cam: Camera2D = player_in_range.get_node_or_null("Camera2D")
	#	if player_cam:
	#		player_cam.make_current()

	# Choose node path based on success/fail
	var node_path: NodePath = success_cutscene_path if success else fail_cutscene_path

	if node_path != NodePath("") and has_node(node_path):
		var cs_node: Node = get_node(node_path)
		if cs_node.has_method("start_cutscene"):
			cs_node.call("start_cutscene")
		else:
			if cs_node is CanvasItem:
				cs_node.visible = true
	else:
		var branch_text := "SUCCESS" if success else "FAIL"
		print("No next cutscene node assigned for ", branch_text, " branch yet.")


func _on_body_exited(body: Node) -> void:
	pass

func _activate_barriers() -> void:
	for path in boss_barriers:
		if has_node(path):
			var b = get_node(path)
			if b is CollisionObject2D:
				b.set_deferred("collision_layer", 1)  # enable collision
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

func cancel_boss_battle_on_player_death() -> void:
	if not battle_active:
		return
	
	print("Boss1: Battle cancelled due to player death.")
	battle_active = false
	battle_cancelled_on_player_death = true
	
	Global.timeline = 5
	Global.first_boss_dead = false
	Global.alyra_dead = false
	
	# Stop timer
	if boss_timer:
		boss_timer.stop()
	
	# Disconnect and free boss, but DO NOT call success/fail handlers
	if boss_instance and is_instance_valid(boss_instance):
		if boss_instance.tree_exited.is_connected(_on_boss_died):
			boss_instance.tree_exited.disconnect(_on_boss_died)
		boss_instance.queue_free()
		boss_instance = null
	
	# Hide UI + barriers and give camera back to player
	if timer_label:
		timer_label.visible = false
	if timer_color:
		timer_color.visible = false
	
	_deactivate_barriers()
	
	if previous_player_camera:
		previous_player_camera.make_current()
	elif player_in_range:
		var player_cam: Camera2D = player_in_range.get_node_or_null("Camera2D")
		if player_cam:
			player_cam.make_current()

