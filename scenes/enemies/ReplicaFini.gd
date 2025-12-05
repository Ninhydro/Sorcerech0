extends BaseEnemy 
class_name ReplicaFini

# --- Tunable pattern values ---
@export var walk_speed: float = 40.0              # slow walk toward player
@export var melee_forward_distance: float = 32.0  # how far she slides forward on melee
@export var melee_dash_time: float = 0.18         # seconds of forward motion
@export var backstep_distance: float = 48.0       # how far she moves back before laser
@export var backstep_time: float = 0.22           # seconds of backward motion

@export var walk_phase_duration: float = 1.0      # how long she "hunts" slowly before melee
@export var idle_before_melee: float = 0.5        # stand still before melee
@export var idle_after_melee: float = 1        # short pause after melee
@export var tired_duration: float = 3          # how long she stays tired

@export var melee_damage: int = 10                # melee slash damage
@export var laser_damage: int = 20                # laser damage
@export var laser_duration: float = 0.8           # how long the beam stays on


@onready var laser_beam = $LaserBeam


var pattern_running: bool = false

var on_platform: bool = false                     # true after jumping to a marker

@onready var laser_origin_marker: Marker2D = $LaserOrigin
var marker_low_left: Marker2D
var marker_mid_left: Marker2D
var marker_high_left: Marker2D
var marker_low_right: Marker2D
var marker_mid_right: Marker2D
var marker_high_right: Marker2D

var on_upper_platform: bool = false   # true when she’s on mid/high markers

var jump_markers: Array[Node2D] = []
@export var jump_check_vertical_diff: float = 48.0  # how much higher the player must be

func setup_markers(markers: Array) -> void:
	for m in markers:
		if not (m is Marker2D):
			continue

		# Add EVERY marker to jump_markers so _jump_to_best_marker() has candidates
		jump_markers.append(m)

		match m.name:
			"ReplicaMarker_LowLeft":
				marker_low_left = m
			"ReplicaMarker_MidLeft":
				marker_mid_left = m
			"ReplicaMarker_HighLeft":
				marker_high_left = m
			"ReplicaMarker_LowRight":
				marker_low_right = m
			"ReplicaMarker_MidRight":
				marker_mid_right = m
			"ReplicaMarker_HighRight":
				marker_high_right = m

	_print_marker_debug()

func _print_marker_debug() -> void:
	print("=== ReplicaFini marker debug ===")
	if marker_low_left:
		print("LowLeft     y = ", marker_low_left.global_position.y)
	if marker_mid_left:
		print("MidLeft     y = ", marker_mid_left.global_position.y)
	if marker_high_left:
		print("HighLeft    y = ", marker_high_left.global_position.y)
	if marker_low_right:
		print("LowRight    y = ", marker_low_right.global_position.y)
	if marker_mid_right:
		print("MidRight    y = ", marker_mid_right.global_position.y)
	if marker_high_right:
		print("HighRight   y = ", marker_high_right.global_position.y)
	print("===============================")



func _ready() -> void:
	# Call BaseEnemy setup
	super._ready()

	# We control everything manually here
	can_drop_health = true
	use_edge_detection = false
	can_jump_chase = false

	attack_range = 60          # melee reach
	enemy_damage = melee_damage
	attack_type = AttackType.MELEE

	# Make sure she doesn't randomly roam/chase from BaseEnemy logic
	is_enemy_chase = false
	is_roaming = false

	# Configure beam damage
	if laser_beam:
		laser_beam.damage = laser_damage

	# Start pattern coroutine
	_run_pattern()


