extends MasterCutscene

#var _has_been_triggered: bool = false
#@onready var collision_shape: CollisionShape2D = $CollisionShape2D
#@export var play_only_once: bool = true

var player_in_range: Node = null
var previous_player_camera: Camera2D = null

@onready var transition_manager = get_node("/root/TransitionManager")

# --- Optional camera / intro animation ---
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var boss_camera: Camera2D = $BossCamera2D

# --- Boss spawn / timers / UI ---
@onready var boss_spawn_marker: Marker2D = $BossSpawnMarker
@onready var boss_timer: Timer = $BossTimer        # acts as fail timer
#@onready var health_spawn_marker: Marker2D = $HealthSpawnMarker
@onready var health_timer: Timer = $HealthTimer

@onready var timer_label: Label = $CanvasLayer/TimerLabel
@onready var timer_color: ColorRect = $CanvasLayer/ColorRect

# --- Boss / health pickup ---
@export var boss_scene: PackedScene                 # assign a simple BaseEnemy scene in Inspector
@onready var health_spawn_marker: Marker2D = $HealthSpawnMarker
@export var health_pickup_scene: PackedScene = preload("res://scenes/objects/health_pickup.tscn")

var boss_instance: Node2D = null
var current_health_pickup: Node2D = null

var battle_active: bool = false
var battle_cancelled_on_player_death: bool = false

# Barriers that block player in arena during boss fight
@export var boss_barriers: Array[NodePath] = []

# Story / route control
var battle_used_fail_route: bool = false

@export var new_cutscene_path: NodePath

@onready var nataly: Sprite2D = $Nataly
@onready var maya: Sprite2D = $Maya
@onready var lux: Sprite2D = $"Replica Fini"
@onready var gawr: Node2D = $BodyPivot

@onready var marker1: Marker2D = $Marker2D

func _ready() -> void:
	# Timer label hidden until battle starts
	cutscene_name = "BossMagus1Cutscene"
	play_only_once = true
	_reset_visuals()
	# Setup battle specific components
	if timer_label:
		timer_label.visible = false
	if timer_color:
		timer_color.visible = false
	
	if boss_timer:
		boss_timer.one_shot = true
		if not boss_timer.timeout.is_connected(_on_boss_timer_timeout):
			boss_timer.timeout.connect(_on_boss_timer_timeout)
		#boss_timer.wait_time = 30.0  # 2 minutes
		#boss_timer.timeout.connect(_on_boss_timer_timeout)
	
	if health_timer:
		health_timer.one_shot = false
		#health_timer.wait_time = 30.0  # drop every 30 seconds
		if not health_timer.timeout.is_connected(_on_health_timer_timeout):
			health_timer.timeout.connect(_on_health_timer_timeout)
			
	#_deactivate_barriers()
	_reset_for_retry()
	
	# Call parent ready
	super._ready()

func _reset_for_retry() -> void:
	# Only reset if the boss is NOT permanently finished
	# (adjust this condition if you have a different “boss cleared” flag)
	if Global.meet_replica and Global.timeline > 6.5:
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
	if health_timer:
		health_timer.stop()
	
	_deactivate_barriers()
	
	if timer_label:
		timer_label.visible = false
	if timer_color:
		timer_color.visible = false
		

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
	if (body.is_in_group("player") and not _has_been_triggered):  #and Global.cutscene_finished1 == false:
		player_in_range = body
		print("Player entered cutscene trigger area. Starting cutscene.")

		#if collision_shape:
		#	collision_shape.set_deferred("disabled", true)
		#else:
		#	printerr("Cutscene Area2D: WARNING: CollisionShape2D is null, cannot disable it. Using Area2D monitoring instead.")
		#	set_deferred("monitorable", false)
		#	set_deferred("monitoring", false)

		#start_cutscene(cutscene_animation_name_to_play, 0.0)

		#if play_only_once:
		#	_has_been_triggered = true
		
		#_start_intro_cutscene()
		super._on_body_entered(body)



func _setup_cutscene():
	cutscene_name = "finiboss"
	nataly.visible = false
	maya.visible = false
	lux.visible = false
	gawr.visible = false
	play_only_once = true
	area_activation_flag = ""  # No flag required
	global_flag_to_set = ""  # We'll handle this manually
	
	# IMPORTANT: Make sure your scene has these Marker2D nodes or set positions manually

	player_markers = {
		# Example positions - adjust to match your scene
		"marker1": marker1.global_position,
		#"marker2": marker2.global_position,
		#"marker3": marker3.global_position,
		#"marker4": marker4.global_position,
		#"marker5": marker5.global_position,
		#"marker6": marker6.global_position
		
	}
	
	# Simple sequence: just play dialog
	sequence = [
		{"type": "wait", "duration": 0.5},
		{"type": "fade_out", "wait": false},
		
		#{"type": "player_face", "direction": -1}, #1 is right, -1 is left
		#{"type": "move_player", "name": "marker1",  "duration": 2, "animation": "run", "wait": false},
		#{"type": "animation", "name": "anim1", "wait": true, "loop": false},
		#{"type": "player_animation", "name": "idle",  "wait": false},
		#{"type": "animation", "name": "anim1_idle", "wait": false, "loop": true},
		#{"type": "dialog", "name": "timeline9", "wait": true},
		#{"type": "animation", "name": "anim2", "wait": true, "loop": false},
		#{"type": "player_animation", "name": "attack",  "wait": false},
		#{"type": "animation", "name": "anim2_idle", "wait": false, "loop": true},
		{"type": "dialog", "name": "timeline15M", "wait": true},
		
		{"type": "wait", "duration": 0.1},		
		{"type": "fade_in"},
		#{"type": "animation", "name": "anim3", "wait": false, "loop": false},
		

	]

func _on_cutscene_start():
	print("Cutscenefiniboss: Starting")
	# Player reference is already stored in _player_ref by parent class
	if _player_ref:
		player_in_range = _player_ref
		print("Cutscenefiniboss: Player reference stored: ", player_in_range.name)

func _on_cutscene_end():
	print("Cutscenefiniboss: Finished")
	nataly.visible = false
	maya.visible = false
	lux.visible = false
	gawr.visible = false
	# Set timeline
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
	#Global.affinity += 1
	Global.increment_kills()
	Global.is_boss_battle = false
	Global.ult_magus_form = true
	
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
				
	# Gawr win branch dialog





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
	#Global.affinity -= 1
	
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
