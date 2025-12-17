extends CharacterBody2D
class_name GigasterBoss

signal boss_died

# ----------------------------
# CONFIG
# ----------------------------
@export var max_health: int = 400
@export var walk_speed: float = 60.0

@export var slam_damage: int = 12
@export var head_laser_damage: int = 16
@export var surround_laser_damage: int = 16

@export var slam_windup_time: float = 0.2
@export var slam_stun_time: float = 3.0 #freeze/stun
@export var slam_return_time: float = 0.6
@export var slam_hit_active_time: float = 0.2

@export var laser_lower_time: float = 0.4
@export var laser_cycle_time: float = 1.0
@export var laser_recover_time: float = 0.8

@export var laser_start_time: float = 0.20
@export var laser_stop_time: float = 0.20
@export var breath_vulnerable_time: float = 1.0 # after stop, boss stays in breath_fire pose

@export var hurt_lock_time: float = 0.15
@export var attack_cooldown: float = 0.6

@export var chase_stop_distance: float = 220.0
@export var chase_deadzone: float = 20.0
@export var chase_enabled: bool = true

# attack chances
@export var phase1_laser_chance := 0.25  # phase1: 25% head laser, 75% slam
@export var phase2_surround_chance := 0.25 # phase2: 25% surround lasers, 75% slam

# phase transition
@export var phase2_trigger_ratio := 0.5  # at 50% hp
var _phase := 1
var _did_phase2_transition := false

# summon intermission
@export var summon_enemy_scene: PackedScene
@export var summon_marker_path: NodePath
@export var intermission_anim := "die"     # “die” used as stunned/intermission pose
@export var resume_anim := "idle"

# surround lasers
@export var laser_column_scene: PackedScene    # (optional) a simple Area2D laser column
@export var surround_markers_root_path: NodePath
#@export var surround_telegraph_time := 0.35
@export var surround_fire_time := 0.25
@export var surround_gap_time := 0.20

@export var align_tolerance: float = 30.0

# slam accuracy (optional lead)
@export var slam_lead_px := 0.0 # try 20..60 if player is fast

# Flash tuning
@export var flash_down_time: float = 0.10
@export var flash_brightness_boost := 0.01

# ----------------------------
# STATE
# ----------------------------
var health: int = 0
var dead := false
var taking_damage := false
var _ai_running := false
var _attack_running := false
var _next_attack_time: float = 0.0
var invulnerable := false

var player: Node2D

var _move_active := false
var _target_x := 0.0
var _facing := 1

var _summon_ref: Node = null

# ----------------------------
# NODES
# ----------------------------
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var body_pivot: Node2D = $BodyPivot

@onready var head_weakspot: Area2D = $BodyPivot/HeadPivot/HeadWeakspot
@onready var left_hitbox: Area2D = $BodyPivot/LeftArm/LeftHand/LeftSlamHitbox
@onready var left_weakspot: Area2D = $BodyPivot/LeftArm/LeftHand/LeftWeakspot
@onready var right_hitbox: Area2D = $BodyPivot/RightArm/RightHand/RightSlamHitbox
@onready var right_weakspot: Area2D = $BodyPivot/RightArm/RightHand/RightWeakspot

@onready var laser_hitbox: Area2D = $BodyPivot/HeadPivot/MouthMarker/LaserPivot/LaserHitbox
@onready var laser_pivot: Node2D = $BodyPivot/HeadPivot/MouthMarker/LaserPivot
@onready var mouth_marker: Marker2D = $BodyPivot/HeadPivot/MouthMarker
@onready var fire_shape: CollisionShape2D = $BodyPivot/HeadPivot/MouthMarker/LaserPivot/LaserHitbox/CollisionShape2D
@onready var laser_sprite: AnimatedSprite2D = $BodyPivot/HeadPivot/MouthMarker/LaserPivot/LaserSprite

@onready var _summon_marker: Marker2D = $SummonMarker
var _surround_root: Node = null

# OPTIONAL (for more accurate slam target): put these Marker2D under each hand,
# at the exact slam contact point (e.g. palm center).
@export var left_slam_marker: NodePath
@export var right_slam_marker: NodePath
var _left_slam_marker_node: Marker2D
var _right_slam_marker_node: Marker2D

# ----------------------------
# FLASH SYSTEM
# ----------------------------
var _flash_targets: Array[CanvasItem] = []
var _flash_mats: Array[ShaderMaterial] = []
var _flash_tween: Tween

@export var weakspot_hit_cooldown := 0.12
var _last_hit_time_by_attacker := {}

var _fire_base_scale := Vector2.ONE
var _fire_base_rot := 0.0
var _fire_base_shape_data = null # stores size/height depending on shape
@export var fire_angle_deg := 30.0
@export var fire_length_scale := 3.0   # how long the flame stretches
@export var fire_width_scale := 1.0

# --- MOVE GOAL MODE ---
const MOVE_GOAL_CENTER := 0
const MOVE_GOAL_SLAM_ALIGN := 1
#const MOVE_GOAL_BREATH_SPACE := 2

var _move_goal_type := MOVE_GOAL_CENTER
var _move_goal_player_x := 0.0
var _move_goal_use_left := true

@export var slam_align_tolerance := 24.0   # tighter than align_tolerance feels better
@export var slam_max_move_ms := 2200       # increase to reduce TIMEOUT spam

@export var breath_preferred_distance := 300.0  # boss tries to be at least this far before breathing
@export var breath_backstep_px := 200.0         # step back amount if too close

@export var breath_chance := 0.25          # lower than 0.333 if you want
@export var max_breath_streak := 1         # 1 = never twice in a row, 2 = max 2 in a row

var _breath_streak := 0

@export var breath_min_gap := 2.5 # seconds
var _next_breath_allowed_time := 0.0
@export var fire_extra_length_px := 80.0  # tweak this

signal minigame_head_hit

@export var minigame_slam_range := 220.0
var _minigame_charge_time := 10.0
var _minigame_final_marker: Node2D = null
var _minigame_doing_slam := false

@export var minigame_slam_cooldown := 2.5
var _next_minigame_slam_time := 0.0