func _process(delta: float) -> void:
	# Basic time scaling for animations
	if animation_player:
		animation_player.speed_scale = Global.global_time_scale

	# Simple gravity
	if not is_on_floor():
		velocity.y += gravity * delta

	# Track player from Global
	player = Global.playerBody

	# If dead, stop movement
	if dead:
		velocity.x = 0.0
		move_and_slide()
		return

	# --- HURT PRIORITY ---
	if taking_damage:
		velocity.x = 0.0  # no sliding while hurt

		if animation_player and animation_player.has_animation("hurt"):
			if current_animation != "hurt":
				current_animation = "hurt"
				animation_player.play("hurt")
		elif animation_player and animation_player.has_animation("idle"):
			if current_animation != "idle":
				current_animation = "idle"
				animation_player.play("idle")

		move_and_slide()
		return
	# --- END HURT PRIORITY ---

	# Normal movement from pattern
	move_and_slide()


# ===================================================================
#                     MAIN PATTERN LOOP
# ===================================================================
func _run_pattern() -> void:
	if pattern_running:
		return
	pattern_running = true

	while not dead:
		if on_platform:
			# Special pattern when sitting on a marker/platform:
			# idle → laser → tired → repeat
			await _phase_platform_idle_laser_tired()
			if dead:
				break
			continue

		# === GROUND PATTERN ===
		await _phase_idle_walk()
		if dead:
			break

		await _phase_melee()
		if dead:
			break

		await _phase_idle_after_melee()
		if dead:
			break
		

		await _phase_backstep()
		if dead:
			break

		await _phase_laser()
		if dead:
			break

		await _phase_tired()


# ===================================================================
#                    PHASE 1 – IDLE + SLOW WALK
# ===================================================================
func _phase_idle_walk() -> void:
	var elapsed: float = 0.0

	# We're on ground pattern now
	on_platform = false

	while elapsed < walk_phase_duration and not dead:
		# From ground: if player is clearly above, jump to marker and switch to platform pattern
		if is_on_floor() and player and is_instance_valid(player) and not jump_markers.is_empty():
			var dy := player.global_position.y - global_position.y
			# Remember: more negative y is higher on screen
			# So player above boss => dy < 0
			if player.global_position.y < global_position.y - jump_check_vertical_diff:
				print("ReplicaFini: player above, trying to jump. ",
					"boss_y=", global_position.y,
					" player_y=", player.global_position.y,
					" dy=", dy,
					" threshold=", -jump_check_vertical_diff)
				await _jump_to_best_marker()
				print("ReplicaFini: finished _jump_to_best_marker, on_platform=", on_platform)
				return
			else:
				print("ReplicaFini: player not high enough to jump. ",
					"boss_y=", global_position.y,
					" player_y=", player.global_position.y,
					" dy=", dy)
					
		if player and is_instance_valid(player):
			var dx := player.global_position.x - global_position.x

			# Face player
			if dx != 0.0:
				dir.x = sign(dx)
				sprite.flip_h = (dir.x < 0.0)

			# Only move if not too close
			if abs(dx) > 20.0:
				velocity.x = dir.x * walk_speed
				if current_animation != "walk" and animation_player.has_animation("walk"):
					current_animation = "walk"
					animation_player.play("walk")
			else:
				velocity.x = 0.0
				if current_animation != "idle" and animation_player.has_animation("idle"):
					current_animation = "idle"
					animation_player.play("idle")
		else:
			# No player reference – idle
			velocity.x = 0.0
			if current_animation != "idle" and animation_player.has_animation("idle"):
				current_animation = "idle"
				animation_player.play("idle")

		await get_tree().process_frame
		elapsed += get_process_delta_time()

