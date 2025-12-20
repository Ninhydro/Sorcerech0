extends BaseEnemy
class_name SterlingEnemy

# =====================================================
# CONFIG
# =====================================================
@export var move_speed := 50.0
@export var melee_range := 48.0
@export var melee_damage := 12

@export var laser_damage := 18
@export var laser_duration := 0.3
@export var laser_windup := 0.6
@export var laser_recovery := 1.0  #stun

@export var melee_tired_time := 2.0 #stun
@export var laser_idle_time := 1.2 
@export var laser_chance := 0.3

@export var jump_height_threshold := 48.0

# =====================================================
# NODES
# =====================================================
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var laser_beam = $LaserBeam
@onready var laser_origin: Marker2D = $LaserOrigin
@onready var spritefini = $RFini

# =====================================================
# STATE
# =====================================================
var attack_running := false
var tired := false
var was_taking_damage := false
var jump_markers: Array[Marker2D] = []

var is_lunging := false
var lunge_direction := 1.0
var lunge_speed := 100.0

var ai_active := true  # Add this to control AI loop
var invulnerable_during_attack := false  # NEW: Make boss invulnerable during attacks

var _consecutive_laser_count := 0
var _max_consecutive_lasers := 1  # Maximum 2 laser attacks in a row

signal died
signal melee_attack_triggered(damage: int)

# =====================================================
# READY
# =====================================================
func _ready() -> void:
	super._ready()
	print("Global.replica_fini_dead = ",Global.replica_fini_dead)
	if Global.replica_fini_dead == true:
		laser_chance = 0.0
	elif Global.replica_fini_dead == false:
		laser_chance = 0.3
		
	# Get player reference immediately
	player = Global.playerBody
	
	# Disable BaseEnemy systems
	is_enemy_chase = false
	is_roaming = false
	use_edge_detection = false
	can_jump_chase = false

	attack_type = AttackType.MELEE
	attack_range = melee_range
	enemy_damage = melee_damage

	_collect_jump_markers()
	
	# Start AI after a short delay to ensure everything is ready
	call_deferred("_start_ai")

# =====================================================
# PROCESS (single movement authority)
# =====================================================
func _process(delta: float) -> void:
	if not ai_active:
		return
		
	if anim:
		anim.speed_scale = Global.global_time_scale

	if not is_on_floor():
		velocity.y += gravity * delta

	if taking_damage:
		was_taking_damage = true
		velocity.x = 0.0
		print("taking damge & health: ", health)
		if anim.has_animation("hurt"):
			anim.play("hurt")
		else:
			anim.play("idle")

		move_and_slide()
		return

	if was_taking_damage:
		was_taking_damage = false
		velocity = Vector2.ZERO
		anim.play("idle")

	move_and_slide()

func take_damage(amount: int) -> void:
	if dead or invulnerable_during_attack:
		print("Sterling: Ignoring damage - dead:", dead, " invulnerable:", invulnerable_during_attack)
		return
	
	health -= amount
	print("Sterling health: ", health)
	# CRITICAL: Set taking_damage to true to trigger hurt animation
	taking_damage = true
	
	# Stop all movement when taking damage
	velocity = Vector2.ZERO
	attack_running = false
	tired = false
	invulnerable_during_attack = false  # Reset invulnerability if hit

	# Play hurt animation if available
	if anim.has_animation("hurt"):
		print("Sterling: Playing hurt animation")
		anim.play("hurt")
		# Wait for hurt animation to finish (or a minimum time)
		var hurt_duration = anim.current_animation_length if anim.current_animation else 0.3
		await get_tree().create_timer(hurt_duration / Global.global_time_scale).timeout
	else:
		print("Sterling: No hurt animation, waiting briefly")
		await get_tree().create_timer(0.3 / Global.global_time_scale).timeout
	
	# Reset taking_damage after hurt animation
	taking_damage = false
	
	if health <= 0:
		_die()
		return 

func _die() -> void:
	dead = true
	ai_active = false
	velocity = Vector2.ZERO
	
	# Play death animation
	if anim.has_animation("die"):
		anim.play("die")
		await anim.animation_finished
	
	# Emit died signal for Gigaster to detect
	emit_signal("died")
	
	# Remove from scene
	queue_free()
	
		
# =====================================================
# MAIN AI LOOP
# =====================================================
func _start_ai() -> void:
	ai_active = true
	print("Sterling AI started")
	_run_ai()