var _force_facing_left := false

@export var surround_telegraph_time := 1.0
@export var laser_on_time := 0.6
@export var laser_off_gap := 0.35

@export var slam_high_y_threshold := -40.0

func _is_high_slam() -> bool:
	if player == null:
		return false
	return (player.global_position.y - global_position.y) < slam_high_y_threshold

# ----------------------------
# HELPERS
# ----------------------------

func _get_surround_laser_markers() -> Array[Marker2D]:
	var markers: Array[Marker2D] = []
	
	# Try different possible locations
	if has_node("SurroundLaserMarkers"):
		var root = $SurroundLaserMarkers
		for child in root.get_children():
			if child is Marker2D:
				markers.append(child)
	
	# Also check the laser pivot path
	if has_node("LaserPivot"):
		var pivot = $LaserPivot
		for child in pivot.get_children():
			if child is Marker2D and child.name.contains("Laser_"):
				markers.append(child)
	
	print("🎯 Found ", markers.size(), " surround laser markers")
	return markers
	
func _ts() -> float:
	return max(Global.global_time_scale, 0.05)

func _get_player() -> Node2D:
	var p := Global.playerBody as Node2D
	if p == null or not is_instance_valid(p):
		p = get_tree().get_first_node_in_group("player") as Node2D
	return p

func _ready() -> void:
	health = max_health
	randomize()

	_summon_marker = get_node_or_null(summon_marker_path) as Marker2D
	_surround_root = get_node_or_null(surround_markers_root_path)
	
	_left_slam_marker_node = get_node_or_null(left_slam_marker) as Marker2D
	_right_slam_marker_node = get_node_or_null(right_slam_marker) as Marker2D

	_disable_all_hitboxes()
	_disable_all_weakspots()
	_stop_flame_immediately()

	# connect weakspots (area_entered only)
	_connect_weakspot(head_weakspot)
	_connect_weakspot(left_weakspot)
	_connect_weakspot(right_weakspot)

	# connect attack hitboxes -> damage player
	if left_hitbox:
		left_hitbox.body_entered.connect(_on_attack_hitbox_body_entered.bind(left_hitbox))
		left_hitbox.add_to_group("boss_hitbox")  # ADD THIS
		print("✅ Left hitbox added to boss_hitbox group")
	
	if right_hitbox:
		right_hitbox.body_entered.connect(_on_attack_hitbox_body_entered.bind(right_hitbox))
		right_hitbox.add_to_group("boss_hitbox")  # ADD THIS
		print("✅ Right hitbox added to boss_hitbox group")
	
	if laser_hitbox:
		laser_hitbox.body_entered.connect(_on_attack_hitbox_body_entered.bind(laser_hitbox))
		laser_hitbox.add_to_group("boss_hitbox")  # ADD THIS
		print("✅ Laser hitbox added to boss_hitbox group")

	#_force_fire_nodes_clean()
	
	#if flame_sprite:
	#	flame_sprite.z_index = 100
	#	flame_sprite.z_as_relative = true
		
	#if fire_pivot:
	#	_fire_base_scale = fire_pivot.scale
	#	_fire_base_rot = fire_pivot.rotation

# Cache base collision shape size so we can stretch it
	#if fire_shape and fire_shape.shape:
	#	if fire_shape.shape is RectangleShape2D:
	#		_fire_base_shape_data = (fire_shape.shape as RectangleShape2D).size
	#	elif fire_shape.shape is CapsuleShape2D:
	#		_fire_base_shape_data = Vector2((fire_shape.shape as CapsuleShape2D).radius, (fire_shape.shape as CapsuleShape2D).height)
	#	elif fire_shape.shape is CircleShape2D:
	#		_fire_base_shape_data = (fire_shape.shape as CircleShape2D).radius
		
	_setup_flash_targets() # wraps boss visuals, but SKIPS flame sprite
	set_physics_process(true)
	set_process(true)

	print("GawrBoss READY: ", name, " flash_targets=", _flash_targets.size())


func _physics_process(delta: float) -> void:
	player = _get_player()

	if _attack_running or dead or taking_damage or Global.camouflage or player == null or not chase_enabled:
		velocity.x = 0
		move_and_slide()
		return
	
	# --- AI-Driven Movement ---
	if not _attack_running and _move_active:
		var dx_to_target := _target_x - global_position.x
		_set_facing_from_dx(dx_to_target)
		var reached := false

		if _move_goal_type == 0:
			reached = abs(dx_to_target) <= align_tolerance
		elif _move_goal_type == 1:
			var slam_x := _get_slam_point_world_x(_move_goal_use_left)
			reached = abs(_move_goal_player_x - slam_x) <= align_tolerance

		if reached:
			velocity.x = 0
			_move_active = false
			if anim.has_animation("idle"):
				anim.play("idle")
		else:
			velocity.x = sign(dx_to_target) * walk_speed * _ts()
			if anim.has_animation("walk"):
				anim.play("walk")

		move_and_slide()
		return

	# --- Normal chase ---
	var dx := player.global_position.x - global_position.x
	_set_facing_from_dx(dx)
	var adx = abs(dx)
	if adx > chase_stop_distance + chase_deadzone:
		velocity.x = sign(dx) * walk_speed * _ts()
		if anim.has_animation("walk"):
			anim.play("walk")
	else:
		velocity.x = 0
		if anim.has_animation("idle"):
			anim.play("idle")
	move_and_slide()

# ----------------------------
# BATTLE START
# ----------------------------
func reset_for_battle() -> void:
	dead = false
	invulnerable = false
	taking_damage = false
	_attack_running = false
	_move_active = false
	health = max_health
	_phase = 1
	_did_phase2_transition = false
	chase_enabled = true

	_disable_all_hitboxes()
	_disable_all_weakspots()
	_stop_flame_immediately()

	_check_hitbox_settings()

	if anim and anim.has_animation("idle"):
		anim.play("idle")

	if not _ai_running:
		_ai_running = true
		call_deferred("_start_ai")

