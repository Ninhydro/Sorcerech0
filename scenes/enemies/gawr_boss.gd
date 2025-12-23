extends CharacterBody2D
class_name GawrBoss

signal boss_died

# ----------------------------
# CONFIG
# ----------------------------
@export var max_health: int = 300
@export var walk_speed: float = 60.0 * Global.global_time_scale  

@export var slam_damage: int = 10
@export var fire_damage: int = 15

@export var slam_windup_time: float = 0.35
@export var slam_stun_time: float = 3.0
@export var slam_return_time: float = 0.6
@export var slam_hit_active_time: float = 0.12

@export var breath_lower_time: float = 0.4
@export var breath_cycle_time: float = 1.0
@export var breath_recover_time: float = 0.8
@export var flame_start_time: float = 0.20
@export var flame_stop_time: float = 0.20
@export var breath_vulnerable_time: float = 2.0 # after stop, boss stays in breath_fire pose

@export var hurt_lock_time: float = 0.15
@export var attack_cooldown: float = 0.6

@export var chase_stop_distance: float = 220.0
@export var chase_deadzone: float = 20.0
@export var chase_enabled: bool = true

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

var player: Node2D

var _move_active := false
var _target_x := 0.0
var _facing := 1

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

@onready var fire_hitbox: Area2D = $BodyPivot/HeadPivot/MouthMarker/FirePivot/FireHitbox
@onready var fire_pivot: Node2D = $BodyPivot/HeadPivot/MouthMarker/FirePivot
@onready var mouth_marker: Marker2D = $BodyPivot/HeadPivot/MouthMarker
@onready var fire_shape: CollisionShape2D = $BodyPivot/HeadPivot/MouthMarker/FirePivot/FireHitbox/CollisionShape2D
@onready var flame_sprite: AnimatedSprite2D = $BodyPivot/HeadPivot/MouthMarker/FirePivot/FlameSprite

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
var nora_minigame_active := false
var _minigame_charge_time := 10.0
var _minigame_final_marker: Node2D = null
var _minigame_doing_slam := false

@export var minigame_slam_cooldown := 2.5
var _next_minigame_slam_time := 0.0

var _force_facing_left := false

@export var minigame_slam_x_range := 150.0
@export var minigame_slam_y_range := 200.0   # prevents slam when player is far above/below
@export var minigame_requires_front := false

