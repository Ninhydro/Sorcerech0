extends BaseEnemy
class_name ReplicaFini

# --- Tunable pattern values ---
@export var walk_speed: float = 40.0              # slow walk toward player
@export var melee_forward_distance: float = 50.0  # how far she slides forward on melee
@export var melee_dash_time: float = 0.18         # seconds of forward motion
@export var backstep_distance: float = 48.0       # how far she moves back before laser
@export var backstep_time: float = 0.22           # seconds of backward motion

@export var walk_phase_duration: float = 1.0      # how long she "hunts" slowly before melee
@export var idle_before_melee: float = 0.5        # stand still before melee
@export var idle_after_melee: float = 1.0         # short pause after melee
@export var tired_duration: float = 3.0           # how long she stays tired

@export var melee_damage: int = 10                # melee slash damage
@export var laser_damage: int = 20                # laser damage
@export var laser_duration: float = 0.8           # how long the beam stays on

@onready var laser_beam = $LaserBeam
@onready var laser_origin_marker: Marker2D = $LaserOrigin

var pattern_running: bool = false
var on_platform: bool = false                     # true after jumping to an upper marker

var marker_low_left: Marker2D
var marker_mid_left: Marker2D
var marker_high_left: Marker2D
var marker_low_right: Marker2D
var marker_mid_right: Marker2D
var marker_high_right: Marker2D

var on_upper_platform: bool = false   # (not strictly needed now, kept for clarity)
var is_hurting: bool = false

var jump_markers: Array[Node2D] = []
@export var jump_check_vertical_diff: float = 48.0  # how much higher the player must be to trigger jump
@export var melee_engage_distance: float = 100.0     # how close she wants to be before melee
@export var max_walk_before_force_melee: float = 2.0  # safety timeout in seconds

var last_attack_dir: int = 1  # +1 or -1, used to keep melee + backstep consistent
var was_taking_damage: bool = false

@export var close_melee_threshold: float = 30.0      # "too close" distance
@export var extra_backstep_multiplier: float = 1.8   # how much farther she retreats if too close

var last_melee_start_dist: float = 0.0               # distance to player when melee started


# ===================================================================
#                      MARKER SETUP / DEBUG
# ===================================================================

func setup_markers(markers: Array) -> void:
	for m in markers:
		if not (m is Marker2D):
			continue

		# Add every marker to jump_markers so _jump_to_best_marker() has candidates
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


# ===================================================================
#                      READY / PROCESS
# ===================================================================

func _ready() -> void:
	collision_layer = 3
	super._ready()

	# Boss-specific behaviour flags
	can_drop_health = true
	use_edge_detection = false
	can_jump_chase = false

	attack_range = 60          # melee reach
	enemy_damage = melee_damage
	attack_type = AttackType.MELEE

	# Disable generic BaseEnemy chase/roam
	is_enemy_chase = false
	is_roaming = false

	# Configure beam damage
	if laser_beam:
		laser_beam.damage = laser_damage

	# Start AI pattern
	_run_pattern()


func _process(delta: float) -> void:
	# Timescale for animations
	if animation_player:
		animation_player.speed_scale = Global.global_time_scale

	# Gravity
	if not is_on_floor():
		velocity.y += gravity * delta

	# Track player
	player = Global.playerBody

	# If dead, just slide with zero x and bail
	if dead:
		velocity.x = 0.0
		move_and_slide()
		return

	# --- HURT PRIORITY (visual / movement) ---
	if taking_damage:
		was_taking_damage = true  # remember we were hurt
		velocity.x = 0.0

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
	# Just *left* hurt state this frame → force idle
	if was_taking_damage:
		was_taking_damage = false
		velocity.x = 0.0
		if animation_player and animation_player.has_animation("idle"):
			if current_animation != "idle":
				current_animation = "idle"
				animation_player.play("idle")
	move_and_slide()


# ===================================================================
#                     HURT / INTERRUPT HELPER
# ===================================================================

func _wait_if_hurt() -> void:

	var was_hurt_local := false

	# Stop pattern progression while taking damage
	while taking_damage and not dead:
		was_hurt_local = true
		velocity.x = 0.0
		await get_tree().process_frame

	# When hurt period ends inside a phase, also snap back to idle
	if was_hurt_local and not dead and animation_player and animation_player.has_animation("idle"):
		if current_animation != "idle":
			current_animation = "idle"
			animation_player.play("idle")


# ===================================================================
#                     MAIN PATTERN LOOP
# ===================================================================