func _run_ai() -> void:
	print("Sterling: AI loop starting - Position: ", global_position, " Player: ", player != null)
	
	var stuck_check_counter = 0
	var last_position = global_position
	while not dead and ai_active:
		await get_tree().process_frame

		# Stuck detection
		#if global_position.distance_to(last_position) < 5.0:
		#	stuck_check_counter += 1
		#	if stuck_check_counter > 100:  # Stuck for 100 frames
		#		print("Sterling: Detected as stuck, attempting to reset")
		#		velocity = Vector2.ZERO
		#		attack_running = false
		#		tired = false
		#		await get_tree().create_timer(0.5).timeout
		#		stuck_check_counter = 0
		#else:
		#	stuck_check_counter = 0
		#	last_position = global_position
			
		if dead:  # Check if dead here too
			break

		if taking_damage or attack_running or tired or invulnerable_during_attack:
			continue

		# Get player reference
		if not player or not is_instance_valid(player):
			player = Global.playerBody
			if not player:
				await get_tree().create_timer(0.1).timeout
				continue
		
		# Calculate distances
		var horizontal_dist = abs(player.global_position.x - global_position.x)
		var vertical_dist = player.global_position.y - global_position.y

		# Get player reference each frame
		#if not player or not is_instance_valid(player):
		#	player = Global.playerBody
		#	if not player:
				#print("Sterling: No player found, waiting...")
		#		await get_tree().create_timer(0.1).timeout
		#		continue

		# Check if player is valid and in scene
		#if not is_instance_valid(player) or player.is_queued_for_deletion():
			#print("Sterling: Player invalid, waiting...")
		#	await get_tree().create_timer(0.1).timeout
		#	continue
		#var distance_to_player = abs(player.global_position.x - global_position.x)
		#var height_diff = player.global_position.y - global_position.y
		
		#print("Sterling: Player at ", player.global_position, " Sterling at ", global_position)

		if _should_jump_to_platform():
			print("Sterling: Need platform movement")
			await _handle_platform_movement()
			await get_tree().create_timer(0.3).timeout
			continue

		# Normal horizontal chasing/attacking
		if horizontal_dist > melee_range * 1.5:
			_chase_player()
			await get_tree().create_timer(0.15).timeout
			continue

		if _in_melee_range():
			print("Sterling: In melee range, choosing attack")
			await _choose_attack()
			await get_tree().create_timer(0.1).timeout
		else:
			_chase_player()
			await get_tree().create_timer(0.08).timeout

	print("Sterling AI stopped")
# =====================================================
# CHASE
# =====================================================
func _chase_player() -> void:
	if not player or not is_instance_valid(player):
		print("Sterling: _chase_player - No valid player")
		return

	var dx := player.global_position.x - global_position.x
	var chase_dir = sign(dx) if dx != 0 else dir.x
	
	dir.x = chase_dir
	
	# Flip both sprites based on chase direction
	if chase_dir != 0:
		# Always use positive scale for flipping (not negative)
		var abs_sprite_scale = Vector2(abs(sprite.scale.x), abs(sprite.scale.y))
		sprite.scale.x = abs_sprite_scale.x * chase_dir
		sprite.flip_h = false  # Use scale, not flip_h

		
	velocity.x = dir.x * move_speed
	
	# Debug movement
	#print("Sterling: Chasing player - dx:", dx, " dir.x:", dir.x, " velocity.x:", velocity.x)
	
	# Only play chase animation if we have velocity
	if abs(velocity.x) > 0:
		if anim.has_animation("chase"):
			anim.play("chase")
	else:
		if anim.has_animation("idle"):
			anim.play("idle")

# =====================================================
# ATTACK DECISION
# =====================================================
func _choose_attack() -> void:
	attack_running = true
	velocity = Vector2.ZERO

	# Check if we've done too many lasers in a row
	if _consecutive_laser_count >= _max_consecutive_lasers:
		print("Sterling: Too many consecutive lasers, forcing melee attack")
		await _attack_melee()
		_consecutive_laser_count = 0  # Reset counter
	elif randf() < laser_chance:
		print("Sterling: Choosing laser attack")
		_consecutive_laser_count += 1  # Increment counter
		await _attack_laser()
	else:
		print("Sterling: Choosing melee attack")
		_consecutive_laser_count = 0  # Reset counter
		await _attack_melee()

	attack_running = false

