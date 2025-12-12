extends CharacterBody2D
class_name GawrBoss

signal boss_died

# -------------------------------------------------------------
# CONFIG
# -------------------------------------------------------------
@export var max_health: int = 300
@export var walk_speed: float = 60.0
@export var engage_distance: float = 500.0

@export var slam_damage: int = 10
@export var fire_damage: int = 15

# Slam timings
@export var slam_windup_time: float = 0.35
@export var slam_stun_time: float = 5
@export var slam_return_time: float = 0.6

# Breath timings
@export var breath_lower_time: float = 0.4
@export var breath_cycle_time: float = 1.0
@export var breath_recover_time: float = 0.8

# Flame sprite timings
@export var flame_start_time: float = 0.20
@export var flame_stop_time: float = 0.20

# Hurt lock
@export var hurt_flash_time: float = 0.15

# -------------------------------------------------------------
# STATE
# -------------------------------------------------------------
var health: int = 0
var dead: bool = false
var taking_damage: bool = false

var _ai_running: bool = false
var _attack_running: bool = false
var _started_once: bool = false

var player: Node2D = null

# -------------------------------------------------------------
# NODES
# -------------------------------------------------------------
@onready var anim: AnimationPlayer = $AnimationPlayer

@onready var head_weakspot: Area2D = $BodyPivot/HeadPivot/HeadWeakspot

@onready var left_hitbox: Area2D = $BodyPivot/LeftArm/LeftHand/LeftSlamHitbox
@onready var left_weakspot: Area2D = $BodyPivot/LeftArm/LeftHand/LeftWeakspot

@onready var right_hitbox: Area2D = $BodyPivot/RightArm/RightHand/RightSlamHitbox
@onready var right_weakspot: Area2D = $BodyPivot/RightArm/RightHand/RightWeakspot

@onready var fire_hitbox: Area2D = $BodyPivot/HeadPivot/MouthMarker/FirePivot/FireHitbox
@onready var fire_pivot: Node2D = $BodyPivot/HeadPivot/MouthMarker/FirePivot

@onready var flame_sprite: AnimatedSprite2D =$BodyPivot/HeadPivot/MouthMarker/FirePivot/FlameSprite


@export var align_tolerance: float = 30.0
@export var slam_left_offset: float = 140.0   # boss stands a bit LEFT of player -> left hand reaches
@export var slam_right_offset: float = -140.0 # boss stands a bit RIGHT of player -> right hand reaches

var _move_target_x: float = 0.0
var _desired_attack: String = ""  # "slam_left", "slam_right", "breath"

@onready var mouth_marker: Marker2D = $BodyPivot/HeadPivot/MouthMarker
@onready var fire_shape: CollisionShape2D = $BodyPivot/HeadPivot/MouthMarker/FirePivot/FireHitbox/CollisionShape2D

@onready var body_pivot: Node2D = $BodyPivot

var _facing: int = 1 # 1 = facing right, -1 = facing left

@export var desired_attack_distance: float = 220.0  # how far boss wants to stand from player before attacking
@export var min_move_distance: float = 25.0         # ignore tiny moves to prevent jitter

var _move_active: bool = false
var _target_x: float = 0.0

@export var chase_stop_distance: float = 220.0  # stand this far from player
@export var chase_deadzone: float = 20.0        # don’t jitter
@export var chase_enabled: bool = true

@export var attack_cooldown: float = 0.6
var _next_attack_time: float = 0.0
@export var slam_side_offset: float = 140.0  # distance from player

@export var hurt_flash_color: Color = Color(1, 1, 1, 1)
@export var hurt_flash_strength: float = 1.0 # 1.0 = pure white, >1 doesn't work with modulate
@export var hurt_flash_up_time: float = 0.05
@export var hurt_flash_down_time: float = 0.10

var _hurt_tween: Tween
var _base_modulate: Color = Color(1, 1, 1, 1)

@export var breath_post_flame_vuln_time: float = 0.6
@export var breath_recover_vuln_time: float = 1.0



@export var flash_up_time := 0.05
@export var flash_down_time := 0.10

var _flash_mat: ShaderMaterial
var _flash_targets: Array[CanvasItem] = []

