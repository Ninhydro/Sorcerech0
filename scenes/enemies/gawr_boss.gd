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
@export var slam_stun_time: float = 1.8
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

func _ts() -> float:
	return max(Global.global_time_scale, 0.05)


func _ready() -> void:
	randomize()

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
	collision_layer = 4
	collision_mask = 2

	set_physics_process(true)
	set_process(true)
	
	_force_fire_nodes_clean()
	
	print("GawrBoss READY: ", name, "  layer=", collision_layer, " mask=", collision_mask)

func _process(delta):
	if anim:
		anim.speed_scale = _ts()
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
		# reacquire player EVERY LOOP (robust)
		player = Global.playerBody as Node2D
		if Global.camouflage:
			# stop any active breath visuals/hitboxes just in case
			_disable_hitbox(fire_hitbox)
			_stop_flame_immediately()
			await _play_idle(0.4 / _ts())
			continue
		
		if player == null or not is_instance_valid(player):
			player = get_tree().get_first_node_in_group("player") as Node2D

		if player == null:
			# THIS is the reason bosses “idle forever” most often.
			print("GawrBoss: player not found (Global.playerBody null and group 'player' missing).")
			await _play_idle(0.6)
			continue

		if taking_damage:
			await get_tree().process_frame
			continue

		var dist_x: float = abs(player.global_position.x - global_position.x)

		# Debug every cycle (you can comment later)
		#print("GawrBoss: dist_x=", dist_x, " engage=", engage_distance, " attacking=", _attack_running)

		#if dist_x > engage_distance:
		#	await _move_closer_phase()
		#	continue

		# Near player: idle then pick attack
		await _play_idle(0.4)
		if dead: break

		# Decide attack
		if randi() % 2 == 0:
			_desired_attack = "slam"
			var use_left: bool = (randi() % 2 == 0)
			_move_target_x = player.global_position.x + (slam_left_offset if use_left else slam_right_offset)

			# Walk to the correct side first (only if not already close enough)
			if abs(_move_target_x - global_position.x) > engage_distance * 0.25:
				await _move_to_target_x(_move_target_x)

			# Now do the slam using the same hand you planned
			await _slam_phase_with_hand(use_left)
		else:
			_desired_attack = "breath"
			_move_target_x = player.global_position.x  # center for breath
			if abs(_move_target_x - global_position.x) > engage_distance * 0.25:
				await _move_to_target_x(_move_target_x)

			await _fire_breath_phase()

	_ai_running = false
	print("GawrBoss AI LOOP ENDED.")

func _play_idle(seconds: float) -> void:
	if anim and anim.has_animation("idle"):
		anim.play("idle")
	await get_tree().create_timer(seconds/ _ts()).timeout

func _move_to_target_x(target_x: float) -> void:
	if player == null or not is_instance_valid(player):
		return

	if anim and anim.has_animation("walk"):
		anim.play("walk")

	while not dead and not taking_damage:
		var dx: float = target_x - global_position.x
		_set_facing_from_dx(dx) 

		if abs(dx) <= align_tolerance:
			break

		var dir: int = -1 if dx < 0.0 else 1
		global_position.x += float(dir) * walk_speed * get_physics_process_delta_time() * _ts()

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
	await get_tree().create_timer(flame_stop_time/ _ts()).timeout

	if dead:
		_attack_running = false
		return

	_enable_weakspot(head_weakspot)

	if anim and anim.has_animation("breath_recover"):
		anim.play("breath_recover")
	await get_tree().create_timer(breath_recover_time/ _ts()).timeout

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
	if body_pivot and body_pivot is CanvasItem:
		var ci: CanvasItem = body_pivot as CanvasItem
		var old: Color = ci.modulate
		ci.modulate = Color(1, 0.7, 0.7, 1)
		call_deferred("_restore_modulate", ci, old)

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
	if not spot.area_entered.is_connected(_on_weakspot_entered):
		spot.area_entered.connect(_on_weakspot_entered)

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