func _start_ai() -> void:
	print("🎮 Gigaster AI LOOP STARTED. Phase: ", _phase)
	
	
	while not dead:
		player = _get_player()
		if player == null:
			await get_tree().create_timer(0.2 / _ts()).timeout
			continue

		# Intermission (summon alive)
		if invulnerable and _did_phase2_transition and _summon_ref != null and is_instance_valid(_summon_ref):
			await get_tree().process_frame
			continue

		# Trigger summon at 50%
		if (not _did_phase2_transition) and float(health) <= float(max_health) * phase2_trigger_ratio:
			print("🎮 Gigaster: Health at ", health, "/", max_health, " - Starting Phase 2 intermission")
			await _start_phase2_intermission()
			_phase = 2
			print("🎮 Gigaster: Now in Phase ", _phase)
			continue

		# Wait until current attack finishes
		if _attack_running:
			await get_tree().process_frame
			continue

		# Cooldown gate
		var now := Time.get_ticks_msec() / 1000.0
		if now < _next_attack_time:
			print("⏱️ Waiting for cooldown: ", _next_attack_time - now, " seconds")

			await get_tree().process_frame
			continue
		
		# Wait until player is close enough
		var mouth_x := mouth_marker.global_position.x if mouth_marker else global_position.x
		var dist_to_player = abs(player.global_position.x - mouth_x)
		
		# If player is far, just keep looping so _physics_process handles chase/walk/idle
		if dist_to_player > chase_stop_distance:
			await get_tree().create_timer(0.5 / _ts()).timeout  # Longer wait when far
			continue

		# Small readability pause
		await get_tree().create_timer(0.12 / _ts()).timeout
		if dead: break

		# === ATTACK SELECTION BASED ON PHASE ===
		if _phase == 1:
			print("🎮 Phase 1: Choosing attack...")
			if randf() < phase1_laser_chance:
				print("🎮 Phase 1: Surround laser attack")
				await _surround_lasers_attack()
				# Head weakspot vulnerable after attack
				_enable_weakspot(head_weakspot)
				await get_tree().create_timer(breath_vulnerable_time / _ts()).timeout
				_disable_weakspot(head_weakspot)
			else:
				print("🎮 Phase 1: Slam attack")
				# CHANGED: Use aligned slam instead of regular slam
				await _slam_align_and_execute()
		else:  # Phase 2
			print("🎮 Phase 2: Choosing attack...")
			if randf() < phase2_surround_chance:
				print("🎮 Phase 2: Surround laser attack")
				await _surround_lasers_attack()
				# Head weakspot vulnerable after attack
				_enable_weakspot(head_weakspot)
				await get_tree().create_timer(breath_vulnerable_time / _ts()).timeout
				_disable_weakspot(head_weakspot)
			else:
				print("🎮 Phase 2: Slam attack")
				# CHANGED: Use aligned slam instead of regular slam
				await _slam_align_and_execute()

		_next_attack_time = (Time.get_ticks_msec() / 1000.0) + attack_cooldown

	print("🎮 Gigaster AI LOOP ENDED.")
	_ai_running = false

func _move_to_target_x(x: float, goal_type := MOVE_GOAL_CENTER, player_x_snapshot := 0.0, use_left := true) -> void:
	_target_x = x
	_move_active = true
	
	_move_goal_type = goal_type
	_move_goal_player_x = player_x_snapshot
	_move_goal_use_left = use_left
	
	print("🎯 Starting movement to target X: ", x, " goal_type: ", goal_type)
	
	# Wait until movement is complete
	#var timeout = 3.0  # 3 second timeout
	#var start_time = Time.get_ticks_msec() / 1000.0
	
	#while _move_active and not dead:
	#	await get_tree().process_frame
		
		# Timeout check
	#	var current_time = Time.get_ticks_msec() / 1000.0
	#	if current_time - start_time > timeout:
	#		print("⚠️ Movement timeout, forcing stop")
	#		_move_active = false
	#		break
func _start_phase2_intermission() -> void:
	_did_phase2_transition = true
	_phase = 2

	_attack_running = false
	_move_active = false
	chase_enabled = false
	velocity = Vector2.ZERO

	# become invincible + “die” animation as stunned pose
	invulnerable = true
	_disable_all_hitboxes()

	if anim and anim.has_animation(intermission_anim):
		anim.play(intermission_anim)

	# spawn summon
	if summon_enemy_scene == null:
		push_warning("Gigaster: summon_enemy_scene not assigned. Skipping intermission.")
		invulnerable = false
		chase_enabled = true
		return

	var s := summon_enemy_scene.instantiate()
	get_tree().current_scene.add_child(s)

	var spawn_pos := global_position
	if _summon_marker:
		spawn_pos = _summon_marker.global_position
	s.global_position = spawn_pos

	_summon_ref = s

	# wait for summon death:
	# ✅ works with either a signal or queue_free check
	if s.has_signal("died"):
		await s.died
	else:
		while is_instance_valid(s):
			await get_tree().process_frame

	# resume boss
	_summon_ref = null
	invulnerable = false
	chase_enabled = true

	if anim and anim.has_animation(resume_anim):
		anim.play(resume_anim)