func _ts() -> float:
	return max(Global.global_time_scale, 0.05)


func _ready() -> void:
	randomize()
	_base_modulate = body_pivot.modulate
	health = max_health
	_disable_all_hitboxes()
	_disable_all_weakspots()

	if flame_sprite:
		flame_sprite.visible = false
		flame_sprite.stop()

	_connect_weakspot(head_weakspot)
	_connect_weakspot(left_weakspot)
	_connect_weakspot(right_weakspot)

	if left_hitbox:
		left_hitbox.body_entered.connect(_on_attack_hitbox_body_entered.bind(left_hitbox))
	if right_hitbox:
		right_hitbox.body_entered.connect(_on_attack_hitbox_body_entered.bind(right_hitbox))
	if fire_hitbox:
		fire_hitbox.body_entered.connect(_on_attack_hitbox_body_entered.bind(fire_hitbox))

	# IMPORTANT: This boss should not block the player.
	# Boss stands on ground (layer 2), but does not collide with player (layer 1).
	#collision_layer = 4
	#collision_mask = 2

	set_physics_process(true)
	set_process(true)
	
	_force_fire_nodes_clean()
	_setup_flash_targets()
	print("GawrBoss READY: ", name, "  layer=", collision_layer, " mask=", collision_mask)

func _physics_process(delta: float) -> void:
	# reacquire player first (so debug print won't crash)
	player = Global.playerBody as Node2D
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D

	if Engine.get_frames_drawn() % 60 == 0 and player:
		print("adx=", abs(player.global_position.x - global_position.x),
			" velx=", velocity.x,
			" move_active=", _move_active,
			" attack=", _attack_running)
		

	if dead:
		velocity.x = 0
		move_and_slide()
		return

	# Freeze conditions (boss won't move while attacking/hurt/camo)
	if taking_damage or _attack_running or Global.camouflage:
		velocity.x = 0
		move_and_slide()
		return

	if player == null or not chase_enabled:
		velocity.x = 0
		move_and_slide()
		return

	# --- AI-command move has priority ---
	if _move_active:
		var dx_to_target := _target_x - global_position.x
		_set_facing_from_dx(dx_to_target)

		if abs(dx_to_target) <= align_tolerance:
			velocity.x = 0
			_move_active = false
			if anim and anim.has_animation("idle"):
				anim.play("idle")
		else:
	# dx_to_target can sometimes end up weird; force a direction if sign()==0
			var dir = sign(dx_to_target)
			if dir == 0:
				dir = 1 if dx_to_target > 0.0 else -1

			velocity.x = dir * walk_speed * _ts()
			if anim and anim.has_animation("walk"):
				anim.play("walk")

		move_and_slide()
		return  # IMPORTANT: only return when using move_active

	# --- Normal chase (only when not move_active) ---
	var dx := player.global_position.x - global_position.x
	_set_facing_from_dx(dx)

	var adx = abs(dx)
	var desired := chase_stop_distance

	if adx > desired + chase_deadzone:
		velocity.x = sign(dx) * walk_speed * _ts()
		if anim and anim.has_animation("walk"):
			anim.play("walk")
	else:
		velocity.x = 0
		if anim and anim.has_animation("idle"):
			anim.play("idle")

	move_and_slide()


# -------------------------------------------------------------
# PUBLIC API
# -------------------------------------------------------------
func reset_for_battle() -> void:
	dead = false
	taking_damage = false
	_attack_running = false

	health = max_health

	_disable_all_hitboxes()
	_disable_all_weakspots()
	_stop_flame_immediately()

	set_physics_process(true)
	set_process(true)

	if anim and anim.has_animation("idle"):
		anim.play("idle")

	print("GawrBoss reset_for_battle() called. Starting AI (deferred).")

	# Start AI deferred to avoid “called before fully enabled” issues.
	if not _ai_running:
		_ai_running = true
		call_deferred("_start_ai_deferred")

func _start_ai_deferred() -> void:
	# Prevent accidental double-start
	if dead:
		_ai_running = false
		return
	if _started_once:
		# if you want: allow re-run, set _started_once=false in reset_for_battle()
		pass
	_started_once = true

	print("GawrBoss AI LOOP STARTED.")
	_run_ai_loop()