# ----------------------------
# HELPERS
# ----------------------------
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
	_stop_flame_immediately()

	# connect weakspots (area_entered only)
	_connect_weakspot(head_weakspot)
	_connect_weakspot(left_weakspot)
	_connect_weakspot(right_weakspot)

	# connect attack hitboxes -> damage player
	if left_hitbox:
		left_hitbox.body_entered.connect(_on_attack_hitbox_body_entered.bind(left_hitbox))
	if right_hitbox:
		right_hitbox.body_entered.connect(_on_attack_hitbox_body_entered.bind(right_hitbox))
	if fire_hitbox:
		fire_hitbox.body_entered.connect(_on_attack_hitbox_body_entered.bind(fire_hitbox))

	_force_fire_nodes_clean()
	
	if flame_sprite:
		flame_sprite.z_index = 100
		flame_sprite.z_as_relative = true
		
	if fire_pivot:
		_fire_base_scale = fire_pivot.scale
		_fire_base_rot = fire_pivot.rotation

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
	
	if anim:
		anim.speed_scale = Global.global_time_scale
		
	if nora_minigame_active:
		_facing = -1
		body_pivot.scale.x = -abs(body_pivot.scale.x)
		velocity = Vector2.ZERO
		move_and_slide()

			# keep facing left (we’ll force it below)
		_force_face_left_minigame()
		
		player = _get_player()
		if player:
			var dx := player.global_position.x - global_position.x
			var dy := player.global_position.y - global_position.y

			var close_x = abs(dx) <= minigame_slam_x_range
			var close_y = abs(dy) <= minigame_slam_y_range

			var in_front := true
			if minigame_requires_front:
				# boss facing left => "front" is player on left side
				in_front = (dx < 0.0)

			var now := Time.get_ticks_msec() / 1000.0
			if close_x and close_y and in_front and not _minigame_doing_slam and now >= _next_minigame_slam_time and not Global.camouflage:
				_next_minigame_slam_time = now + minigame_slam_cooldown
				call_deferred("_do_minigame_slam_interrupt")

		return
	

	if dead:
		velocity.x = 0
		move_and_slide()
		return

	# allow AI reposition movement even if we're "in an attack phase"
	if taking_damage or Global.camouflage or (_attack_running and not _move_active):
		velocity.x = 0
		move_and_slide()
		return

	if player == null or not chase_enabled:
		velocity.x = 0
		move_and_slide()
		return

	# move_active (AI-driven)
	if _move_active:
		var dx_to_target := _target_x - global_position.x
		_set_facing_from_dx(dx_to_target)

		# --- STOP CONDITION DEPENDS ON MOVE GOAL ---
		var reached := false

		if _move_goal_type == MOVE_GOAL_CENTER:
			reached = abs(dx_to_target) <= align_tolerance

		elif _move_goal_type == MOVE_GOAL_SLAM_ALIGN:
			# stop when the slam marker (hand contact point) is aligned to the player snapshot X
			var slam_x := _get_slam_point_world_x(_move_goal_use_left)
			reached = abs(_move_goal_player_x - slam_x) <= slam_align_tolerance

		#elif _move_goal_type == MOVE_GOAL_BREATH_SPACE:
			# stop once we created enough distance OR reached target
		#	var px := _move_goal_player_x
		#	var dist = abs(px - global_position.x)
		#	reached = (dist >= breath_preferred_distance) or (abs(dx_to_target) <= align_tolerance)

		if reached:
			velocity.x = 0
			_move_active = false
			if nora_minigame_active:
				_ensure_minigame_idle()
			elif anim and anim.has_animation("idle"):
				anim.play("idle")
		else:
			var dir = sign(dx_to_target)
			if dir == 0:
				dir = 1 if dx_to_target > 0.0 else -1
			velocity.x = dir * walk_speed * _ts()
			if anim and anim.has_animation("walk"):
				anim.play("walk")

		move_and_slide()
		return

	# normal chase
	var dx := player.global_position.x - global_position.x
	_set_facing_from_dx(dx)

	var adx = abs(dx)
	if adx > chase_stop_distance + chase_deadzone:
		velocity.x = sign(dx) * walk_speed * _ts()
		if anim and anim.has_animation("walk"):
			anim.play("walk")
	else:
		velocity.x = 0
		if nora_minigame_active:
			_ensure_minigame_idle()
		elif anim and anim.has_animation("idle"):
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
	_stop_flame_immediately()

	if nora_minigame_active:
		_ensure_minigame_idle()
	elif anim and anim.has_animation("idle"):
		anim.play("idle")

	if not _ai_running:
		_ai_running = true
		call_deferred("_start_ai")