# ----------------------------
# SLAM (uses ONLY your listed animations)
# ----------------------------
func _slam_attack() -> void:
	if dead or _attack_running:
		return

	_attack_running = true

	var use_left := true
	if player and is_instance_valid(player):
		use_left = player.global_position.x < global_position.x

	var is_high := _is_high_slam()

	var hitbox: Area2D = left_hitbox if use_left else right_hitbox
	var weakspot: Area2D = left_weakspot if use_left else right_weakspot

	# IMPORTANT: Stop any current movement BEFORE starting attack
	_move_active = false
	velocity.x = 0
	
	print("💥 Slam attack: left=", use_left, " high=", is_high)

	# 1) Windup animation (with high/low variants)
	if anim:
		if use_left:
			if is_high and anim.has_animation("slam_left_high"):
				anim.play("slam_left_high")
			elif anim.has_animation("slam_left"):
				anim.play("slam_left")
		else:
			if is_high and anim.has_animation("slam_right_high"):
				anim.play("slam_right_high")
			elif anim.has_animation("slam_right"):
				anim.play("slam_right")

	await get_tree().create_timer(slam_windup_time / _ts()).timeout
	if dead:
		_attack_running = false
		return

	# 2) Damage window
	print("💥 Enabling hitbox: ", hitbox.name)
	_enable_hitbox(hitbox)
	
	# Apply damage to player if close (keep your direct damage logic)
	if player and is_instance_valid(player) and player.has_method("take_damage"):
		var player_pos = player.global_position
		var hitbox_pos = hitbox.global_position
		var distance = player_pos.distance_to(hitbox_pos)
		print("🎯 Player distance to hitbox: ", distance)
		
		if distance < 120:  # Adjust based on your hitbox size
			print("💥 Applying slam damage to player")
			player.take_damage(slam_damage)
	
	await get_tree().create_timer(slam_hit_active_time / _ts()).timeout
	_disable_hitbox(hitbox)

	# 3) Stun/vulnerable phase (with high/low idle variants if available)
	print("💥 Enabling weakspot for vulnerability: ", weakspot.name)
	_enable_weakspot(weakspot)
	
	# Play idle/stunned animation if available
	if anim:
		if use_left:
			if is_high and anim.has_animation("slam_left_high_idle"):
				anim.play("slam_left_high_idle")
			elif anim.has_animation("slam_left_idle"):
				anim.play("slam_left_idle")
		else:
			if is_high and anim.has_animation("slam_right_high_idle"):
				anim.play("slam_right_high_idle")
			elif anim.has_animation("slam_right_idle"):
				anim.play("slam_right_idle")
	
	await get_tree().create_timer(slam_stun_time / _ts()).timeout
	_disable_weakspot(weakspot)

	# 4) Return animation (with high/low variants)
	if anim:
		if use_left:
			if is_high and anim.has_animation("slam_left_high_return"):
				anim.play("slam_left_high_return")
			elif anim.has_animation("slam_left_return"):
				anim.play("slam_left_return")
		else:
			if is_high and anim.has_animation("slam_right_high_return"):
				anim.play("slam_right_high_return")
			elif anim.has_animation("slam_right_return"):
				anim.play("slam_right_return")

	await get_tree().create_timer(slam_return_time / _ts()).timeout
	
	# 5) Back to idle
	if anim and anim.has_animation("idle"):
		anim.play("idle")
		
	_attack_running = false
	print("💥 Slam attack complete")

# Accurate slam targeting:
# move boss so "slam contact point" ends up at player_x (+ optional lead)
func _slam_target_x(use_left: bool) -> float:
	if player == null or not is_instance_valid(player):
		return global_position.x

	var px := player.global_position.x + slam_lead_px * float(_facing)
	var hand_x := _get_slam_point_world_x(use_left)
	return global_position.x + (px - hand_x)

func _get_slam_point_world_x(use_left: bool) -> float:
	# Prefer explicit Marker2D (best accuracy)
	if use_left and _left_slam_marker_node and is_instance_valid(_left_slam_marker_node):
		return _left_slam_marker_node.global_position.x
	if (not use_left) and _right_slam_marker_node and is_instance_valid(_right_slam_marker_node):
		return _right_slam_marker_node.global_position.x

	# Fallback to hitbox global x
	var hb: Area2D = left_hitbox if use_left else right_hitbox
	if hb and is_instance_valid(hb):
		return hb.global_position.x
	return global_position.x

func _choose_closer_hand() -> bool:
	if player == null or not is_instance_valid(player):
		return true
	var dl = abs(player.global_position.x - _get_slam_point_world_x(true))
	var dr = abs(player.global_position.x - _get_slam_point_world_x(false))
	return dl <= dr


func _head_laser_attack() -> void:
	if dead or _attack_running:
		return
	_attack_running = true

	# lower / fire / recover animations:
	if anim and anim.has_animation("laser_lower"):
		anim.play("laser_lower")
	await get_tree().create_timer(laser_lower_time / _ts()).timeout
	if dead: _attack_running = false; return

	if anim and anim.has_animation("laser_fire"):
		anim.play("laser_fire")

	await get_tree().create_timer(laser_start_time / _ts()).timeout
	_enable_hitbox(laser_hitbox)

	var t := 0.0
	while t < laser_cycle_time and not dead and not Global.camouflage:
		_update_head_laser_aim()
		await get_tree().process_frame
		t += get_process_delta_time() * _ts()

	await get_tree().create_timer(laser_stop_time / _ts()).timeout
	_disable_hitbox(laser_hitbox)

	if anim and anim.has_animation("laser_recover"):
		anim.play("laser_recover")
	await get_tree().create_timer(laser_recover_time / _ts()).timeout

	if anim and anim.has_animation("idle"):
		anim.play("idle")

	_attack_running = false

func _surround_lasers_attack() -> void:
	if dead or _attack_running:
		return

	_attack_running = true
	
	# IMPORTANT: Stop any current movement
	_move_active = false
	velocity.x = 0

	# 1) Summon animation
	if anim and anim.has_animation("summon_laser"):
		anim.play("summon_laser")
	elif anim and anim.has_animation("idle"):
		anim.play("idle")  # Fallback to idle

	await get_tree().create_timer(surround_telegraph_time / _ts()).timeout
	if dead:
		_attack_running = false
		return

	# 2) Spawn and activate lasers (keep your existing code)
	var markers := _get_surround_laser_markers()
	if markers.is_empty():
		print("⚠️ Gigaster: No surround laser markers found!")
		_attack_running = false
		return

	# Activate lasers one-by-one
	for m in markers:
		if dead:
			break
			
		var laser = _spawn_laser_at(m.global_position)
		if laser:
			print("🎯 Laser spawned at: ", m.global_position)
			laser.activate()
			
			# Keep laser active for laser_on_time
			await get_tree().create_timer(laser_on_time / _ts()).timeout
			
			# Deactivate laser
			laser.deactivate()
			
			# Wait gap before next laser
			await get_tree().create_timer(laser_off_gap / _ts()).timeout
		else:
			print("❌ Failed to spawn laser at: ", m.global_position)

	_attack_running = false
	print("💫 Surround laser attack complete")