# -------------------------------------------------------------
# AI LOOP
# -------------------------------------------------------------
func _run_ai_loop() -> void:
	
	
	while not dead:
		player = Global.playerBody as Node2D
		if player == null or not is_instance_valid(player):
			player = get_tree().get_first_node_in_group("player") as Node2D

		if player == null:
			await _play_idle(0.2)
			continue

		if Global.camouflage:
			_disable_hitbox(fire_hitbox)
			_stop_flame_immediately()
			await _play_idle(0.2)
			continue

		if taking_damage:
			await get_tree().process_frame
			continue

		# --- WAIT UNTIL WE ARE IN A GOOD RANGE TO ATTACK ---
		var dx = player.global_position.x - global_position.x
		var adx = abs(dx)

		#var desired := chase_stop_distance
		#var in_sweet_spot = abs(adx - desired) <= (chase_deadzone + 10.0)

		# If far, do NOT attack. Let _physics_process chase.
		#if not in_sweet_spot:
		#	await get_tree().process_frame
		#	continue

		# Cooldown so we don't perma-attack
		var now := Time.get_ticks_msec() / 1000.0
		if now < _next_attack_time:
			await get_tree().process_frame
			continue

		# Step 1: walk to player's center first (feels aggressive)
		await _move_to_target_x(player.global_position.x)

		# short beat so it doesn’t jitter
		await _play_idle(0.15)
		if dead: break

		# Decide attack (1/4 breath, 3/4 slam)
		if randi() % 4 == 0:
			await _fire_breath_phase()
		else:
			var use_left := _choose_closer_hand()
			await _move_to_target_x(_slam_target_x(use_left))
			await _slam_phase_with_hand(use_left)

		_next_attack_time = Time.get_ticks_msec() / 1000.0 + attack_cooldown
		#if randi() % 2 == 0:
		#	_desired_attack = "slam"
		#	var use_left: bool = (randi() % 2 == 0)
		#	_move_target_x = player.global_position.x + (slam_left_offset if use_left else slam_right_offset)

			# Walk to the correct side first (only if not already close enough)
		#	if abs(_move_target_x - global_position.x) > engage_distance * 0.25:
		#		await _move_to_target_x(_move_target_x)

			# Now do the slam using the same hand you planned
		#	await _slam_phase_with_hand(use_left)
		#else:
		#	_desired_attack = "breath"
		#	_move_target_x = player.global_position.x  # center for breath
		#	if abs(_move_target_x - global_position.x) > engage_distance * 0.25:
		#		await _move_to_target_x(_move_target_x)

		#	await _fire_breath_phase()

	_ai_running = false
	print("GawrBoss AI LOOP ENDED.")

func _play_idle(seconds: float) -> void:
	# Don't force animations here. Physics handles walk/idle.
	await get_tree().create_timer(seconds / _ts()).timeout

func _move_to_target_x(target_x: float) -> void:
	_target_x = target_x
	_move_active = true

	var start_time := Time.get_ticks_msec()
	var max_ms := 1500  # 1.5s safety timeout

	while _move_active and not dead and not taking_damage and not Global.camouflage:
		# safety: if we get stuck, abort so AI can continue
		if Time.get_ticks_msec() - start_time > max_ms:
			print("GawrBoss: move_to_target TIMEOUT. target=", _target_x, " pos=", global_position.x)
			_move_active = false
			break
		await get_tree().process_frame


