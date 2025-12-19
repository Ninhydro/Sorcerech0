extends CharacterBody2D
class_name GigasterBoss

signal boss_died

# ----------------------------
# CONFIG
# ----------------------------
#var movement_locked := false

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
@export var phase1_laser_chance := 0.3  # phase1: 25% head laser, 75% slam
@export var phase2_surround_chance := 0.3 # phase2: 25% surround lasers, 75% slam

# phase transition
@export var phase2_trigger_ratio := 0.5  # at 50% hp
var _phase := 1
var _did_phase2_transition := false

# summon intermission
@export var summon_enemy_scene: PackedScene
@export var summon_marker_path: NodePath
@export var intermission_anim := "die"     # “die” used as stunned/intermission pose
@export var resume_anim := "die_recover"

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
@export var laser_on_time := 0.5
@export var laser_off_gap := 0.01

@export var slam_high_y_threshold := -40.0

var _post_attack_freeze := 0.0

#var _smooth_transition := false
var _transition_target_x := 0.0
var _transition_speed := 80.0

var damage_window_open := false

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

	_left_slam_marker_node = get_node_or_null(left_slam_marker) as Marker2D
	_right_slam_marker_node = get_node_or_null(right_slam_marker) as Marker2D

	_disable_all_hitboxes()
	_disable_all_weakspots()
	#_stop_flame_immediately()

	# connect weakspots (area_entered only)
	_connect_weakspot(head_weakspot)
	_connect_weakspot(left_weakspot)
	_connect_weakspot(right_weakspot)

	# connect attack hitboxes -> damage player
	if left_hitbox:
		left_hitbox.body_entered.connect(_on_attack_hitbox_body_entered.bind(left_hitbox))
	if right_hitbox:
		right_hitbox.body_entered.connect(_on_attack_hitbox_body_entered.bind(right_hitbox))
	#if fire_hitbox:
	#	fire_hitbox.body_entered.connect(_on_attack_hitbox_body_entered.bind(fire_hitbox))

	#_force_fire_nodes_clean()
	
	#if flame_sprite:
	#	flame_sprite.z_index = 100
	#	flame_sprite.z_as_relative = true
		
	#if fire_pivot:
	#	_fire_base_scale = fire_pivot.scale
	#	_fire_base_rot = fire_pivot.rotation

# Cache base collision shape size so we can stretch it
	if fire_shape and fire_shape.shape:
		if fire_shape.shape is RectangleShape2D:
			_fire_base_shape_data = (fire_shape.shape as RectangleShape2D).size
		elif fire_shape.shape is CapsuleShape2D:
			_fire_base_shape_data = Vector2((fire_shape.shape as CapsuleShape2D).radius, (fire_shape.shape as CapsuleShape2D).height)
		elif fire_shape.shape is CircleShape2D:
			_fire_base_shape_data = (fire_shape.shape as CircleShape2D).radius
		
	_setup_flash_targets() # wraps boss visuals, but SKIPS flame sprite
	set_physics_process(true)
	set_process(true)

	print("GawrBoss READY: ", name, " flash_targets=", _flash_targets.size())

func _physics_process(delta: float) -> void:
	player = _get_player()
	
	if Input.is_action_just_pressed("debug1"): 
		_debug_movement_state()
	# allow AI reposition movement even if we're "in an attack phase"
	if dead or taking_damage or Global.camouflage or (_attack_running and not _move_active) or player == null or not chase_enabled:
		velocity.x = 0
		move_and_slide()
		return
	
	

	# move_active (AI-driven)
	if _move_active:
		var dx_to_target := _target_x - global_position.x
		#_set_facing_from_dx(dx_to_target)

		# --- STOP CONDITION DEPENDS ON MOVE GOAL ---
		var reached := false

		#if _move_goal_type == MOVE_GOAL_CENTER:
		#	reached = abs(dx_to_target) <= align_tolerance

		if _move_goal_type == MOVE_GOAL_SLAM_ALIGN:
			# stop when the slam marker (hand contact point) is aligned to the player snapshot X
			reached = abs(dx_to_target) <= align_tolerance
			#var slam_x := _get_slam_point_world_x(_move_goal_use_left)
			#reached = abs(_move_goal_player_x - slam_x) <= slam_align_tolerance

		#elif _move_goal_type == MOVE_GOAL_BREATH_SPACE:
			# stop once we created enough distance OR reached target
		#	var px := _move_goal_player_x
		#	var dist = abs(px - global_position.x)
		#	reached = (dist >= breath_preferred_distance) or (abs(dx_to_target) <= align_tolerance)

		if reached:
			velocity.x = 0
			_move_active = false
			anim.play("idle")
		else:
			var dir = sign(dx_to_target)
			if dir == 0:
				dir = 1 if dx_to_target > 0.0 else -1
			#print("moving ai")
			velocity.x = dir * walk_speed * _ts()
			if anim and anim.has_animation("walk"):
				anim.play("walk")

		move_and_slide()
		return

	# normal chase
	var dx := player.global_position.x - global_position.x
	#_set_facing_from_dx(dx)

	var adx = abs(dx)
	if adx > chase_stop_distance + chase_deadzone:
		#print("normal chase moving")
		velocity.x = sign(dx) * walk_speed * _ts()
		if anim and anim.has_animation("walk"):
			anim.play("walk")
	else:
		velocity.x = 0
		anim.play("idle")

	move_and_slide()