func _get_surround_markers() -> Array[Marker2D]:
	var out: Array[Marker2D] = []
	if _surround_root:
		for c in _surround_root.get_children():
			if c is Marker2D:
				out.append(c)
	return out
	
func _breath_phase() -> void:
	
	if dead or _attack_running:
		return
	_attack_running = true

	# Face player before starting
	if player:
		_set_facing_from_dx(player.global_position.x - global_position.x)
	
	var px := player.global_position.x
	var mouth_x := mouth_marker.global_position.x if mouth_marker else global_position.x
	var dist = abs(px - mouth_x)

	if dist < breath_preferred_distance:
		var target_x := _breath_target_x(px, breath_preferred_distance)

		# move using normal goal (center tolerance)
		await _move_to_target_x(target_x, MOVE_GOAL_CENTER)
		await get_tree().create_timer(0.12 / _ts()).timeout
		if dead:
			_attack_running = false
			return
	# 1) lower
	if anim and anim.has_animation("breath_lower"):
		anim.play("breath_lower")
	await get_tree().create_timer(laser_lower_time / _ts()).timeout
	if dead:
		_attack_running = false
		return

	# 2) fire pose (cycle anim on boss)
	if anim and anim.has_animation("breath_fire"):
		anim.play("breath_fire")

	# Start flame sprite animation
	_start_flame_sprite()

	# Delay before damage starts
	await get_tree().create_timer(laser_start_time / _ts()).timeout
	_enable_hitbox(laser_hitbox)

	# Keep firing for breath_cycle_time, update aim/stretch every frame
	var t := 0.0
	while t < laser_cycle_time and not dead and not Global.camouflage:
		_update_fire_to_player()
		_ensure_flame_cycle()
		await get_tree().process_frame
		t += get_process_delta_time() * _ts()

	# Stop damage slightly before visuals stop (optional timing)
	await get_tree().create_timer(laser_stop_time / _ts()).timeout
	_disable_hitbox(laser_hitbox)
	_stop_flame_sprite()

	# ✅ PUNISH WINDOW: keep breath_fire pose and enable head weakspot
	_enable_weakspot(head_weakspot)
	await get_tree().create_timer(breath_vulnerable_time / _ts()).timeout
	_disable_weakspot(head_weakspot)

	# recover
	if anim and anim.has_animation("breath_recover"):
		anim.play("breath_recover")
	await get_tree().create_timer(laser_recover_time / _ts()).timeout

	_attack_running = false
	




func _die() -> void:
	dead = true
	_disable_all_hitboxes()
	_disable_all_weakspots()
	_stop_flame_immediately()
	chase_enabled = false
	velocity = Vector2.ZERO
	if anim and anim.has_animation("die"):
		anim.play("die")
	boss_died.emit()

# ----------------------------
# WEAKSPOT DETECTION
# ----------------------------
func _connect_weakspot(spot: Area2D) -> void:
	if spot == null:
		return
	spot.monitoring = true
	spot.monitorable = true
	if not spot.area_entered.is_connected(_on_weakspot_area_entered):
		spot.area_entered.connect(_on_weakspot_area_entered)

func _on_weakspot_area_entered(area: Area2D) -> void:
	if dead or area == null:
		return

	# ✅ Accept: melee zone, melee group, OR projectiles (has damage var / projectile group)
	var is_attack := false

	if Global.playerDamageZone and area == Global.playerDamageZone:
		is_attack = true
	elif area.is_in_group("player_attack"):
		is_attack = true
	elif area.is_in_group("player_projectile"):
		is_attack = true
	elif ("damage" in area): # <- your fireball has var damage, so this will pass
		is_attack = true

	if not is_attack:
		return

	# anti-spam per attacker instance
	var key := str(area.get_instance_id())
	var now_ms := Time.get_ticks_msec()
	if _last_hit_time_by_attacker.has(key) and (now_ms - int(_last_hit_time_by_attacker[key])) < int(weakspot_hit_cooldown * 1000.0):
		return
	_last_hit_time_by_attacker[key] = now_ms
	
	# Nora minigame: hitting head resets the charge timer (controller listens to this)


	# damage amount
	var dmg := Global.playerDamageAmount
	if "damage" in area:
		dmg = int(area.damage)

	take_damage(dmg)

# ----------------------------
# PLAYER DAMAGE FROM BOSS HITBOXES
# ----------------------------
func _on_attack_hitbox_body_entered(body: Node, source_hitbox: Area2D) -> void:
	print("🎯 Gigaster hitbox body entered: ", body.name, " hitbox: ", source_hitbox.name)
	
	if dead or body == null:
		return
		
	if not body.is_in_group("player"):
		print("❌ Not player, group check failed")
		return

	var dmg := slam_damage
	if source_hitbox == laser_hitbox:
		dmg = head_laser_damage
	
	print("💥 Gigaster dealing ", dmg, " damage to player from ", source_hitbox.name)
	
	if body.has_method("take_damage"):
		body.call("take_damage", dmg)
	else:
		print("❌ Player doesn't have take_damage method")

func _on_attack_hitbox_area_entered(area: Area2D, source_hitbox: Area2D) -> void:
	if dead or area == null:
		return

	# player hurtbox / damage receiver
	if not area.is_in_group("player_hurtbox"):
		return

	var player := area.get_parent()
	if player == null:
		return

	var dmg = surround_laser_damage if source_hitbox == laser_hitbox else slam_damage

	if player.has_method("take_damage"):
		player.take_damage(dmg)

# ----------------------------
# HITBOX HELPERS
# ----------------------------
func _enable_hitbox(box: Area2D) -> void:
	if box == null: 
		print("❌ _enable_hitbox: box is null")
		return
		
	var shape := box.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape: 
		shape.disabled = false
		print("✅ Enabled hitbox: ", box.name, " shape disabled=", shape.disabled)
	else:
		print("❌ _enable_hitbox: no shape found for ", box.name)