func _start_ai() -> void:
	print("GawrBoss AI LOOP STARTED.")
	while not dead:
		player = _get_player()
		if player == null:
			await get_tree().create_timer(0.2 / _ts()).timeout
			continue

		# Pause/interrupt conditions
		if Global.camouflage:
			_disable_hitbox(fire_hitbox)
			_stop_flame_immediately()
			await get_tree().create_timer(0.2 / _ts()).timeout
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
		var do_breath := randf() < breath_chance

		# anti-streak
		if _breath_streak >= max_breath_streak:
			do_breath = false

		if do_breath:
			_breath_streak += 1
			await _breath_backstep_and_fire()
		else:
			_breath_streak = 0
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
	_attack_running = true

	var hitbox: Area2D = left_hitbox if use_left else right_hitbox
	var weakspot: Area2D = left_weakspot if use_left else right_weakspot

	# 1) slam windup (one-shot)
	if anim:
		if use_left and anim.has_animation("slam_left"):
			anim.play("slam_left")
		elif (not use_left) and anim.has_animation("slam_right"):
			anim.play("slam_right")

	await get_tree().create_timer(slam_windup_time / _ts()).timeout
	if dead:
		_attack_running = false
		return

	# 2) damage window (short)
	_enable_hitbox(hitbox)
	await get_tree().create_timer(slam_hit_active_time / _ts()).timeout
	_disable_hitbox(hitbox)

	# 3) vulnerable idle for this hand (cycle)
	_enable_weakspot(weakspot)
	if anim:
		if use_left and anim.has_animation("slam_left_idle"):
			anim.play("slam_left_idle")
		elif (not use_left) and anim.has_animation("slam_right_idle"):
			anim.play("slam_right_idle")

	await get_tree().create_timer(slam_stun_time / _ts()).timeout
	_disable_weakspot(weakspot)

	# 4) return (one-shot)
	if anim:
		if use_left and anim.has_animation("slam_left_return"):
			anim.play("slam_left_return")
		elif (not use_left) and anim.has_animation("slam_right_return"):
			anim.play("slam_right_return")

	await get_tree().create_timer(slam_return_time / _ts()).timeout

	# 5) back to idle
	if nora_minigame_active:
		_ensure_minigame_idle()
	elif anim and anim.has_animation("idle"):
		anim.play("idle")

	_attack_running = false

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

# ----------------------------
# BREATH (uses ONLY your listed animations)
# ----------------------------
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
	await get_tree().create_timer(breath_lower_time / _ts()).timeout
	if dead:
		_attack_running = false
		return

	# 2) fire pose (cycle anim on boss)
	if anim and anim.has_animation("breath_fire"):
		anim.play("breath_fire")

	# Start flame sprite animation
	_start_flame_sprite()

	# Delay before damage starts
	await get_tree().create_timer(flame_start_time / _ts()).timeout
	_enable_hitbox(fire_hitbox)

	# Keep firing for breath_cycle_time, update aim/stretch every frame
	var t := 0.0
	while t < breath_cycle_time and not dead and not Global.camouflage:
		_update_fire_to_player()
		_ensure_flame_cycle()
		await get_tree().process_frame
		t += get_process_delta_time() * _ts()

	# Stop damage slightly before visuals stop (optional timing)
	await get_tree().create_timer(flame_stop_time / _ts()).timeout
	_disable_hitbox(fire_hitbox)
	_stop_flame_sprite()

	# ✅ PUNISH WINDOW: keep breath_fire pose and enable head weakspot
	_enable_weakspot(head_weakspot)
	await get_tree().create_timer(breath_vulnerable_time / _ts()).timeout
	_disable_weakspot(head_weakspot)

	# recover
	if anim and anim.has_animation("breath_recover"):
		anim.play("breath_recover")
	await get_tree().create_timer(breath_recover_time / _ts()).timeout

	_attack_running = false
	



# ----------------------------
# DAMAGE / FLASH
# ----------------------------
func take_damage(amount: int) -> void:
	if dead:
		return
	if nora_minigame_active:
		return
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
	_stop_flame_immediately()
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
	if nora_minigame_active: #get_signal_connection_list("minigame_head_hit").size() >= 0:
		# only when the head weakspot was the one being hit
		# (If you want this strictly, easiest is: check if head weakspot overlaps the attack area right now)
		if head_weakspot and head_weakspot.overlaps_area(area):
			minigame_head_hit.emit()
		return  

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

	var dmg: int = fire_damage if source_hitbox == fire_hitbox else slam_damage
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
	_disable_hitbox(fire_hitbox)

func _enable_weakspot(ws: Area2D) -> void:
	
	if ws == null: return
	var shape := ws.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape: shape.disabled = false
	print("ENABLE WEAKSPOT:", ws.name, " disabled=", shape.disabled)


func _disable_weakspot(ws: Area2D) -> void:
	if ws == null: return
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
	if flame_sprite and node == flame_sprite:
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
	
	if nora_minigame_active and _force_facing_left:
		return
		
	var new_facing := -1 if dx < 0.0 else 1
	if new_facing == _facing:
		return
	_facing = new_facing
	body_pivot.scale.x = abs(body_pivot.scale.x) * float(_facing)