func _run_pattern() -> void:
	if pattern_running:
		return
	pattern_running = true

	while not dead:
		await _wait_if_hurt()
		if dead:
			break

		if on_platform:
			# Upper platform pattern: idle → laser → tired → repeat
			await _phase_platform_idle_laser_tired()
			if dead:
				break
			continue

		# === GROUND PATTERN ===
		await _wait_if_hurt()
		if dead:
			break
		await _phase_idle_walk()
		if dead:
			break

		await _wait_if_hurt()
		if dead:
			break
		await _phase_melee()
		if dead:
			break

		await _wait_if_hurt()
		if dead:
			break
		await _phase_idle_after_melee()
		if dead:
			break

		await _wait_if_hurt()
		if dead:
			break
		await _phase_backstep()
		if dead:
			break

		await _wait_if_hurt()
		if dead:
			break
		await _phase_laser()
		if dead:
			break

		await _wait_if_hurt()
		if dead:
			break
		await _phase_tired()


# ===================================================================
#                    PHASE 1 – IDLE + SLOW WALK
# ===================================================================

func _phase_idle_walk() -> void:
	var elapsed: float = 0.0

	# We are in ground pattern now
	on_platform = false

	while not dead:
		if taking_damage:
			await _wait_if_hurt()
			return

		# Ground → platform check
		if is_on_floor() and player and is_instance_valid(player) and not jump_markers.is_empty():
			var dy := player.global_position.y - global_position.y
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
			var dx = player.global_position.x - global_position.x
			var dist_x = abs(dx)

			# Face player
			if dx != 0.0:
				dir.x = sign(dx)
				sprite.flip_h = (dir.x < 0.0)

			# If close enough, stop walking and go to melee phase
			if dist_x <= melee_engage_distance:
				# Remember how far we were when we decided to melee
				last_melee_start_dist = dist_x

				velocity.x = 0.0
				if animation_player.has_animation("idle"):
					if current_animation != "idle":
						current_animation = "idle"
						animation_player.play("idle")
				break

			# Otherwise, walk toward player
			velocity.x = dir.x * walk_speed
			if current_animation != "walk" and animation_player.has_animation("walk"):
				current_animation = "walk"
				animation_player.play("walk")
		else:
			# No player reference – idle
			velocity.x = 0.0
			if current_animation != "idle" and animation_player.has_animation("idle"):
				current_animation = "idle"
				animation_player.play("idle")

		await get_tree().process_frame
		elapsed += get_process_delta_time()

		# Just in case player runs away forever: after some time, force melee anyway
		#if elapsed >= max_walk_before_force_melee:
		#	break


# ===================================================================
#                    PHASE 2 – MELEE ATTACK (SLASH)
# ===================================================================

func _phase_melee() -> void:
	if dead:
		return

	await _wait_if_hurt()
	if dead:
		return

	# Face the player first and lock direction
	if player and is_instance_valid(player):
		var dx = player.global_position.x - global_position.x
		if dx != 0.0:
			last_attack_dir = sign(dx)   # LOCKED for melee + backstep
			dir.x = last_attack_dir
			sprite.flip_h = (dir.x < 0.0)

	# Short idle before attack
	velocity.x = 0.0
	if animation_player.has_animation("idle"):
		current_animation = "idle"
		animation_player.play("idle")
	await get_tree().create_timer(idle_before_melee / Global.global_time_scale).timeout

	if taking_damage:
		await _wait_if_hurt()
		return

	# Play attack animation and slide forward a bit
	var total_time = melee_dash_time
	var moved = 0.0
	var dash_speed = melee_forward_distance / max(total_time, 0.01)

	if animation_player.has_animation("attack"):
		print("PLAY ATTACK")
		current_animation = "attack"
		if sprite.flip_h == true:
			sprite.position = Vector2(-20, -53)
		else:
			sprite.position = Vector2(20, -53)
		animation_player.play("attack")

	while moved < melee_forward_distance and not dead:
		if taking_damage:
			await _wait_if_hurt()
			return

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

	await _wait_if_hurt()
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

	await _wait_if_hurt()
	if dead:
		return

	# Decide how far to backstep:
	# - normal backstep if melee started at a "nice" distance
	# - longer backstep if she ended up too close to the player
	var use_backstep_distance: float = backstep_distance
	if last_melee_start_dist > 0.0 and last_melee_start_dist <= close_melee_threshold:
		# She started melee very close to the player → retreat more before laser
		use_backstep_distance = backstep_distance * extra_backstep_multiplier

	# Move away from where the last melee went
	var step_dir = -last_attack_dir
	if step_dir == 0:
		step_dir = -1

	var total_time = backstep_time
	var moved = 0.0
	var speed = use_backstep_distance / max(total_time, 0.01)

	# Face same way as melee (optional, feels consistent)
	dir.x = last_attack_dir
	sprite.flip_h = (dir.x < 0.0)

	if animation_player.has_animation("walk"):
		current_animation = "walk"
		animation_player.play("walk")

	while moved < use_backstep_distance and not dead:
		if taking_damage:
			await _wait_if_hurt()
			return

		var dt = get_process_delta_time()
		var step = speed * dt
		moved += step
		velocity.x = step_dir * speed
		await get_tree().process_frame

	velocity.x = 0.0