# =====================================================
# MELEE
# =====================================================
func _attack_melee() -> void:
	print("Sterling: Starting melee attack")
	#anim.play("attack_melee")
	
	# Add forward lunge movement when attacking
	invulnerable_during_attack = true
	attack_running = true
	anim.play("attack_melee")
	#var lunge_speed = 200.0
	var lunge_duration = 0.5
	
	# Determine direction based on sprite flip or player position
	var lunge_direction: float
	if player and is_instance_valid(player):
		# Lunge toward the player
		lunge_direction = sign(player.global_position.x - global_position.x)
		if lunge_direction == 0:
			lunge_direction = dir.x if dir.x != 0 else 1
	else:
		# Fallback to current facing direction
		lunge_direction = -1 if sprite.flip_h else 1
	
	if lunge_direction != 0:
		var abs_sprite_scale = Vector2(abs(sprite.scale.x), abs(sprite.scale.y))
		sprite.scale.x = abs_sprite_scale.x * lunge_direction
		sprite.flip_h = false

		
	# Apply the lunge
	velocity.x = lunge_direction * lunge_speed
	
	# Wait for lunge duration, but stop early if animation finishes
	var timer = get_tree().create_timer(lunge_duration / Global.global_time_scale)
	await timer.timeout or anim.animation_finished
	
	# Stop the lunge movement
	velocity.x = 0
	
	await anim.animation_finished

	if _in_melee_range():
		print("Sterling: In range, attempting to deal damage")
		# Try direct damage instead of deal_damage()
		#if player and is_instance_valid(player) and player.has_method("take_damage"):
		#	player.take_damage(melee_damage)
		#	print("Sterling: Dealt ", melee_damage, " damage to player")
	else:
		print("Sterling: Not in range after attack")

	tired = true
	print("Sterling: Setting tired to true")
	invulnerable_during_attack = false  # Reset invulnerability
	attack_running = false
	anim.play("idle")
	await get_tree().create_timer(melee_tired_time / Global.global_time_scale).timeout

	tired = false
	print("Sterling: Setting tired to false")
	anim.play("idle")

# Call this from animation event
func _on_melee_attack_frame() -> void:
	print("Sterling: Melee attack frame triggered")
	
	if not player or not is_instance_valid(player):
		print("Sterling: No valid player for melee attack")
		return
	
	# Check if player is in range
	if _in_melee_range():
		print("Sterling: Player in range, emitting damage signal")
		emit_signal("melee_attack_triggered", melee_damage)
		
		# Also apply damage directly (backup)
		if player.has_method("take_damage"):
			player.take_damage(melee_damage)
			print("Sterling: Direct damage applied: ", melee_damage)
	else:
		print("Sterling: Player not in range for melee")
		
# =====================================================
# LASER
# =====================================================
func _attack_laser() -> void:
	await _wait_if_hurt()
	if dead:
		return

	invulnerable_during_attack = true
	attack_running = true
	velocity = Vector2.ZERO

	if not player or not is_instance_valid(player):
		invulnerable_during_attack = false
		attack_running = false
		return

	var dir_sign = sign(player.global_position.x - global_position.x)
	if dir_sign == 0:
		dir_sign = 1

	var absolute_sprite_scale = Vector2(abs(sprite.scale.x), abs(sprite.scale.y))
	var absolute_spritefini_scale = Vector2(abs(spritefini.scale.x), abs(spritefini.scale.y))
	
	# Flip sprite for laser attack
	sprite.scale.x = absolute_sprite_scale.x * dir_sign
	spritefini.scale.x = absolute_spritefini_scale.x * dir_sign
	sprite.flip_h = false
	spritefini.flip_h = false
	
	# Adjust laser origin position based on direction
	laser_origin.position.x = 20 * dir_sign
	laser_beam.global_position = laser_origin.global_position
	
	# Flip laser origin too
	laser_origin.scale.x = dir_sign
	
	# Set laser direction if the beam has that method
	if laser_beam.has_method("set_direction"):
		laser_beam.set_direction(dir_sign)
	

	
	anim.play("laser")
	await get_tree().create_timer(laser_windup / Global.global_time_scale).timeout

	if taking_damage:
		laser_beam.stop()
		# Restore original sprite scale if interrupted
		sprite.scale = absolute_sprite_scale
		sprite.scale = absolute_sprite_scale
		invulnerable_during_attack = false
		attack_running = false
		return

	laser_beam.damage = laser_damage
	laser_beam.fire(dir_sign)

	await get_tree().create_timer(laser_duration / Global.global_time_scale).timeout
	laser_beam.stop()
	
	await get_tree().create_timer(laser_recovery / Global.global_time_scale).timeout
	
	# IMPORTANT: Restore original sprite scale after laser attack
	sprite.scale = absolute_sprite_scale
	sprite.flip_h = false
	
	# Also reset laser origin
	laser_origin.scale.x = 1
	
	print("Sterling: Laser attack finished, sprite scale restored to: ", sprite.scale)
	invulnerable_during_attack = false
	attack_running = false
	
	anim.play("idle")
	await get_tree().create_timer(laser_recovery / Global.global_time_scale).timeout