# ===================================================================
#                    PHASE 2 – MELEE ATTACK (SLASH)
# ===================================================================
func _phase_melee() -> void:
	if dead:
		return

	# Face the player first
	if player and is_instance_valid(player):
		var dx = player.global_position.x - global_position.x
		if dx != 0.0:
			dir.x = sign(dx)
			sprite.flip_h = (dir.x < 0.0)

	# Short idle before attack
	velocity.x = 0.0
	if animation_player.has_animation("idle"):
		current_animation = "idle"
		animation_player.play("idle")
	await get_tree().create_timer(idle_before_melee / Global.global_time_scale).timeout

	# Play attack animation and slide forward a bit
	var total_time = melee_dash_time
	var moved = 0.0
	var dash_speed = melee_forward_distance / max(total_time, 0.01)

	if animation_player.has_animation("attack"):
		print("PLAY ATTACK")
		current_animation = "attack"
		if sprite.flip_h == true:
			sprite.position = Vector2(-20, -53)
			animation_player.play("attack")
		else:
			sprite.position = Vector2(20, -53)
			animation_player.play("attack")

	while moved < melee_forward_distance and not dead:
		var dt = get_process_delta_time()
		var step = dash_speed * dt
		moved += step
		velocity.x = dir.x * dash_speed
		await get_tree().process_frame

	# Stop horizontal motion
	velocity.x = 0.0

	# Damage check
	attack_target = player
	enemy_damage = melee_damage
	if is_player_in_attack_range():
		deal_damage()

	# Small pause at end of melee
	await get_tree().create_timer(0.1 / Global.global_time_scale).timeout


# ===================================================================
#                PHASE 3 – SHORT IDLE AFTER MELEE
# ===================================================================
func _phase_idle_after_melee() -> void:
	if dead:
		return

	velocity.x = 0.0
	if animation_player.has_animation("idle"):
		current_animation = "idle"
		animation_player.play("idle")

	await get_tree().create_timer(idle_after_melee / Global.global_time_scale).timeout


# ===================================================================
#                     PHASE 4 – BACKSTEP
# ===================================================================
func _phase_backstep() -> void:
	if dead:
		return

	# Move away from player (backwards)
	var step_dir = -dir.x
	if step_dir == 0.0:
		step_dir = -1.0

	var total_time = backstep_time
	var moved = 0.0
	var speed = backstep_distance / max(total_time, 0.01)

	# Optional: use "walk" going backwards or just "idle"
	if animation_player.has_animation("walk"):
		current_animation = "walk"
		animation_player.play("walk")

	while moved < backstep_distance and not dead:
		var dt = get_process_delta_time()
		var step = speed * dt
		moved += step
		velocity.x = step_dir * speed
		await get_tree().process_frame

	# Stop after backstep
	velocity.x = 0.0


# ===================================================================
#                     PHASE 5 – LASER ATTACK (BEAM)
# ===================================================================

func _phase_laser() -> void:
	if dead:
		return

	velocity.x = 0.0

	# Decide direction: face the player
	var dir_sign: int = 1
	if player and is_instance_valid(player):
		var dx := player.global_position.x - global_position.x
		if dx < 0.0:
			dir_sign = -1
		else:
			dir_sign = 1

	dir.x = dir_sign
	sprite.flip_h = (dir_sign < 0.0)
	laser_origin_marker.position.x = 20*dir_sign

	enemy_damage = laser_damage

	# Position the beam at the marker (this is the origin)
	if laser_beam and laser_origin_marker:
		laser_beam.global_position = laser_origin_marker.global_position

	# Play laser animation
	if animation_player.has_animation("laser"):
		current_animation = "laser"
		animation_player.play("laser")
	#elif animation_player.has_animation("attack"):
	#	current_animation = "attack"
	#	if sprite.flip_h:
	#		sprite.position = Vector2(-20, -53)
	#	else:
	#		sprite.position = Vector2(20, -53)
	#	animation_player.play("attack")

	# Short windup
	await get_tree().create_timer(0.3 / Global.global_time_scale).timeout

	# === FIRE BEAM ===
	if laser_beam:
		laser_beam.damage = laser_damage
		laser_beam.fire(dir_sign)  # stretches 1000px in this direction

	# Beam stays active
	await get_tree().create_timer(laser_duration / Global.global_time_scale).timeout

	if laser_beam:
		laser_beam.stop()

	# Small tail / recovery
	await get_tree().create_timer(0.3 / Global.global_time_scale).timeout