func _disable_hitbox(box: Area2D) -> void:
	if box == null: return
	var shape := box.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape: shape.disabled = true

func _disable_all_hitboxes() -> void:
	_disable_hitbox(left_hitbox)
	_disable_hitbox(right_hitbox)
	_disable_hitbox(laser_hitbox)

func _enable_weakspot(ws: Area2D) -> void:
	
	if ws == null: return
	ws.visible = true
	var shape := ws.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape: shape.disabled = false
	print("ENABLE WEAKSPOT:", ws.name, " disabled=", shape.disabled)


func _disable_weakspot(ws: Area2D) -> void:
	if ws == null: return
	ws.visible = false
	var shape := ws.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape: shape.disabled = true

func _disable_all_weakspots() -> void:
	_disable_weakspot(head_weakspot)
	_disable_weakspot(left_weakspot)
	_disable_weakspot(right_weakspot)

# ----------------------------
# FLASH (wrap boss visuals, but SKIP flame sprite so it stays visible)
# ----------------------------
func _setup_flash_targets() -> void:
	_flash_targets.clear()
	_flash_mats.clear()

	_collect_canvas_items_recursive(body_pivot)

	var shader := load("res://shaders/flash_white.gdshader") as Shader
	if shader == null:
		push_error("FLASH ERROR: shader not found at res://shaders/flash_white.gdshader")
		return

	for ci in _flash_targets:
		ci.use_parent_material = false

		var original_mat: Material = ci.material

		var flash_mat := ShaderMaterial.new()
		flash_mat.shader = shader
		flash_mat.set_shader_parameter("brightness_boost", flash_brightness_boost)

		# keep previous material rendering as next_pass
		flash_mat.next_pass = original_mat

		ci.material = flash_mat
		_flash_mats.append(flash_mat)

func _collect_canvas_items_recursive(node: Node) -> void:
	# ✅ Do NOT wrap FlameSprite, or it can disappear / darken
	if laser_sprite and node == laser_sprite:
		return

	if node is CanvasItem:
		_flash_targets.append(node)

	for c in node.get_children():
		_collect_canvas_items_recursive(c)

func _flash_hurt() -> void:
	if _flash_mats.is_empty():
		return

	if _flash_tween and _flash_tween.is_running():
		_flash_tween.kill()

	for m in _flash_mats:
		m.set_shader_parameter("flash_strength", 1.0)

	_flash_tween = create_tween()
	_flash_tween.tween_method(
		func(v):
			for m in _flash_mats:
				m.set_shader_parameter("flash_strength", v),
		1.0, 0.0,
		flash_down_time / _ts()
	)

# ----------------------------
# MISC
# ----------------------------
func _set_facing_from_dx(dx: float) -> void:
	
		
	var new_facing := -1 if dx < 0.0 else 1
	if new_facing == _facing:
		return
	_facing = new_facing
	if body_pivot:
		body_pivot.scale.x = abs(body_pivot.scale.x) * float(_facing)

func _stop_flame_immediately() -> void:
	if laser_sprite:
		laser_sprite.visible = false
		laser_sprite.stop()
	_force_fire_nodes_clean()
	
func _force_fire_nodes_clean() -> void:
	if laser_pivot:
		laser_pivot.position = Vector2.ZERO
		laser_pivot.rotation = 0.0
		laser_pivot.scale = Vector2.ONE
	if laser_hitbox:
		laser_hitbox.position = Vector2.ZERO
		laser_hitbox.rotation = 0.0
		laser_hitbox.scale = Vector2.ONE
	if fire_shape:
		fire_shape.position = Vector2.ZERO
		fire_shape.rotation = 0.0
	if laser_sprite:
		laser_sprite.position = Vector2.ZERO
		laser_sprite.rotation = 0.0
		laser_sprite.offset = Vector2.ZERO

func _apply_fire_transform() -> void:
	if not laser_pivot or not mouth_marker:
		return

	# Always emit from mouth marker
	laser_pivot.global_position = mouth_marker.global_position

	# Rotate ±30 degrees depending on facing
	laser_pivot.rotation = deg_to_rad(fire_angle_deg * float(_facing))

	# Stretch flame forward (local +X direction)
	laser_pivot.scale = Vector2(_fire_base_scale.x * fire_length_scale, _fire_base_scale.y * fire_width_scale)

	# Stretch collision shape to match visuals
	if fire_shape and fire_shape.shape and _fire_base_shape_data != null:
		if fire_shape.shape is RectangleShape2D:
			var rect := fire_shape.shape as RectangleShape2D
			var base_size: Vector2 = _fire_base_shape_data
			rect.size = Vector2(base_size.x * fire_length_scale, base_size.y * fire_width_scale)

		elif fire_shape.shape is CapsuleShape2D:
			var cap := fire_shape.shape as CapsuleShape2D
			var base = _fire_base_shape_data # Vector2(radius,height)
			cap.radius = base.x * fire_width_scale
			cap.height = base.y * fire_length_scale

		elif fire_shape.shape is CircleShape2D:
			var cir := fire_shape.shape as CircleShape2D
			var base_r: float = _fire_base_shape_data
			cir.radius = base_r * fire_width_scale


func _start_flame() -> void:
	_apply_fire_transform()

	if laser_sprite:
		laser_sprite.visible = true
		# Your sprite has start/cycle/stop
		if laser_sprite.sprite_frames and laser_sprite.sprite_frames.has_animation("start"):
			laser_sprite.play("start")
		else:
			laser_sprite.play()

	# delay before hitbox begins (your timing)
	await get_tree().create_timer(laser_start_time / _ts()).timeout
	_enable_hitbox(laser_hitbox)


func _stop_flame() -> void:
	_disable_hitbox(laser_hitbox)

	if laser_sprite:
		# play stop if exists, then hide
		if laser_sprite.sprite_frames and laser_sprite.sprite_frames.has_animation("stop"):
			laser_sprite.play("stop")
			await get_tree().create_timer(laser_stop_time / _ts()).timeout
		laser_sprite.visible = false
		laser_sprite.stop()