# =====================================================
# RANGE CHECK
# =====================================================
func _in_melee_range() -> bool:
	return player and is_instance_valid(player) and abs(player.global_position.x - global_position.x) <= melee_range

# =====================================================
# PLATFORM JUMP
# =====================================================
func _should_jump_to_platform() -> bool:
	if not player or not is_instance_valid(player) or jump_markers.is_empty():
		return false
	
	# Check vertical distance to player
	var height_difference = player.global_position.y - global_position.y
	
	# Only consider platform movement if player is SIGNIFICANTLY above or below
	if abs(height_difference) > jump_height_threshold:
		return true
	
	return false
	
func _collect_jump_markers() -> void:
	jump_markers.clear()
	for m in get_tree().get_nodes_in_group("SterlingJumpMarker"):
		if m is Marker2D:
			jump_markers.append(m)
	print("Sterling: Collected ", jump_markers.size(), " jump markers")

func _jump_to_best_marker() -> void:
	if not player or not is_instance_valid(player):
		return

	var best: Marker2D = null
	var best_score := INF

	for m in jump_markers:
		# Calculate a score based on both vertical and horizontal distance to player
		var vertical_dist_to_player = abs(m.global_position.y - player.global_position.y)
		var horizontal_dist_to_player = abs(m.global_position.x - player.global_position.x)
		var dist_from_stirling = m.global_position.distance_to(global_position)
		
		# Score: prioritize markers close to player's height, then horizontal distance
		var score = vertical_dist_to_player * 2.0 + horizontal_dist_to_player * 1.0
		
		# Don't jump to markers that are too far
		if dist_from_stirling < 500:  # Max jump distance
			if score < best_score:
				best = m
				best_score = score

	if best:
		print("Sterling: Jumping to best marker at ", best.global_position, 
			  " (player at ", player.global_position, ")")
		await _jump_to_marker(best)
	else:
		print("Sterling: No suitable marker found within range")

func _jump_to_marker(marker: Marker2D) -> void:
	# This is now just a wrapper for the old jump animation system
	# You can keep this if you want jump animations, or remove it
	print("Sterling: Starting jump to marker at ", marker.global_position)
	
	# For upward movement with teleport, we don't need the jump animation
	# Just use _move_to_marker() instead
	await _smooth_move_to_marker(marker, true)
# =====================================================
# HURT HELPER
# =====================================================
func _wait_if_hurt() -> void:
	if invulnerable_during_attack:
		return
	while taking_damage and not dead:
		velocity = Vector2.ZERO
		await get_tree().process_frame

# =====================================================
# CLEANUP
# =====================================================
func _exit_tree() -> void:
	ai_active = false

# =====================================================
# LOWER PLATFORM CHASE
# =====================================================
func _should_chase_to_lower_platform() -> bool:
	if not player or not is_instance_valid(player) or jump_markers.is_empty():
		return false
	
	# Check vertical distance to player
	var height_difference = player.global_position.y - global_position.y
	
	# If player is SIGNIFICANTLY BELOW Sterling
	if height_difference > jump_height_threshold:  # Player is BELOW Sterling
		# Find the best marker that's CLOSER TO PLAYER'S LEVEL (below)
		var best_marker: Marker2D = null
		var best_score = INF
		
		for marker in jump_markers:
			# Check if this marker is BELOW current position (helps reach lower player)
			var marker_height_diff = marker.global_position.y - global_position.y
			
			if marker_height_diff > 0:  # Marker is BELOW current position
				# Calculate horizontal distance to player
				var horizontal_dist = abs(marker.global_position.x - player.global_position.x)
				var vertical_dist = abs(marker.global_position.y - player.global_position.y)
				
				# Score: prioritize markers close to player vertically
				var score = vertical_dist * 2.0 + horizontal_dist * 1.0
				
				if score < best_score:
					best_marker = marker
					best_score = score
		
		if best_marker:
			print("Sterling: Player is BELOW ({height_difference:.1f}px), will chase to marker at {best_marker.global_position}")
			return true
	
	return false