# ===================================================================
#                     PHASE 6 – TIRED / VULNERABLE
# ===================================================================
func _phase_tired() -> void:
	if dead:
		return

	velocity.x = 0.0

	if animation_player.has_animation("tired"):
		current_animation = "tired"
		animation_player.play("tired")
	elif animation_player.has_animation("idle"):
		current_animation = "idle"
		animation_player.play("idle")

	await get_tree().create_timer(tired_duration / Global.global_time_scale).timeout

func take_damage(dmg: int) -> void:
	# Ignore if already dead
	if dead:
		return

	# Let BaseEnemy handle HP, flags, hit_stun_timer, taking_damage, etc.
	super.take_damage(dmg)

	print("ReplicaFini took damage: ", dmg, " -> HP: ", health, "/", health_max)

	# If she died, handle boss death explicitly
	if health <= 0:
		_handle_boss_death()
		
func _handle_boss_death() -> void:
	if dead: # super.take_damage already set this
		print("ReplicaFini: death sequence start")
	
	# Stop pattern + movement + laser
	pattern_running = false
	velocity = Vector2.ZERO
	if laser_beam:
		laser_beam.stop()

	# Play death animation if available
	if animation_player and animation_player.has_animation("death"):
		current_animation = "death"
		animation_player.play("death")
		await animation_player.animation_finished

	queue_free()

func _jump_to_best_marker() -> void:
	if player == null or not is_instance_valid(player) or jump_markers.is_empty():
		print("ReplicaFini: _jump_to_best_marker aborted: player or markers missing")
		return

	var best_marker: Node2D = null
	var best_score := INF

	for m in jump_markers:
		var dx = abs(m.global_position.x - player.global_position.x)
		var dy := player.global_position.y - m.global_position.y
		var score = dx + abs(dy) * 0.5
		if score < best_score:
			best_score = score
			best_marker = m

	if best_marker:
		print("ReplicaFini: best marker chosen: ", best_marker.name,
			" at ", best_marker.global_position,
			" score=", best_score)
		await _jump_to_position(best_marker.global_position)
		on_platform = true
		print("ReplicaFini: finished jump_to_position, now on_platform=", on_platform)
	else:
		print("ReplicaFini: _jump_to_best_marker found no best_marker somehow")


func _jump_to_position(target: Vector2) -> void:
	print("ReplicaFini: jumping from ", global_position, " to ", target)

	if animation_player and animation_player.has_animation("jump"):
		current_animation = "jump"
		animation_player.play("jump")

	var duration: float = 0.35
	var t: float = 0.0
	var start: Vector2 = global_position

	velocity = Vector2.ZERO

	while t < duration and not dead:
		var dt: float = get_process_delta_time()
		t += dt
		var alpha: float = clampf(t / duration, 0.0, 1.0)
		global_position = start.lerp(target, alpha)
		await get_tree().process_frame

	global_position = target
	velocity = Vector2.ZERO
	print("ReplicaFini: landed at ", global_position)


func _phase_platform_idle_laser_tired() -> void:
	if dead:
		return

	# --- 0) Should we LEAVE platform mode? (player went back to ground) ---
	if player and is_instance_valid(player):
		var ground_y := global_position.y

		# If you have low markers, use them as "ground" reference
		if marker_low_left:
			ground_y = marker_low_left.global_position.y
		elif marker_low_right:
			ground_y = marker_low_right.global_position.y

		# If player is near or below "ground", stop platform mode
		if player.global_position.y > ground_y - 8.0:
			on_platform = false
			print("ReplicaFini: player near ground again, leaving platform mode")
			return

	# --- 1) REPOSITION between upper markers to follow player horizontally ---
	if player and is_instance_valid(player):
		var best_marker = _get_best_upper_marker_for_player()
		if best_marker:
			var dist = best_marker.global_position.distance_to(global_position)
			if dist > 8.0:
				print("ReplicaFini: platform reposition from ",
					global_position, " to ", best_marker.global_position,
					" (dist=", dist, ")")
				await _jump_to_marker(best_marker)

	# --- 2) IDLE on platform ---
	velocity.x = 0.0
	if animation_player.has_animation("idle"):
		current_animation = "idle"
		animation_player.play("idle")
	print("ReplicaFini: platform idle on upper platform at ", global_position)
	await get_tree().create_timer(1.0 / Global.global_time_scale).timeout

	# --- 3) LASER ONLY (no melee in air) ---
	print("ReplicaFini: platform laser at ", global_position)
	await _phase_laser()

	# --- 4) TIRED / VULNERABLE ---
	velocity.x = 0.0
	if animation_player.has_animation("tired"):
		current_animation = "tired"
		animation_player.play("tired")
	elif animation_player.has_animation("idle"):
		current_animation = "idle"
		animation_player.play("idle")

	print("ReplicaFini: platform tired at ", global_position)
	await get_tree().create_timer(3.0 / Global.global_time_scale).timeout