# ----------------------------
# BATTLE START
# ----------------------------
func reset_for_battle() -> void:
	dead = false
	taking_damage = false
	_attack_running = false
	health = max_health

	_disable_all_hitboxes()
	_disable_all_weakspots()
	#_stop_flame_immediately()

	anim.play("idle")

	if not _ai_running:
		_ai_running = true
		call_deferred("_start_ai")

func _start_ai() -> void:
	print("GawrBoss AI LOOP STARTED.")
	while not dead:
		
		player = _get_player()
		#_debug_movement_state()
		
		if player == null:
			await get_tree().create_timer(0.2 / _ts()).timeout
			continue

		# Pause/interrupt conditions
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
		

		if taking_damage:
			await get_tree().process_frame
			continue

		var now := Time.get_ticks_msec() / 1000.0
		if now < _next_attack_time:
			await get_tree().process_frame
			continue

		# ✅ Let physics chase logic run naturally (idle/chase) UNTIL we're in attack range.
		# We DON'T manually move to player here anymore.
		var mouth_x := mouth_marker.global_position.x if mouth_marker else global_position.x
		var dist_to_player = abs(player.global_position.x - mouth_x)

		# If player is far, just keep looping so _physics_process handles chase/walk/idle
		if dist_to_player > chase_stop_distance:
			await get_tree().process_frame
			continue

		# Small readability pause (optional)
		await get_tree().create_timer(0.12 / _ts()).timeout
		if dead: break

		# Choose attack
		# === ATTACK SELECTION BASED ON PHASE ===
		if _phase == 1:
			print("🎮 Phase 1: Choosing attack...")
			if randf() < phase1_laser_chance:
				print("🎮 Phase 1: Surround laser attack")
				
				_enable_weakspot(head_weakspot)
				await _surround_lasers_attack()
				# Head weakspot vulnerable after attack
				
				await get_tree().create_timer(breath_vulnerable_time / _ts()).timeout
				_disable_weakspot(head_weakspot)
				anim.play("summon_laser_recover")
			else:
				print("🎮 Phase 1: Slam attack")
				# CHANGED: Use aligned slam instead of regular slam
				await _slam_align_and_execute()
		else:  # Phase 2
			print("🎮 Phase 2: Choosing attack...")
			if randf() < phase2_surround_chance:
				print("🎮 Phase 2: Surround laser attack")
				_enable_weakspot(head_weakspot)
				await _surround_lasers_attack()
				# Head weakspot vulnerable after attack

				await get_tree().create_timer(breath_vulnerable_time / _ts()).timeout
				_disable_weakspot(head_weakspot)
				anim.play("summon_laser_recover")
			else:
				print("🎮 Phase 2: Slam attack")
				# CHANGED: Use aligned slam instead of regular slam
				await _slam_align_and_execute()

		_next_attack_time = (Time.get_ticks_msec() / 1000.0) + attack_cooldown

	_ai_running = false
	print("GawrBoss AI LOOP ENDED.")

func _move_to_target_x(x: float, goal_type := MOVE_GOAL_CENTER, player_x_snapshot := 0.0, use_left := true) -> void:

	_target_x = x
	_move_active = true

	_move_goal_type = goal_type
	_move_goal_player_x = player_x_snapshot
	_move_goal_use_left = use_left

	# CALCULATE TARGET HAND POSITION ONCE
	var target_hand_x_for_alignment := 0.0
	if goal_type == MOVE_GOAL_SLAM_ALIGN:
		# Calculate where the hand SHOULD be when aligned
		target_hand_x_for_alignment = player_x_snapshot
	
	var start_time := Time.get_ticks_msec()
	var max_ms := int(slam_max_move_ms) if goal_type == MOVE_GOAL_SLAM_ALIGN else 1500

	while _move_active and not dead and not taking_damage and not Global.camouflage:
		if Time.get_ticks_msec() - start_time > max_ms:
			print("GawrBoss: move_to_target TIMEOUT. goal=", goal_type, " target=", _target_x, " pos=", global_position.x)
			_move_active = false
			break
		await get_tree().process_frame
	
	