func _chase_to_lower_marker() -> void:
	if not player or not is_instance_valid(player):
		return
	
	var best_marker: Marker2D = null
	var best_score = INF
	var height_difference = player.global_position.y - global_position.y
	
	# Find the best lower marker
	for marker in jump_markers:
		var marker_height_diff = marker.global_position.y - global_position.y
		
		if marker_height_diff > 0:  # Only consider markers BELOW current position
			var horizontal_dist = abs(marker.global_position.x - player.global_position.x)
			var vertical_dist = abs(marker.global_position.y - player.global_position.y)
			
			var score = vertical_dist * 2.0 + horizontal_dist * 1.0
			
			if score < best_score:
				best_marker = marker
				best_score = score
	
	if best_marker:
		print("Sterling: Chasing to lower marker at {best_marker.global_position}")
		await _smooth_move_to_marker(best_marker, false)  # false = chase, not teleport

func _smooth_move_to_marker(marker: Marker2D, is_upward: bool) -> void:
	print("Sterling: Smooth moving to marker at {marker.global_position} (upward: {is_upward})")
	
	# Phase 1: Chase horizontally to get under/over the marker
	var horizontal_target = marker.global_position.x
	var reached_horizontally = false
	var horizontal_timeout = 2.0  # Max time to reach horizontally
	var horizontal_start_time = Time.get_ticks_msec() / 1000.0
	
	print("Sterling: Phase 1 - Moving horizontally to X: {horizontal_target}")
	
	while not reached_horizontally and not dead and not taking_damage:
		var current_time = Time.get_ticks_msec() / 1000.0
		if current_time - horizontal_start_time > horizontal_timeout:
			print("Sterling: Horizontal movement timeout")
			break
		
		var dx = horizontal_target - global_position.x
		var horizontal_dir = sign(dx) if dx != 0 else dir.x
		
		# Update direction and flip sprite
		if horizontal_dir != 0:
			dir.x = horizontal_dir
			var abs_sprite_scale = Vector2(abs(sprite.scale.x), abs(sprite.scale.y))
			sprite.scale.x = abs_sprite_scale.x * horizontal_dir
			sprite.flip_h = false
		
		# Move horizontally
		velocity.x = horizontal_dir * move_speed
		
		# Apply gravity if we're on ground
		if not is_on_floor():
			velocity.y += gravity * get_process_delta_time()
		
		# Play chase animation
		if anim.has_animation("chase"):
			anim.play("chase")
		
		await get_tree().process_frame
		
		# Check if we've reached the horizontal position
		if abs(dx) < 5.0:
			reached_horizontally = true
			velocity.x = 0
			print("Sterling: Reached horizontal position")
	
	# Phase 2: Handle vertical movement
	if is_upward:
		# For upward movement, we can teleport or use jump animation
		print("Sterling: Phase 2 - Teleporting upward")
		
		# Optional: Play jump animation if available
		if anim.has_animation("jump"):
			anim.play("jump")
			await get_tree().create_timer(0.2).timeout
		
		# Teleport to marker position
		global_position = marker.global_position
		print("Sterling: Teleported to marker position")
	else:
		# For downward movement, just walk off the edge and let gravity do its thing
		print("Sterling: Phase 2 - Walking to edge for downward movement")
		
		# Move a bit past the marker to ensure we go off the edge
		var walk_past_distance = 20.0
		var edge_target_x = marker.global_position.x + (walk_past_distance if dir.x > 0 else -walk_past_distance)
		
		# Walk to the edge
		while abs(global_position.x - edge_target_x) > 5.0 and not dead and not taking_damage:
			var edge_dx = edge_target_x - global_position.x
			var edge_dir = sign(edge_dx)
			
			velocity.x = edge_dir * move_speed * 0.5  # Slower when approaching edge
			
			# Apply gravity
			if not is_on_floor():
				velocity.y += gravity * get_process_delta_time()
			
			if anim.has_animation("chase"):
				anim.play("chase")
			
			await get_tree().process_frame
		
		# Let gravity pull us down
		print("Sterling: Falling down to marker level")
		var fall_timeout = 3.0
		var fall_start_time = Time.get_ticks_msec() / 1000.0
		
		while (global_position.y < marker.global_position.y - 10) and not dead and not taking_damage:
			var fall_current_time = Time.get_ticks_msec() / 1000.0  # Fixed: declared here
			if fall_current_time - fall_start_time > fall_timeout:
				print("Sterling: Fall timeout, snapping to marker")
				break
			
			# Apply gravity
			velocity.y += gravity * get_process_delta_time() * 2.0  # Faster falling
			
			# Small horizontal movement to stay aligned
			var final_dx = marker.global_position.x - global_position.x
			if abs(final_dx) > 10.0:
				var final_dir = sign(final_dx)
				velocity.x = final_dir * move_speed * 0.3
			else:
				velocity.x = 0
			
			await get_tree().process_frame
		
		# Snap to final position
		global_position = marker.global_position
		velocity = Vector2.ZERO
		print("Sterling: Reached marker position")
	
	# Reset and idle
	velocity = Vector2.ZERO
	if anim.has_animation("idle"):
		anim.play("idle")
	
	print("Sterling: Successfully reached marker at {global_position}")
	