func _jump_to_marker(target: Marker2D, duration: float = 0.4) -> void:
	if target == null:
		print("ReplicaFini: _jump_to_marker called with null target")
		return

	print("ReplicaFini: jumping to marker ", target.name, 
		" from ", global_position, " to ", target.global_position)

	var start_pos: Vector2 = global_position
	var t: float = 0.0

	while t < duration:
		t += get_process_delta_time()
		var alpha = clampf(t / duration, 0.0, 1.0) # clampf to avoid that warning
		global_position = start_pos.lerp(target.global_position, alpha)
		await get_tree().process_frame

	global_position = target.global_position

	# Decide if this is an upper platform marker
	on_upper_platform = (
		target == marker_mid_left  or target == marker_mid_right  or
		target == marker_high_left or target == marker_high_right
	)
	
	on_platform = on_upper_platform  # <<< important
	
	print("ReplicaFini: landed on marker ", target.name,
		" at ", global_position,
		" | on_upper_platform = ", on_upper_platform,
		" | is_on_floor() = ", is_on_floor())

func _get_best_marker_for_player() -> Marker2D:
	if not player or not is_instance_valid(player):
		return null

	var candidates: Array[Marker2D] = []
	if marker_low_left:   candidates.append(marker_low_left)
	if marker_mid_left:   candidates.append(marker_mid_left)
	if marker_high_left:  candidates.append(marker_high_left)
	if marker_low_right:  candidates.append(marker_low_right)
	if marker_mid_right:  candidates.append(marker_mid_right)
	if marker_high_right: candidates.append(marker_high_right)

	if candidates.is_empty():
		print("ReplicaFini: no markers available")
		return null

	var best: Marker2D = candidates[0]
	var best_dist: float = player.global_position.distance_to(best.global_position)

	for m in candidates:
		var d: float = player.global_position.distance_to(m.global_position)
		if d < best_dist:
			best = m
			best_dist = d

	print("ReplicaFini: best marker for player = ", best.name, 
		" at ", best.global_position, " (dist=", best_dist, ")")
	return best

func _get_best_upper_marker_for_player() -> Marker2D:
	if not player or not is_instance_valid(player):
		return null

	var candidates: Array[Marker2D] = []
	if marker_mid_left:   candidates.append(marker_mid_left)
	if marker_mid_right:  candidates.append(marker_mid_right)
	if marker_high_left:  candidates.append(marker_high_left)
	if marker_high_right: candidates.append(marker_high_right)

	if candidates.is_empty():
		print("ReplicaFini: no upper markers available")
		return null

	var best: Marker2D = candidates[0]
	var best_dist: float = player.global_position.distance_to(best.global_position)

	for m in candidates:
		var d: float = player.global_position.distance_to(m.global_position)
		if d < best_dist:
			best = m
			best_dist = d

	print("ReplicaFini: best UPPER marker for player = ", best.name,
		" at ", best.global_position, " (dist=", best_dist, ")")
	return best