func _update_fire_to_player() -> void:


	if player == null or not is_instance_valid(player):
		return
	if mouth_marker == null or not is_instance_valid(mouth_marker):
		return
	if laser_pivot == null or not is_instance_valid(laser_pivot):
		return

	var origin: Vector2 = mouth_marker.global_position
	var to_p: Vector2 = player.global_position - origin
	var dist: float = max(to_p.length() + fire_extra_length_px, 1.0)
	#_set_facing_from_dx(to_p.x)
	# Put pivot exactly on the mouth (every frame, because mouth anim moves)
	laser_pivot.global_position = origin

	# ---- CLAMP AIM TO ±30° AROUND FACING DIRECTION ----
	var max_deg := 30.0
	var max_rad := deg_to_rad(max_deg)

	# Facing base direction in WORLD angle:
	# right = 0 rad, left = PI rad
	var base := 0.0 if _facing == 1 else PI

	# Player angle in world
	var ang := to_p.angle()

	# Angle relative to base, wrapped to [-PI..PI]
	var rel := wrapf(ang - base, -PI, PI)

	# Clamp relative angle
	rel = clamp(rel, -max_rad, max_rad)

	# Final aimed angle
	laser_pivot.global_rotation = base + rel
	# ---------------------------------------------------

	# Keep fire_hitbox at pivot local origin
	if laser_hitbox:
		laser_hitbox.position = Vector2.ZERO
		laser_hitbox.rotation = 0.0
		laser_hitbox.scale = Vector2.ONE

	# Stretch collision shape to the target distance
	if fire_shape and fire_shape.shape is RectangleShape2D:
		var rect := fire_shape.shape as RectangleShape2D
		rect.size = Vector2(dist, rect.size.y)         # length = dist
		fire_shape.position = Vector2(dist * 0.5, 0.0) # move shape forward

	# Stretch flame sprite visually to match (also forward)
	if laser_sprite:
		laser_sprite.visible = true
		laser_sprite.position = Vector2(dist * 0.5, 0.0)
		laser_sprite.offset = Vector2.ZERO
		laser_sprite.centered = true

		# Determine base sprite width from current frame (if available)
		var base_width := 64.0
		if laser_sprite.sprite_frames:
			var tex := laser_sprite.sprite_frames.get_frame_texture(laser_sprite.animation, laser_sprite.frame)
			if tex:
				base_width = float(tex.get_width())

		if base_width > 0.0:
			laser_sprite.scale = Vector2(dist / base_width, 1.0)
	
	print("FIRE UPDATE origin=", origin, " rot=", laser_pivot.global_rotation, " dist=", dist, " flame_visible=", laser_sprite.visible if laser_sprite else "no sprite")


func _start_flame_sprite() -> void:
	if not laser_sprite:
		return
	laser_sprite.visible = true
	# Use your actual animations: start -> cycle
	if laser_sprite.sprite_frames and laser_sprite.sprite_frames.has_animation("start"):
		laser_sprite.play("start")
	else:
		laser_sprite.play()


func _ensure_flame_cycle() -> void:
	if not laser_sprite:
		return
	if laser_sprite.sprite_frames and laser_sprite.sprite_frames.has_animation("cycle"):
		if laser_sprite.animation != "cycle":
			laser_sprite.play("cycle")


func _stop_flame_sprite() -> void:
	if not laser_sprite:
		return
	# stop animation if exists
	if laser_sprite.sprite_frames and laser_sprite.sprite_frames.has_animation("stop"):
		laser_sprite.play("stop")
	else:
		laser_sprite.stop()
	laser_sprite.visible = false

func _breath_target_x(player_x: float, desired_mouth_distance: float) -> float:
	if mouth_marker == null or not is_instance_valid(mouth_marker):
		return global_position.x

	var mouth_x := mouth_marker.global_position.x

	# push mouth away from player
	var dir_away = -sign(player_x - mouth_x)
	if dir_away == 0:
		dir_away = -_facing

	var desired_mouth_x := player_x + float(dir_away) * desired_mouth_distance

	# convert desired mouth X into required body X (same trick as slam)
	return global_position.x + (desired_mouth_x - mouth_x)

func _slam_align_and_execute() -> void:
	if dead or _attack_running:
		return
	#_attack_running = true

	# pick hand
	var use_left := _choose_closer_hand()
	var px := player.global_position.x # snapshot
	
	var target_x := _slam_target_x(use_left)
	
	# move so the slam contact marker aligns to player snapshot X
	_move_to_target_x(
		target_x,
		MOVE_GOAL_SLAM_ALIGN,
		px,
		use_left
	)

	while _move_active and not dead:
		await get_tree().process_frame
		
	if dead:
		#_attack_running = false
		return

	await _slam_attack()

	#_attack_running = false

func _breath_backstep_and_fire() -> void:
	if dead or _attack_running:
		return
	_attack_running = true

	# Face player first (so "away" direction is stable)
	if player:
		_set_facing_from_dx(player.global_position.x - global_position.x)

	# snapshot
	var px := player.global_position.x

	# check distance from mouth (not body center)
	var mouth_x := mouth_marker.global_position.x if mouth_marker else global_position.x
	var dist = abs(px - mouth_x)

	# ✅ Backstep until we have enough room
	if dist < breath_preferred_distance:
		var target_x := _breath_target_x(px, breath_preferred_distance)
		await _move_to_target_x(target_x, MOVE_GOAL_CENTER)

		# re-check after moving (important!)
		mouth_x = mouth_marker.global_position.x if mouth_marker else global_position.x
		dist = abs(px - mouth_x)

		# still too close? do one more small backstep, or abort to slam
		if dist < breath_preferred_distance * 0.85:
			var target_x2 := _breath_target_x(px, breath_preferred_distance + breath_backstep_px)
			await _move_to_target_x(target_x2, MOVE_GOAL_CENTER)

			mouth_x = mouth_marker.global_position.x if mouth_marker else global_position.x
			dist = abs(px - mouth_x)

			if dist < breath_preferred_distance * 0.80:
				# abort breath if we truly can't create space (walls etc.)
				_attack_running = false
				return


	
	if player and is_instance_valid(player):
		_set_facing_from_dx(player.global_position.x - global_position.x)
	
	await _breath_fire_sequence_only()

	_attack_running = false