# -------------------------------------------------------------
# SLAM
# -------------------------------------------------------------
func _slam_phase_with_hand(use_left: bool) -> void:
	_set_facing_from_dx(player.global_position.x - global_position.x)

	if dead or _attack_running:
		return
	_attack_running = true

	#var use_left: bool = (randi() % 2 == 0)
	var hitbox: Area2D = left_hitbox if use_left else right_hitbox
	var weakspot: Area2D = left_weakspot if use_left else right_weakspot

	# windup
	if anim:
		if use_left and anim.has_animation("slam_left"):
			anim.play("slam_left")
		elif (not use_left) and anim.has_animation("slam_right"):
			anim.play("slam_right")

	await get_tree().create_timer(slam_windup_time/ _ts()).timeout
	if dead:
		_attack_running = false
		return

	# impact damage window
	_enable_hitbox(hitbox)
	await get_tree().create_timer(0.12/ _ts()).timeout
	_disable_hitbox(hitbox)

	# vulnerable idle on ground
	if anim:
		if use_left and anim.has_animation("slam_left_idle"):
			anim.play("slam_left_idle")
		elif (not use_left) and anim.has_animation("slam_right_idle"):
			anim.play("slam_right_idle")

	_enable_weakspot(weakspot)
	await get_tree().create_timer(slam_stun_time/ _ts()).timeout
	_disable_weakspot(weakspot)

	if dead:
		_attack_running = false
		return

	# return
	if anim:
		if use_left and anim.has_animation("slam_left_return"):
			anim.play("slam_left_return")
		elif (not use_left) and anim.has_animation("slam_right_return"):
			anim.play("slam_right_return")

	await get_tree().create_timer(slam_return_time/ _ts()).timeout
	_attack_running = false

# -------------------------------------------------------------
# FIRE BREATH
# -------------------------------------------------------------
func _fire_breath_phase() -> void:
	_set_facing_from_dx(player.global_position.x - global_position.x)
	
	if Global.camouflage:
		_attack_running = false
		return

	if dead or _attack_running:
		return
	_attack_running = true

	# Lower head
	if anim and anim.has_animation("breath_lower"):
		anim.play("breath_lower")
	await get_tree().create_timer(breath_lower_time/ _ts()).timeout
	if dead:
		_attack_running = false
		return

	# Start flame visuals
	_start_flame()

	if anim and anim.has_animation("breath_fire"):
		anim.play("breath_fire")

	await get_tree().create_timer(flame_start_time/ _ts()).timeout

	_enable_hitbox(fire_hitbox)

	# === AIM & STRETCH WHILE BREATHING ===
	var t := 0.0
	while t < breath_cycle_time and not dead:
		_update_fire_to_player()
		t += get_process_delta_time()
		await get_tree().process_frame

	_disable_hitbox(fire_hitbox)

	_stop_flame()
	await get_tree().create_timer(flame_stop_time / _ts()).timeout
	if dead:
		_attack_running = false
		return

	# ✅ punish window AFTER flames are gone
	_enable_weakspot(head_weakspot)

	# keep the "breath_fire" pose a bit longer (optional)
	await get_tree().create_timer(breath_post_flame_vuln_time / _ts()).timeout

	if anim and anim.has_animation("breath_recover"):
		anim.play("breath_recover")

	# ✅ stay vulnerable through recover too
	await get_tree().create_timer((breath_recover_time + breath_recover_vuln_time) / _ts()).timeout

	_disable_weakspot(head_weakspot)
	_attack_running = false

func _start_flame() -> void:
	if flame_sprite == null:
		return
	flame_sprite.visible = true
	if flame_sprite.sprite_frames and flame_sprite.sprite_frames.has_animation("start"):
		flame_sprite.play("start")
	call_deferred("_switch_flame_to_cycle")

func _switch_flame_to_cycle() -> void:
	await get_tree().create_timer(flame_start_time/ _ts()).timeout
	if dead or flame_sprite == null:
		return
	if flame_sprite.sprite_frames and flame_sprite.sprite_frames.has_animation("cycle"):
		flame_sprite.play("cycle")

func _stop_flame() -> void:
	if flame_sprite == null:
		return
	if flame_sprite.sprite_frames and flame_sprite.sprite_frames.has_animation("stop"):
		flame_sprite.play("stop")
	else:
		flame_sprite.visible = false

func _stop_flame_immediately() -> void:
	if flame_sprite == null:
		return
	flame_sprite.visible = false
	flame_sprite.stop()

# -------------------------------------------------------------
# DAMAGE / DEATH
# -------------------------------------------------------------
func take_damage(amount: int) -> void:
	if dead:
		return

	health -= amount
	taking_damage = true
	_flash_hurt()
	await get_tree().create_timer(hurt_flash_time/ _ts()).timeout
	taking_damage = false

	if health <= 0:
		_die()