func _stop_flame_immediately() -> void:
	if flame_sprite:
		flame_sprite.visible = false
		flame_sprite.stop()

func _force_fire_nodes_clean() -> void:
	if fire_pivot:
		fire_pivot.position = Vector2.ZERO
		fire_pivot.rotation = 0.0
		fire_pivot.scale = Vector2.ONE
	if fire_hitbox:
		fire_hitbox.position = Vector2.ZERO
		fire_hitbox.rotation = 0.0
		fire_hitbox.scale = Vector2.ONE
	if fire_shape:
		fire_shape.position = Vector2.ZERO
		fire_shape.rotation = 0.0
	if flame_sprite:
		flame_sprite.position = Vector2.ZERO
		flame_sprite.rotation = 0.0
		flame_sprite.offset = Vector2.ZERO

func _apply_fire_transform() -> void:
	if not fire_pivot or not mouth_marker:
		return

	# Always emit from mouth marker
	fire_pivot.global_position = mouth_marker.global_position

	# Rotate ±30 degrees depending on facing
	fire_pivot.rotation = deg_to_rad(fire_angle_deg * float(_facing))

	# Stretch flame forward (local +X direction)
	fire_pivot.scale = Vector2(_fire_base_scale.x * fire_length_scale, _fire_base_scale.y * fire_width_scale)

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

	if flame_sprite:
		flame_sprite.visible = true
		# Your sprite has start/cycle/stop
		if flame_sprite.sprite_frames and flame_sprite.sprite_frames.has_animation("start"):
			flame_sprite.play("start")
		else:
			flame_sprite.play()

	# delay before hitbox begins (your timing)
	await get_tree().create_timer(flame_start_time / _ts()).timeout
	_enable_hitbox(fire_hitbox)


func _stop_flame() -> void:
	_disable_hitbox(fire_hitbox)

	if flame_sprite:
		# play stop if exists, then hide
		if flame_sprite.sprite_frames and flame_sprite.sprite_frames.has_animation("stop"):
			flame_sprite.play("stop")
			await get_tree().create_timer(flame_stop_time / _ts()).timeout
		flame_sprite.visible = false
		flame_sprite.stop()

func _update_fire_to_player() -> void:


	if player == null or not is_instance_valid(player):
		return
	if mouth_marker == null or not is_instance_valid(mouth_marker):
		return
	if fire_pivot == null or not is_instance_valid(fire_pivot):
		return

	var origin: Vector2 = mouth_marker.global_position
	var to_p: Vector2 = player.global_position - origin
	var dist: float = max(to_p.length() + fire_extra_length_px, 1.0)
	#_set_facing_from_dx(to_p.x)
	# Put pivot exactly on the mouth (every frame, because mouth anim moves)
	fire_pivot.global_position = origin

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
	fire_pivot.global_rotation = base + rel
	# ---------------------------------------------------

	# Keep fire_hitbox at pivot local origin
	if fire_hitbox:
		fire_hitbox.position = Vector2.ZERO
		fire_hitbox.rotation = 0.0
		fire_hitbox.scale = Vector2.ONE

	# Stretch collision shape to the target distance
	if fire_shape and fire_shape.shape is RectangleShape2D:
		var rect := fire_shape.shape as RectangleShape2D
		rect.size = Vector2(dist, rect.size.y)         # length = dist
		fire_shape.position = Vector2(dist * 0.5, 0.0) # move shape forward

	# Stretch flame sprite visually to match (also forward)
	if flame_sprite:
		flame_sprite.visible = true
		flame_sprite.position = Vector2(dist * 0.5, 0.0)
		flame_sprite.offset = Vector2.ZERO
		flame_sprite.centered = true

		# Determine base sprite width from current frame (if available)
		var base_width := 64.0
		if flame_sprite.sprite_frames:
			var tex := flame_sprite.sprite_frames.get_frame_texture(flame_sprite.animation, flame_sprite.frame)
			if tex:
				base_width = float(tex.get_width())

		if base_width > 0.0:
			flame_sprite.scale = Vector2(dist / base_width, 1.0)
	
	print("FIRE UPDATE origin=", origin, " rot=", fire_pivot.global_rotation, " dist=", dist, " flame_visible=", flame_sprite.visible if flame_sprite else "no sprite")