func _breath_fire_sequence_only() -> void:
	# 1) lower
	if anim and anim.has_animation("breath_lower"):
		anim.play("breath_lower")
	await get_tree().create_timer(laser_lower_time / _ts()).timeout
	if dead:
		return

	# 2) fire pose
	if anim and anim.has_animation("breath_fire"):
		anim.play("breath_fire")

	_start_flame_sprite()
	await get_tree().create_timer(laser_start_time / _ts()).timeout
	_enable_hitbox(laser_hitbox)

	var t := 0.0
	while t < laser_cycle_time and not dead and not Global.camouflage:
		_update_fire_to_player()
		_ensure_flame_cycle()
		await get_tree().process_frame
		t += get_process_delta_time() * _ts()

	await get_tree().create_timer(laser_stop_time / _ts()).timeout
	_disable_hitbox(laser_hitbox)
	_stop_flame_sprite()

	_enable_weakspot(head_weakspot)
	await get_tree().create_timer(breath_vulnerable_time / _ts()).timeout
	_disable_weakspot(head_weakspot)

	if anim and anim.has_animation("breath_recover"):
		anim.play("breath_recover")
	await get_tree().create_timer(laser_recover_time / _ts()).timeout


	if anim and anim.has_animation("idle"):
		anim.play("idle")

# ----------------------------
# LASER AIM (HEAD)
# ----------------------------
func _update_head_laser_aim() -> void:
	if not player or not is_instance_valid(player): return
	if not mouth_marker or not is_instance_valid(mouth_marker): return
	if not laser_pivot or not is_instance_valid(laser_pivot): return

	var origin := mouth_marker.global_position
	var to_p := player.global_position - origin
	var dist = max(to_p.length(), 1.0)

	laser_pivot.global_position = origin
	laser_pivot.global_rotation = to_p.angle()

	# stretch collision shape forward (RectangleShape2D recommended)
	if laser_sprite and laser_sprite.shape is RectangleShape2D:
		var rect := laser_sprite.shape as RectangleShape2D
		rect.size = Vector2(dist, rect.size.y)
		laser_sprite.position = Vector2(dist * 0.5, 0.0)

# ----------------------------
# SUMMONED LASER COLUMN
# ----------------------------
func _spawn_laser_column_at(world_pos: Vector2) -> void:
	if laser_column_scene == null:
		return
	var l := laser_column_scene.instantiate()
	get_tree().current_scene.add_child(l)
	l.global_position = world_pos

	# pass damage if the column supports it
	if "damage" in l:
		l.damage = surround_laser_damage

# ----------------------------
# DAMAGE / DIE
# ----------------------------
func take_damage(amount: int) -> void:
	if dead or invulnerable:
		print("❌ Cannot take damage: dead=", dead, " invuln=", invulnerable)
		return

	print("💥 Gigaster taking ", amount, " damage! Health: ", health, " -> ", health - amount)
	health -= amount
	_flash_hurt()
	
	if health <= 0:
		_die()


func _spawn_laser_at(pos: Vector2) -> LaserColumn:
	if laser_column_scene == null:
		push_error("GigasterBoss: laser_column_scene is NOT assigned!")
		return null

	var laser := laser_column_scene.instantiate() as LaserColumn
	get_tree().current_scene.add_child(laser)

	laser.global_position = pos
	#laser.global_position.y = get_viewport_rect().position.y
	laser.visible = true
	laser.active = false
	# Stretch to screen height
	#var screen_h := get_viewport_rect().size.y
	#if laser.has_node("CollisionShape2D"):
	#	var cs := laser.get_node("CollisionShape2D") as CollisionShape2D
	#	if cs.shape is RectangleShape2D:
	#		cs.shape.size.y = screen_h
	#		cs.position.y = screen_h * 0.5

	if laser.has_node("Sprite2D"):
		var sp := laser.get_node("Sprite2D") as Sprite2D
		sp.visible = false  # Start hidden, will show when activated
		sp.modulate = Color(1, 0.5, 0.5, 0.8)  # Reddish tint
	
	if "damage" in laser:
		laser.damage = surround_laser_damage
		
	#laser.deactivate()
	return laser
	
func _update_laser_between_markers(
	laser_area: Area2D,
	from_marker: Marker2D,
	to_marker: Marker2D
) -> void:
	if not laser_area or not from_marker or not to_marker:
		return

	var shape = laser_area.get_node("CollisionShape2D").shape
	if not shape or not shape is RectangleShape2D:
		return

	var from := from_marker.global_position
	var to := to_marker.global_position

	var dir := to - from
	var length := dir.length()
	if length < 1.0:
		return

	# Position laser in the middle
	laser_area.global_position = from + dir * 0.5
	laser_area.rotation = dir.angle()

	# Stretch rectangle
	shape.extents.x = length * 0.5
	shape.extents.y = 20   # LASER WIDTH (adjust here)

	# Optional debug visual
	if laser_area.has_node("DebugRect"):
		var rect := laser_area.get_node("DebugRect")
		rect.size = Vector2(length, shape.extents.y * 2)
		rect.position = Vector2(-length * 0.5, -shape.extents.y)

# Add this function to your Player.gd

func _check_hitbox_settings() -> void:
	print("🔍 Checking hitbox settings...")
	
	for hb in [left_hitbox, right_hitbox, laser_hitbox]:
		if hb:
			print("  ", hb.name, ":")
			print("    Monitoring: ", hb.monitoring)
			print("    Monitorable: ", hb.monitorable)
			print("    Collision Layer: ", hb.collision_layer)
			print("    Collision Mask: ", hb.collision_mask)
			
			# Check if collision shape exists
			var shape = hb.get_node_or_null("CollisionShape2D") as CollisionShape2D
			if shape:
				print("    Shape disabled: ", shape.disabled)
				print("    Shape type: ", shape.shape)