func _flash_hurt() -> void:
	if _flash_mat == null:
		return

	if _hurt_tween and _hurt_tween.is_running():
		_hurt_tween.kill()

	_flash_mat.set_shader_parameter("flash", 1.0)

	_hurt_tween = create_tween()
	_hurt_tween.tween_method(
		func(v): _flash_mat.set_shader_parameter("flash", v),
		1.0, 0.0,
		flash_down_time / _ts()
	)


func _restore_modulate(ci: CanvasItem, old_color: Color) -> void:
	await get_tree().create_timer(hurt_flash_time/ _ts()).timeout
	if ci:
		ci.modulate = old_color

func _die() -> void:
	dead = true
	_disable_all_hitboxes()
	_disable_all_weakspots()
	_stop_flame_immediately()

	if anim and anim.has_animation("die"):
		anim.play("die")

	boss_died.emit()

# -------------------------------------------------------------
# HITBOX / WEAKSPOT HELPERS
# -------------------------------------------------------------
func _connect_weakspot(spot: Area2D) -> void:
	if spot == null:
		return

	spot.monitoring = true
	spot.monitorable = true

	# Only Area2D attacks should count
	if not spot.area_entered.is_connected(_on_weakspot_area_entered):
		spot.area_entered.connect(_on_weakspot_area_entered)


func _enable_hitbox(box: Area2D) -> void:
	if box == null:
		return
	var shape: CollisionShape2D = box.get_node_or_null("CollisionShape2D")
	if shape:
		shape.disabled = false

func _disable_hitbox(box: Area2D) -> void:
	if box == null:
		return
	var shape: CollisionShape2D = box.get_node_or_null("CollisionShape2D")
	if shape:
		shape.disabled = true

func _disable_all_hitboxes() -> void:
	_disable_hitbox(left_hitbox)
	_disable_hitbox(right_hitbox)
	_disable_hitbox(fire_hitbox)

func _enable_weakspot(ws: Area2D) -> void:
	if ws == null:
		return
	var shape: CollisionShape2D = ws.get_node_or_null("CollisionShape2D")
	if shape:
		shape.disabled = false

func _disable_weakspot(ws: Area2D) -> void:
	if ws == null:
		return
	var shape: CollisionShape2D = ws.get_node_or_null("CollisionShape2D")
	if shape:
		shape.disabled = true

func _disable_all_weakspots() -> void:
	_disable_weakspot(head_weakspot)
	_disable_weakspot(left_weakspot)
	_disable_weakspot(right_weakspot)

# -------------------------------------------------------------
# DAMAGE DEALING
# -------------------------------------------------------------
func _on_attack_hitbox_body_entered(body: Node, source_hitbox: Area2D) -> void:
	if dead:
		return
	if body == null:
		return
	if not body.is_in_group("player"):
		return

	var dmg: int = fire_damage if source_hitbox == fire_hitbox else slam_damage
	if body.has_method("take_damage"):
		body.call("take_damage", dmg)

func _on_weakspot_entered(area: Area2D) -> void:
	if dead:
		return
	if area == null:
		return
	if not area.is_in_group("player_attack"):
		return

	var dmg: int = 10
	if "damage" in area:
		dmg = int(area.damage)

	take_damage(dmg)
	
func _update_fire_to_player() -> void:
	if player == null or not is_instance_valid(player):
		return
	if mouth_marker == null or fire_pivot == null:
		return

	_force_fire_nodes_clean()

	var origin: Vector2 = mouth_marker.global_position
	var to_p: Vector2 = player.global_position - origin
	var dist: float = max(to_p.length(), 1.0)

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

	if fire_hitbox:
		fire_hitbox.position = Vector2.ZERO

	if fire_shape and fire_shape.shape is RectangleShape2D:
		var rect := fire_shape.shape as RectangleShape2D
		rect.size = Vector2(dist, rect.size.y)
		fire_shape.position = Vector2(dist * 0.5, 0.0)

	if flame_sprite:
		flame_sprite.visible = true
		flame_sprite.centered = true
		flame_sprite.offset = Vector2.ZERO
		flame_sprite.position = Vector2(dist * 0.5, 0.0)

		var tex: Texture2D = null
		if flame_sprite.sprite_frames:
			tex = flame_sprite.sprite_frames.get_frame_texture(flame_sprite.animation, flame_sprite.frame)

		var base_width := 64.0
		if tex:
			base_width = float(tex.get_width())

		if base_width > 0.0:
			flame_sprite.scale = Vector2(dist / base_width, 1.0)