# ----------------------------
# SLAM (uses ONLY your listed animations)
# ----------------------------
func _slam_phase_with_hand(use_left: bool) -> void:
	if dead:
		return
		
	#print("DEBUG: Starting slam at position: ", global_position)
	_attack_running = true
	#movement_locked = true  # Add this line
	
	#velocity = Vector2.ZERO
	var is_high := _is_high_slam()
	
	var hitbox: Area2D = left_hitbox if use_left else right_hitbox
	var weakspot: Area2D = left_weakspot if use_left else right_weakspot

	# 1) slam windup (one-shot)
	var anim_prefix := "slam_left" if use_left else "slam_right"
	if is_high:
		#anim_prefix = "slam_right" if use_left else "slam_left"
		anim_prefix += "_high"
		
	# 1) windup
	if anim and anim.has_animation(anim_prefix):
		anim.play(anim_prefix)
	_enable_hitbox(hitbox)
	await get_tree().create_timer(slam_windup_time / _ts()).timeout
	if dead:
		#movement_locked = false
		_attack_running = false
		return

	# 2) damage window
	#_enable_hitbox(hitbox)
	await get_tree().create_timer(slam_hit_active_time / _ts()).timeout
	_disable_hitbox(hitbox)

	# 3) vulnerable idle
	_enable_weakspot(weakspot)
	var idle_anim := anim_prefix + "_idle"
	if anim and anim.has_animation(idle_anim):
		anim.play(idle_anim)

	await get_tree().create_timer(slam_stun_time / _ts()).timeout
	_disable_weakspot(weakspot)

	# 4) return
	var return_anim := anim_prefix + "_return"
	if anim and anim.has_animation(return_anim):
		anim.play(return_anim)

	await get_tree().create_timer(slam_return_time / _ts()).timeout

	# 5) recovery
	anim.play("idle")
	#movement_locked = false  # Add this line
	_attack_running = false
	#_smooth_transition = true
	_transition_target_x = global_position.x
# Accurate slam targeting:
# move boss so "slam contact point" ends up at player_x (+ optional lead)
func _slam_target_x(use_left: bool) -> float:
	if player == null or not is_instance_valid(player):
		return global_position.x

	# DEBUG: Check what's happening
	print("SLAM TARGET DEBUG: boss=", global_position.x, 
		  " player=", player.global_position.x,
		  " facing=", _facing,
		  " hand=", "left" if use_left else "right",
		  " hand_x=", _get_slam_point_world_x(use_left))
	
	# Calculate where we want the hand to land
	var target_hand_x = player.global_position.x + slam_lead_px * float(_facing)
	var current_hand_x = _get_slam_point_world_x(use_left)
	
	# How much we need to move the boss
	var offset_needed = target_hand_x - current_hand_x
	var result = global_position.x + offset_needed
	
	print("  -> target_hand_x=", target_hand_x, 
		  " current_hand_x=", current_hand_x,
		  " offset=", offset_needed,
		  " result=", result)
	
	return result

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
	
	var left_x = _get_slam_point_world_x(true)
	var right_x = _get_slam_point_world_x(false)
	var player_x = player.global_position.x
	
	var dl = abs(player_x - left_x)
	var dr = abs(player_x - right_x)
	
	print("CHOOSE HAND: player=", player_x,
		  " left=", left_x, " (dist=", dl, ")",
		  " right=", right_x, " (dist=", dr, ")",
		  " use_left=", dl <= dr)
	
	return dl <= dr

# ----------------------------
# BREATH (uses ONLY your listed animations)
# ----------------------------




# ----------------------------
# DAMAGE / FLASH
# ----------------------------
func take_damage(amount: int) -> void:
	if dead:
		return
	print("DAMAGINGGGGGGG")
	# 🔒 Damage gate
	if not damage_window_open:
		return   # hit registered, but no damage, no flash

	health -= amount
	taking_damage = true

	_flash_hurt()

	await get_tree().create_timer(hurt_lock_time / _ts()).timeout
	taking_damage = false

	if health <= 0:
		_die()