func _handle_platform_movement() -> void:
	if not player or not is_instance_valid(player) or jump_markers.is_empty():
		return
	
	var height_difference = player.global_position.y - global_position.y
	
	# Find the best marker for current situation
	var best_marker: Marker2D = null
	var best_score = INF
	
	for marker in jump_markers:
		# Calculate a score based on position relative to player
		var marker_height_diff = marker.global_position.y - global_position.y
		var horizontal_dist_to_marker = abs(marker.global_position.x - global_position.x)
		var vertical_dist_to_player = abs(marker.global_position.y - player.global_position.y)
		
		# Different scoring based on whether we're going up or down
		var score: float
		
		if height_difference < 0:  # Player is ABOVE
			# For upward movement, prioritize markers that are above and close to player
			if marker_height_diff < 0:  # Marker is above current position
				score = vertical_dist_to_player * 2.0 + horizontal_dist_to_marker * 1.0
			else:
				score = INF  # Skip markers below for upward movement
		else:  # Player is BELOW
			# For downward movement, prioritize markers that are below and close to player
			if marker_height_diff > 0:  # Marker is below current position
				score = vertical_dist_to_player * 2.0 + horizontal_dist_to_marker * 1.0
			else:
				score = INF  # Skip markers above for downward movement
		
		# Also consider distance from current position
		var dist_from_current = marker.global_position.distance_to(global_position)
		if dist_from_current < 600:  # Reasonable movement range
			if score < best_score:
				best_marker = marker
				best_score = score
	
	if best_marker:
		print("Sterling: Player is {'ABOVE' if height_difference < 0 else 'BELOW'} ({height_difference:.1f}px)")
		print("Sterling: Moving to marker at {best_marker.global_position}")
		await _smooth_move_to_marker(best_marker, height_difference < 0)
		
func _debug_state() -> void:
	print("=== Sterling Debug ===")
	print("Position: ", global_position)
	print("Player valid: ", player != null and is_instance_valid(player))
	if player and is_instance_valid(player):
		print("Player position: ", player.global_position)
		print("Distance to player: ", abs(player.global_position.x - global_position.x))
	print("Melee range: ", melee_range)
	print("In melee range: ", _in_melee_range())
	print("tired: ", tired)
	print("attack_running: ", attack_running)
	print("taking_damage: ", taking_damage)
	print("velocity: ", velocity)
	print("Current animation: ", anim.current_animation if anim else "No anim")
	print("=====================")
	
func _debug_platform_logic() -> void:
	if not player or not is_instance_valid(player):
		return
	
	var height_difference = player.global_position.y - global_position.y
	var horizontal_dist = abs(player.global_position.x - global_position.x)
	
	print("=== Platform Logic Debug ===")
	print("Sterling Y: {global_position.y:.1f}, Player Y: {player.global_position.y:.1f}")
	print("Vertical diff: {height_difference:.1f} (positive = player below, negative = player above)")
	print("Horizontal dist: {horizontal_dist:.1f}")
	print("jump_height_threshold: {jump_height_threshold}")
	print("Should jump up: {_should_jump_to_platform()}")
	print("Should chase down: {_should_chase_to_lower_platform()}")
	print("===========================")