func _force_fire_nodes_clean() -> void:
	# These MUST be zeroed or you will see the beam coming from "body".
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
		# don't touch fire_shape.scale normally

	if flame_sprite:
		flame_sprite.position = Vector2.ZERO
		flame_sprite.rotation = 0.0
		flame_sprite.offset = Vector2.ZERO


func _set_facing_from_dx(dx: float) -> void:
	var new_facing: int = -1 if dx < 0.0 else 1
	if new_facing == 0:
		return
	if new_facing == _facing:
		return

	_facing = new_facing

	# Flip the whole rig
	# Using scale.x keeps your node hierarchy consistent.
	body_pivot.scale.x = abs(body_pivot.scale.x) * float(_facing)

	# IMPORTANT: when flipping via scale, rotations become mirrored.
	# So we’ll apply fire_pivot rotation in local space later (see below).

func _get_attack_stand_x() -> float:
	if player == null or not is_instance_valid(player):
		return global_position.x
	var dx := player.global_position.x - global_position.x
	var side := 1.0 if dx >= 0.0 else -1.0
	# Stand at a fixed distance in front of the player (so boss actually “chases”)
	return player.global_position.x - side * desired_attack_distance

func _choose_closer_hand() -> bool:
	# returns true = use_left, false = use_right
	if player == null or not is_instance_valid(player):
		return true

	# If you have hitboxes, this is the most reliable even with flipping
	if left_hitbox and right_hitbox:
		var dl = abs(player.global_position.x - left_hitbox.global_position.x)
		var dr = abs(player.global_position.x - right_hitbox.global_position.x)
		return dl <= dr

	# fallback
	return (player.global_position.x < global_position.x)

func _slam_target_x(use_left: bool) -> float:
	# use_left = slam with left hand -> boss stands left side of player
	var off := slam_side_offset
	return player.global_position.x + (-off if use_left else off)

func _on_weakspot_area_entered(area: Area2D) -> void:
	if dead or area == null:
		return

	# --- BASE ENEMY STYLE: exact match with Global.playerDamageZone ---
	var is_player_damage_zone := (area == Global.playerDamageZone)

	# --- Fallback 1: sometimes Global.playerDamageZone is a parent node of the hitbox
	if not is_player_damage_zone and Global.playerDamageZone and area.get_parent() == Global.playerDamageZone:
		is_player_damage_zone = true

	# --- Fallback 2: if your player attack Area2D isn't assigned to Global.playerDamageZone,
	# match by known names (your debug shows AttackArea / Hitbox)
	if not is_player_damage_zone:
		if area.name == "AttackArea" or area.name == "Hitbox":
			is_player_damage_zone = true

	if not is_player_damage_zone:
		return

	# Damage amount exactly like BaseEnemy
	var dmg := Global.playerDamageAmount

	# Optional: if your attack area carries its own damage
	if "damage" in area:
		dmg = int(area.damage)

	take_damage(dmg)

func _setup_flash_targets() -> void:
	_flash_targets.clear()

	# Collect everything visual under the boss rig
	for n in body_pivot.get_children():
		_collect_canvas_items_recursive(n)

	# Make 1 shared instance for THIS boss (so it doesn't affect other bosses)
	var shader := load("res://shaders/flash_white.gdshader") as Shader
	_flash_mat = ShaderMaterial.new()
	_flash_mat.shader = shader
	_flash_mat.set_shader_parameter("flash", 0.0)

	# Apply to each sprite/animated sprite
	for ci in _flash_targets:
		# IMPORTANT: duplicate so per-node edits don't fight
		ci.material = _flash_mat

func _collect_canvas_items_recursive(node: Node) -> void:
	if node is CanvasItem:
		_flash_targets.append(node)
	for c in node.get_children():
		_collect_canvas_items_recursive(c)