func _start_flame_sprite() -> void:
	if not flame_sprite:
		return
	flame_sprite.visible = true
	# Use your actual animations: start -> cycle
	if flame_sprite.sprite_frames and flame_sprite.sprite_frames.has_animation("start"):
		flame_sprite.play("start")
	else:
		flame_sprite.play()


func _ensure_flame_cycle() -> void:
	if not flame_sprite:
		return
	if flame_sprite.sprite_frames and flame_sprite.sprite_frames.has_animation("cycle"):
		if flame_sprite.animation != "cycle":
			flame_sprite.play("cycle")


func _stop_flame_sprite() -> void:
	if not flame_sprite:
		return
	# stop animation if exists
	if flame_sprite.sprite_frames and flame_sprite.sprite_frames.has_animation("stop"):
		flame_sprite.play("stop")
	else:
		flame_sprite.stop()
	flame_sprite.visible = false

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

	_attack_running = false

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
	await get_tree().create_timer(breath_lower_time / _ts()).timeout
	if dead:
		return

	# 2) fire pose
	if anim and anim.has_animation("breath_fire"):
		anim.play("breath_fire")

	_start_flame_sprite()
	await get_tree().create_timer(flame_start_time / _ts()).timeout
	_enable_hitbox(fire_hitbox)

	var t := 0.0
	while t < breath_cycle_time and not dead and not Global.camouflage:
		_update_fire_to_player()
		_ensure_flame_cycle()
		await get_tree().process_frame
		t += get_process_delta_time() * _ts()

	await get_tree().create_timer(flame_stop_time / _ts()).timeout
	_disable_hitbox(fire_hitbox)
	_stop_flame_sprite()

	_enable_weakspot(head_weakspot)
	await get_tree().create_timer(breath_vulnerable_time / _ts()).timeout
	_disable_weakspot(head_weakspot)

	if anim and anim.has_animation("breath_recover"):
		anim.play("breath_recover")
	await get_tree().create_timer(breath_recover_time / _ts()).timeout

	if nora_minigame_active:
		_ensure_minigame_idle()
	elif anim and anim.has_animation("idle"):
		anim.play("idle")

func start_nora_minigame(charge_time: float, final_marker: Node2D) -> void:
	nora_minigame_active = true
	# HARD LOCK
	velocity = Vector2.ZERO
	_move_active = false
	_attack_running = false
	chase_enabled = false
	set_physics_process(true)

	_minigame_charge_time = charge_time
	_minigame_final_marker = final_marker
	
	_force_facing_left = true
	_facing = -1
	body_pivot.scale.x = -abs(body_pivot.scale.x)
	

	# stop normal AI movement/attacks
	velocity.x = 0

	# head weakspot ALWAYS ON in this minigame
	_enable_weakspot(head_weakspot)

	# start charge loop visuals (no flame sprite)
	_play_minigame_charge_anims()

func stop_nora_minigame() -> void:
	#nora_minigame_active = false
	#chase_enabled = true
	_disable_weakspot(head_weakspot)

	_stop_flame_immediately()
	
	if nora_minigame_active:
		_ensure_minigame_idle()
	elif anim and anim.has_animation("idle"):
		anim.play("idle")

func _play_minigame_charge_anims() -> void:
	if not anim: return
	if anim.has_animation("breath_lower_2"):
		anim.play("breath_lower_2")
	await get_tree().create_timer(0.25 / _ts()).timeout
	if not nora_minigame_active: return
	if anim.has_animation("breath_fire_2"):
		anim.play("breath_fire_2")