func _die() -> void:
	dead = true
	_disable_all_hitboxes()
	_disable_all_weakspots()
	#_stop_flame_immediately()
	if anim and anim.has_animation("die"):
		anim.play("die")
	emit_signal("boss_died")

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
	if dead or body == null:
		return
	if not body.is_in_group("player"):
		return

	var dmg: int = surround_laser_damage if source_hitbox == laser_hitbox else slam_damage
	if body.has_method("take_damage"):
		body.call("take_damage", dmg)

# ----------------------------
# HITBOX HELPERS
# ----------------------------
func _enable_hitbox(box: Area2D) -> void:
	if box == null: return
	var shape := box.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape: shape.disabled = false

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
	damage_window_open = true   # ✅ OPEN DAMAGE
	var shape := ws.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape: shape.disabled = false
	print("ENABLE WEAKSPOT:", ws.name, " disabled=", shape.disabled)


func _disable_weakspot(ws: Area2D) -> void:
	if ws == null: return
	damage_window_open = false  # 🔒 CLOSE DAMAGE
	var shape := ws.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape: shape.disabled = true

func _disable_all_weakspots() -> void:
	damage_window_open = false
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
	#if flame_sprite and node == flame_sprite:
	#	return

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
	
	#if nora_minigame_active and _force_facing_left:
	#	return
		
	var new_facing := -1 if dx < 0.0 else 1
	if new_facing == _facing:
		return
	_facing = new_facing
	body_pivot.scale.x = abs(body_pivot.scale.x) * float(_facing)

func _slam_align_and_execute() -> void:
	if dead or _attack_running:
		return
	_attack_running = true

	# pick hand
	var use_left := _choose_closer_hand()
	var px := player.global_position.x # snapshot

	# move so the slam contact marker aligns to player snapshot X
	await _move_to_target_x(
		_slam_target_x(use_left),
		MOVE_GOAL_SLAM_ALIGN,
		px,
		use_left
	)

	if dead:
		_attack_running = false
		return

	await _slam_phase_with_hand(use_left)
	#while _smooth_transition:
		#await get_tree().process_frame
	_attack_running = false

func _surround_lasers_attack() -> void:
	if dead or _attack_running:
		return

	_attack_running = true
	_move_active = false
	velocity = Vector2.ZERO

	# -------------------------------------------------
	# 1) WINDUP / TELEGRAPH (one-shot)
	# -------------------------------------------------
	if anim and anim.has_animation("summon_laser"):
		anim.play("summon_laser")

	await get_tree().create_timer(surround_telegraph_time / _ts()).timeout
	if dead:
		_attack_running = false
		return

	# -------------------------------------------------
	# 2) LASER LOOP PHASE (idle loop while firing)
	# -------------------------------------------------
	if anim and anim.has_animation("summon_laser_idle"):
		anim.play("summon_laser_idle")

	var markers := _get_surround_laser_markers()
	if markers.is_empty():
		print("⚠️ No surround laser markers")
		_attack_running = false
		return

	for m in markers:
		if dead:
			break

		var laser = _spawn_laser_at(m.global_position)
		if laser:
			laser.activate()
			await get_tree().create_timer(laser_on_time / _ts()).timeout
			laser.deactivate()

		await get_tree().create_timer(laser_off_gap / _ts()).timeout

	# -------------------------------------------------
	# 3) TIRED / STUNNED PHASE
	# -------------------------------------------------
	if anim and anim.has_animation("summon_laser_tired"):
		anim.play("summon_laser_tired")
	

	# Boss is vulnerable / stunned here
	_enable_weakspot(head_weakspot)
	await get_tree().create_timer(3.0 / _ts()).timeout
	_disable_weakspot(head_weakspot)

	if dead:
		_attack_running = false
		return

	# -------------------------------------------------
	# 4) RECOVER (one-shot)
	# -------------------------------------------------
	if anim and anim.has_animation("summon_laser_recover"):
		anim.play("summon_laser_recover")

	# Wait for recover animation to finish if it exists
	if anim and anim.has_animation("summon_laser_recover"):
		await anim.animation_finished

	# -------------------------------------------------
	# 5) BACK TO IDLE
	# -------------------------------------------------
	if anim and anim.has_animation("idle"):
		anim.play("idle")

	_attack_running = false

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
		
func _debug_movement_state():
	print("DEBUG Movement State:")
	print("  _move_active:", _move_active)
	print("  _attack_running:", _attack_running)
	print("  velocity.x:", velocity.x)
	print("  chase_enabled:", chase_enabled)
	print("  _target_x:", _target_x)
	print("  position.x:", global_position.x)
	print("  left hand marker position.x:", _left_slam_marker_node.global_position.x)
	print("  right hand marker position.x:", _right_slam_marker_node.global_position.x)
	print("  player position.x:", player.global_position.x)

		