# ===================================================================
#                     PHASE 5 – LASER ATTACK (BEAM)
# ===================================================================

func _phase_laser() -> void:
	if dead:
		return

	await _wait_if_hurt()
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
	laser_origin_marker.position.x = 20 * dir_sign

	enemy_damage = laser_damage

	# Position the beam at the marker (this is the origin)
	if laser_beam and laser_origin_marker:
		laser_beam.global_position = laser_origin_marker.global_position

	# Play laser animation
	if animation_player.has_animation("laser"):
		current_animation = "laser"
		animation_player.play("laser")

	# Short windup
	await get_tree().create_timer(0.3 / Global.global_time_scale).timeout

	if taking_damage:
		await _wait_if_hurt()
		return

	# === FIRE BEAM ===
	if laser_beam:
		laser_beam.damage = laser_damage
		laser_beam.fire(dir_sign)  # stretches beam in this direction

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

	await _wait_if_hurt()
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


# ===================================================================
#                     DAMAGE / DEATH
# ===================================================================

func take_damage(dmg: int) -> void:
	if dead:
		return

	super.take_damage(dmg)
	print("ReplicaFini took damage: ", dmg, " -> HP: ", health, "/", health_max)

	if health <= 0:
		_handle_boss_death()


func _handle_boss_death() -> void:
	if dead:
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


# ===================================================================
#                     JUMP HELPERS
# ===================================================================

func _jump_to_best_marker() -> void:
	if player == null or not is_instance_valid(player) or jump_markers.is_empty():
		print("ReplicaFini: _jump_to_best_marker aborted: player or markers missing")
		return

	var best_marker: Marker2D = null
	var best_score := INF

	for m in jump_markers:
		if not (m is Marker2D):
			continue
		
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
		await _jump_to_marker(best_marker)
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
		if taking_damage:
			await _wait_if_hurt()
			return

		var dt: float = get_process_delta_time()
		t += dt
		var alpha: float = clampf(t / duration, 0.0, 1.0)
		global_position = start.lerp(target, alpha)
		await get_tree().process_frame

	global_position = target
	velocity = Vector2.ZERO
	print("ReplicaFini: landed at ", global_position)


func _jump_to_marker(target: Marker2D) -> void:
	if not target:
		return

	var start_pos := global_position
	var end_pos := target.global_position
	var duration := 0.4
	var t := 0.0
	collision_layer = 0
	if animation_player and animation_player.has_animation("jump"):
		current_animation = "jump"
		animation_player.play("jump")

	while t < duration and not dead:
		if taking_damage:
			await _wait_if_hurt()
			return

		t += get_physics_process_delta_time()
		var alpha = clamp(t / duration, 0.0, 1.0)
		global_position = start_pos.lerp(end_pos, alpha)
		await get_tree().physics_frame
	
	global_position = end_pos
	velocity = Vector2.ZERO
	collision_layer = 3
	# Decide if this is a platform position or ground
	#var ground_y := global_position.y
	#if marker_low_left:
	#	ground_y = marker_low_left.global_position.y
	#elif marker_low_right:
	#	ground_y = marker_low_right.global_position.y

	# If we are significantly above the "low" markers, we are on platform
	#on_platform = global_position.y < ground_y - 50.0
	on_platform = _is_platform_marker(target)
	print("ReplicaFini: landed on marker ", target.name,
		" at ", global_position,
	#	" | ground_y=", ground_y,
		" | on_platform=", on_platform)

func _is_platform_marker(marker: Marker2D) -> bool:
	if marker == null:
		return false

	# Treat mid/high as "upper platform"
	return marker == marker_mid_left \
		or marker == marker_mid_right \
		or marker == marker_high_left \
		or marker == marker_high_right

# ===================================================================
#                     PLATFORM HELPERS
# ===================================================================

func _phase_platform_idle_laser_tired() -> void:
	if dead:
		return

	await _wait_if_hurt()
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
		if player.global_position.y > ground_y - 70.0:
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

	if taking_damage:
		await _wait_if_hurt()
		return

	# --- 2) IDLE on platform ---
	velocity.x = 0.0
	if animation_player.has_animation("idle"):
		current_animation = "idle"
		animation_player.play("idle")
	print("ReplicaFini: platform idle on upper platform at ", global_position)
	await get_tree().create_timer(1.0 / Global.global_time_scale).timeout

	if taking_damage:
		await _wait_if_hurt()
		return

	# --- 3) LASER ONLY (no melee in air) ---
	print("ReplicaFini: platform laser at ", global_position)
	await _phase_laser()

	if taking_damage:
		await _wait_if_hurt()
		return

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


func _get_best_marker_for_player() -> Marker2D:
	# (Currently unused helper – closest of all markers)
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