func _do_minigame_slam_interrupt() -> void:
	if not nora_minigame_active or _minigame_doing_slam: return
	_minigame_doing_slam = true

	# stop charge anim momentarily
	if anim and anim.has_animation("slam_minigame"):
		anim.play("slam_minigame")

	# hit player back (damage + knock)
	player = _get_player()
	if player and player.is_in_group("player"):
		#if player.has_method("take_damage"):
		#	player.call("take_damage", slam_damage)

		# optional knockback if your player supports it
		var dir = sign(player.global_position.x - global_position.x)
		if player.has_method("apply_knockback"):
			player.call("apply_knockback", Vector2(dir * 260.0, -200.0))
		elif ("velocity" in player):
			player.velocity.x = dir * 100.0
			player.velocity.y = -100.0

	await get_tree().create_timer(0.35 / _ts()).timeout

	if anim and anim.has_animation("slam_minigame_return"):
		anim.play("slam_minigame_return")
	await get_tree().create_timer(0.25 / _ts()).timeout

	# resume charge anims (lower_2 -> fire_2) but TIMER is controlled by controller (not here)
	await _play_minigame_charge_anims()

	_minigame_doing_slam = false

func do_final_flame_at(world_pos: Vector2) -> void:
	# ✅ short, obvious burst
	if dead:
		return

	# keep minigame state if you call this right before stopping minigame
	_disable_hitbox(fire_hitbox)
	_stop_flame_immediately()

	# Pose for final flame
	if anim:
		if anim.has_animation("breath_lower_2"):
			anim.play("breath_lower_2")
		await get_tree().create_timer(0.25 / _ts()).timeout

		if anim.has_animation("breath_fire_2"):
			anim.play("breath_fire_2")

	# Visual + hitbox burst
	_start_flame_sprite()
	await get_tree().create_timer(flame_start_time / _ts()).timeout
	_enable_hitbox(fire_hitbox)

	var t := 0.0
	var burst_time := 1.0
	while t < burst_time and not dead:
		_update_fire_to_world_pos(world_pos)
		_ensure_flame_cycle()
		await get_tree().process_frame
		t += get_process_delta_time() * _ts()

	_disable_hitbox(fire_hitbox)
	_stop_flame_sprite()

	# return to charge pose if still in minigame
	_ensure_minigame_idle()


func _force_face_left_minigame() -> void:
	# left means _facing = -1 in your system
	if _facing != -1:
		_facing = -1
		if body_pivot:
			body_pivot.scale.x = -abs(body_pivot.scale.x)

func _ensure_minigame_idle() -> void:
	if not nora_minigame_active:
		return
	if not anim:
		return

	# Always show charge pose instead of idle
	if anim.has_animation("breath_fire_2"):
		if anim.current_animation != "breath_fire_2":
			anim.play("breath_fire_2")

func _update_fire_to_world_pos(target: Vector2) -> void:
	if mouth_marker == null or fire_pivot == null:
		return

	var origin: Vector2 = mouth_marker.global_position
	var to_t: Vector2 = target - origin
	var dist: float = max(to_t.length() + fire_extra_length_px, 1.0)

	# Put pivot at mouth
	fire_pivot.global_position = origin

	# Aim directly at target (optionally clamp if you want)
	fire_pivot.global_rotation = to_t.angle()

	# Reset local transforms
	if fire_hitbox:
		fire_hitbox.position = Vector2.ZERO
		fire_hitbox.rotation = 0.0
		fire_hitbox.scale = Vector2.ONE

	# Stretch collision to distance
	if fire_shape and fire_shape.shape is RectangleShape2D:
		var rect := fire_shape.shape as RectangleShape2D
		rect.size = Vector2(dist, rect.size.y)
		fire_shape.position = Vector2(dist * 0.5, 0.0)

	# Stretch flame sprite
	if flame_sprite:
		flame_sprite.visible = true
		flame_sprite.position = Vector2(dist * 0.5, 0.0)

		var base_width := 64.0
		if flame_sprite.sprite_frames:
			var tex := flame_sprite.sprite_frames.get_frame_texture(flame_sprite.animation, flame_sprite.frame)
			if tex:
				base_width = float(tex.get_width())
		if base_width > 0.0:
			flame_sprite.scale = Vector2(dist / base_width, 1.0)
