extends BaseEnemy
class_name NatalyBoss

signal boss_died

# =====================================================
# CONFIG
# =====================================================
@export var move_speed := 85.0
@export var melee_range_before := 100.0
@export var melee_range := 60.0
@export var slash_damage := 10
@export var combo_damage := 15
@export var combo_radius := 120.0
@export var dash_force := 200.0
@export var dash_duration := 0.2

@export var jump_height_threshold := 64.0
@export var max_reachable_height := 128.0  # Maximum height Nataly can reach from her current platform

# Attack patterns
@export var combo_patterns := [
	["slash", "slash_2", "combo"],
	["slash", "slash_2", "slash"]
]

# =====================================================
# NODES
# =====================================================
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var combo_hitbox := $ComboHitbox if has_node("ComboHitbox") else null
@onready var melee_hitbox := $MeleeHitbox if has_node("MeleeHitbox") else null

# =====================================================
# STATE
# =====================================================
var attack_running := false
var tired := false
var jump_markers: Array[Marker2D] = []
var is_moving_to_marker := false
var last_platform_check_time := 0.0
var platform_check_cooldown := 1.0  # Check every second if player is reachable

var ai_active := true
var is_invulnerable := false
var last_damage_time := 0.0  # To prevent double damage

# Combo system
var current_pattern_index := 0
var pattern_step := 0
var combo_cooldown_active := false

# =====================================================
# READY
# =====================================================
func _ready() -> void:
	super._ready()
	
	player = Global.playerBody
	health = 200
	health_max = 200
	# Disable BaseEnemy systems
	is_enemy_chase = false
	is_roaming = false
	use_edge_detection = false
	can_jump_chase = false

	attack_type = AttackType.MELEE
	attack_range = melee_range_before
	enemy_damage = slash_damage

	_collect_jump_markers()
	
	call_deferred("_start_ai")

# =====================================================
# PROCESS
# =====================================================
func _process(delta: float) -> void:
	if not ai_active or dead:
		return
		
	if anim:
		anim.speed_scale = Global.global_time_scale

	if not is_on_floor():
		velocity.y += gravity * delta

	if taking_damage:
		velocity.x = 0.0
		move_and_slide()
		return

	move_and_slide()
	
	# Update damage cooldown
	if last_damage_time > 0:
		last_damage_time -= delta
	
	# Update platform check cooldown
	if last_platform_check_time > 0:
		last_platform_check_time -= delta

# =====================================================
# TAKE DAMAGE - FIXED TO PREVENT DOUBLE DAMAGE
# =====================================================
func take_damage(amount: int) -> void:
	if dead or is_invulnerable:
		print("Nataly: Ignoring damage - dead:", dead, " invulnerable:", is_invulnerable)
		return
	
	# Prevent taking damage too quickly (within 0.1 seconds)
	var current_time = Time.get_ticks_msec() / 1000.0
	if last_damage_time > 0 and current_time < last_damage_time + 0.1:
		print("Nataly: Double damage prevented")
		return
	
	health -= amount
	last_damage_time = current_time
	print("Nataly health: ", health)
	
	# Stop everything
	velocity = Vector2.ZERO
	attack_running = false
	tired = false
	is_moving_to_marker = false
	
	# Play hurt animation
	if anim.has_animation("hurt"):
		anim.play("hurt")
		taking_damage = true
		
		# Wait for hurt animation
		var hurt_duration = anim.current_animation_length if anim.current_animation else 0.3
		await _safe_wait(hurt_duration*2 / Global.global_time_scale)
		
		taking_damage = false
	else:
		await _safe_wait(0.3 / Global.global_time_scale)
	
	if health <= 0:
		_die()

func _die() -> void:
	dead = true
	ai_active = false
	velocity = Vector2.ZERO
	
	if anim.has_animation("die"):
		anim.play("die")
		await anim.animation_finished
	if can_drop_health and health_drop_scene:
		try_drop_health()
		can_drop_health = false
		emit_signal("boss_died")
	queue_free()

# =====================================================
# HELPER FUNCTIONS FOR SAFE AWAITS
# =====================================================
func _is_still_valid() -> bool:
	return not dead and is_inside_tree() and ai_active

func _safe_wait(time: float) -> void:
	if not _is_still_valid():
		return
	
	var timer = get_tree().create_timer(time)
	await timer.timeout
	
func _safe_process_frame() -> void:
	if not _is_still_valid():
		return
	await get_tree().process_frame

# =====================================================
# PLATFORM REACHABILITY CHECK
# =====================================================
func _is_player_reachable() -> bool:
	if not player or not is_instance_valid(player):
		return false
	
	# Check vertical distance - if player is too high above, Nataly can't reach
	var vertical_dist = player.global_position.y - global_position.y
	
	# If player is too high (more than max_reachable_height above), Nataly can't reach
	if vertical_dist < -max_reachable_height:  # Player is way above
		print("Nataly: Player is too high to reach (", vertical_dist, " vs max ", max_reachable_height, ")")
		return false
	
	return true

# =====================================================
# MAIN AI LOOP
# =====================================================
func _start_ai() -> void:
	if not is_inside_tree():
		return
		
	ai_active = true
	print("Nataly AI started")
	_run_ai()

func _run_ai() -> void:
	print("Nataly: AI loop starting")
	
	while _is_still_valid() and ai_active:
		await _safe_process_frame()
			
		if dead:
			break

		if taking_damage or attack_running or tired or is_moving_to_marker:
			continue

		# Get player reference
		if not player or not is_instance_valid(player):
			player = Global.playerBody
			if not player:
				await _safe_wait(0.1)
				continue
		
		# Check if player is reachable
		if not _is_player_reachable():
			# Player is on unreachable platform, just stay idle
			if anim.has_animation("idle"):
				anim.play("idle")
			velocity.x = 0
			await _safe_wait(0.5)  # Wait half second before checking again
			continue
		
		# Calculate distances
		var horizontal_dist = abs(player.global_position.x - global_position.x)
		var vertical_dist = player.global_position.y - global_position.y

		# Check for platform movement
		if not is_moving_to_marker and abs(vertical_dist) > jump_height_threshold:
			print("Nataly: Need platform movement (height diff: ", vertical_dist, ")")
			await _handle_platform_movement()
			await _safe_wait(0.3)
			continue

		# Normal chasing/attacking
		if horizontal_dist > melee_range * 1.5:
			_chase_player()
			await _safe_wait(0.15)
			continue

		if horizontal_dist <= melee_range_before:
			print("Nataly: In melee range, starting attack")
			await _start_attack_pattern()
			await _safe_wait(0.1)
		else:
			_chase_player()
			await _safe_wait(0.08)

	print("Nataly AI stopped")

# =====================================================
# CHASE
# =====================================================
func _chase_player() -> void:
	if not _is_still_valid() or not player or not is_instance_valid(player):
		return

	var dx := player.global_position.x - global_position.x
	var chase_dir = sign(dx) if dx != 0 else dir.x
	
	dir.x = chase_dir
	
	if chase_dir != 0:
		sprite.flip_h = chase_dir < 0
		
	velocity.x = dir.x * move_speed
	
	if abs(velocity.x) > 0:
		if anim.has_animation("run"):
			anim.play("run")
		elif anim.has_animation("chase"):
			anim.play("chase")
	else:
		if anim.has_animation("idle"):
			anim.play("idle")

# =====================================================
# ATTACK PATTERNS
# =====================================================
func _start_attack_pattern() -> void:
	if not _is_still_valid():
		return
		
	attack_running = true
	velocity = Vector2.ZERO
	
	current_pattern_index = randi() % combo_patterns.size()
	pattern_step = 0
	
	print("Nataly: Starting attack pattern ", current_pattern_index)
	
	await _execute_next_attack_step()
	
	attack_running = false

func _execute_next_attack_step() -> void:
	if not _is_still_valid():
		attack_running = false
		return
		
	if pattern_step >= combo_patterns[current_pattern_index].size():
		_finish_pattern()
		return
	
	var attack_type = combo_patterns[current_pattern_index][pattern_step]
	pattern_step += 1
	
	print("Nataly: Executing attack: ", attack_type)
	
	match attack_type:
		"slash":
			await _execute_slash_attack()
		"slash_2":
			await _execute_slash_2_attack()
		"combo":
			await _execute_combo_attack()
	
	# Check if there are more steps
	if pattern_step < combo_patterns[current_pattern_index].size():
		await _safe_wait(0.2 / Global.global_time_scale)
		await _execute_next_attack_step()
	else:
		_finish_pattern()

func _finish_pattern() -> void:
	if not _is_still_valid():
		return
		
	print("Nataly: Pattern finished")
	
	# Check if last attack was "combo"
	var last_attack_was_combo = false
	if current_pattern_index < combo_patterns.size() and combo_patterns[current_pattern_index].size() > 0:
		last_attack_was_combo = (combo_patterns[current_pattern_index][-1] == "combo")
	
	if last_attack_was_combo:
		# Combo cooldown
		combo_cooldown_active = true
		tired = true
		print("Nataly: Combo finished, entering 5-second cooldown")
		
		velocity.x = 0
		anim.play("idle")
		await _safe_wait(5.0 / Global.global_time_scale)
		
		tired = false
		combo_cooldown_active = false
		print("Nataly: Cooldown finished")
	else:
		# Normal cooldown
		tired = true
		anim.play("idle")
		await _safe_wait(3.0 / Global.global_time_scale)
		tired = false

# =====================================================
# ATTACKS
# =====================================================
func _execute_slash_attack() -> void:
	if not _is_still_valid():
		return
		
	is_invulnerable = true
	attack_running = true
	
	# Face player
	if player and is_instance_valid(player):
		var to_player = player.global_position.x - global_position.x
		if abs(to_player) > 5.0:
			dir.x = sign(to_player)
			sprite.flip_h = dir.x < 0
	
	anim.play("slash")
	
	# Apply dash
	if dir.x != 0:
		velocity.x = dir.x * dash_force
	
	# Wait for dash
	await _safe_wait(dash_duration / Global.global_time_scale)
	
	velocity.x = 0
	
	# Wait for animation
	await anim.animation_finished
	
	is_invulnerable = false

func _execute_slash_2_attack() -> void:
	if not _is_still_valid():
		return
		
	is_invulnerable = true
	attack_running = true
	
	# Face player
	if player and is_instance_valid(player):
		var to_player = player.global_position.x - global_position.x
		if abs(to_player) > 5.0:
			dir.x = sign(to_player)
			sprite.flip_h = dir.x < 0
	
	anim.play("slash_2")
	
	# Apply dash
	if dir.x != 0:
		velocity.x = dir.x * dash_force
	
	# Wait for dash
	await _safe_wait(dash_duration / Global.global_time_scale)
	
	velocity.x = 0
	
	# Wait for animation
	await anim.animation_finished
	
	is_invulnerable = false

func _execute_combo_attack() -> void:
	if not _is_still_valid():
		return
		
	is_invulnerable = true
	attack_running = true
	
	# Face player
	if player and is_instance_valid(player):
		var to_player = player.global_position.x - global_position.x
		if abs(to_player) > 5.0:
			dir.x = sign(to_player)
			sprite.flip_h = dir.x < 0
	
	anim.play("combo")
	if dir.x != 0:
		velocity.x = dir.x * dash_force
	
	# Wait for dash
	await _safe_wait(dash_duration / Global.global_time_scale)
	
	velocity.x = 0
	
	# Wait for animation
	await anim.animation_finished
	
	is_invulnerable = false

# =====================================================
# DAMAGE APPLY FUNCTIONS - ADDED DOUBLE DAMAGE PREVENTION
# =====================================================
var last_hit_time := 0.0
var hit_cooldown := 0.2  # Cooldown between hits

func _apply_slash_damage() -> void:
	if not _is_still_valid() or not player or not is_instance_valid(player):
		return
	
	# Prevent multiple hits in quick succession
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time < last_hit_time + hit_cooldown:
		print("Nataly: Slash hit cooldown")
		return
	
	var distance = global_position.distance_to(player.global_position)
	if distance <= melee_range:
		print("Nataly: Slash hit player!")
		if player.has_method("take_damage"):
			player.take_damage(slash_damage)
			last_hit_time = current_time
	else:
		print("Nataly: Slash missed (distance: ", distance, ")")

func _apply_slash_2_damage() -> void:
	if not _is_still_valid() or not player or not is_instance_valid(player):
		return
	
	# Prevent multiple hits in quick succession
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time < last_hit_time + hit_cooldown:
		print("Nataly: Slash 2 hit cooldown")
		return
	
	var distance = global_position.distance_to(player.global_position)
	if distance <= melee_range:
		print("Nataly: Slash 2 hit player!")
		if player.has_method("take_damage"):
			player.take_damage(slash_damage)
			last_hit_time = current_time
	else:
		print("Nataly: Slash 2 missed (distance: ", distance, ")")

func _apply_combo_damage() -> void:
	if not _is_still_valid() or not player or not is_instance_valid(player):
		return
	
	# Prevent multiple hits in quick succession
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time < last_hit_time + hit_cooldown:
		print("Nataly: Combo hit cooldown")
		return
	
	var distance = global_position.distance_to(player.global_position)
	if distance <= combo_radius:
		print("Nataly: Combo hit player!")
		if player.has_method("take_damage"):
			player.take_damage(combo_damage)
			last_hit_time = current_time
	else:
		print("Nataly: Combo missed (distance: ", distance, ")")

# =====================================================
# PLATFORM MOVEMENT - WITH JUMP ANIMATION
# =====================================================
func _collect_jump_markers() -> void:
	jump_markers.clear()
	for m in get_tree().get_nodes_in_group("nataly_jump_marker"):
		if m is Marker2D:
			jump_markers.append(m)
	print("Nataly: Collected ", jump_markers.size(), " jump markers")

func _handle_platform_movement() -> void:
	if not _is_still_valid() or not player or not is_instance_valid(player) or jump_markers.is_empty():
		return
	
	var height_difference = player.global_position.y - global_position.y
	
	# First check if player is even reachable
	if not _is_player_reachable():
		print("Nataly: Player is on unreachable platform, staying idle")
		velocity.x = 0
		if anim.has_animation("idle"):
			anim.play("idle")
		return
	
	# Find the nearest marker
	var nearest_marker: Marker2D = null
	var nearest_distance = INF
	
	for marker in jump_markers:
		if not is_instance_valid(marker):
			continue
		
		var distance = marker.global_position.distance_to(global_position)
		if distance < nearest_distance and distance < 600:
			nearest_marker = marker
			nearest_distance = distance
	
	if nearest_marker:
		print("Nataly: Moving to nearest marker at ", nearest_marker.global_position)
		is_moving_to_marker = true
		
		# Determine if going up or down
		var going_up = height_difference < 0
		
		if going_up:
			await _move_up_to_marker(nearest_marker)
		else:
			await _move_down_to_marker(nearest_marker)
		
		is_moving_to_marker = false

func _move_up_to_marker(marker: Marker2D) -> void:
	print("Nataly: Moving UP to marker")
	
	# Move horizontally to marker
	var target_x = marker.global_position.x
	var reached = false
	var timeout = 2.0
	var start_time = Time.get_ticks_msec() / 1000.0
	
	while not reached and _is_still_valid() and not taking_damage:
		var current_time = Time.get_ticks_msec() / 1000.0
		if current_time - start_time > timeout:
			print("Nataly: Movement timeout")
			break
		
		var dx = target_x - global_position.x
		var move_dir = sign(dx) if dx != 0 else dir.x
		
		if abs(dx) > 10.0:
			dir.x = move_dir
			sprite.flip_h = move_dir < 0
		
		velocity.x = move_dir * move_speed
		
		if abs(velocity.x) > 0:
			if anim.has_animation("run"):
				anim.play("run")
		
		await _safe_process_frame()
		
		if abs(dx) < 20.0:
			reached = true
			velocity.x = 0
	
	if not _is_still_valid():
		return
	
	# Teleport up with jump animation
	print("Nataly: Teleporting upward")
	
	# Play jump animation if available
	if anim.has_animation("jump"):
		anim.play("jump")
		await _safe_wait(0.1 / Global.global_time_scale)
	
	if not _is_still_valid():
		return
	
	# Instant teleport to marker
	global_position = marker.global_position
	
	# Play landing animation or return to idle
	if anim.has_animation("idle"):
		anim.play("idle")
	velocity = Vector2.ZERO

func _move_down_to_marker(marker: Marker2D) -> void:
	print("Nataly: Moving DOWN past marker")
	
	# Move horizontally PAST the marker
	var target_x = marker.global_position.x
	var move_past_distance = 100.0  # How far past the marker to go
	var final_target_x = target_x + (move_past_distance if dir.x > 0 else -move_past_distance)
	
	var reached = false
	var timeout = 3.0
	var start_time = Time.get_ticks_msec() / 1000.0
	
	# Play jump animation before falling
	if anim.has_animation("jump") and _is_still_valid():
		anim.play("jump")
		await _safe_wait(0.2 / Global.global_time_scale)
	
	while not reached and _is_still_valid() and not taking_damage:
		var current_time = Time.get_ticks_msec() / 1000.0
		if current_time - start_time > timeout:
			print("Nataly: Movement timeout")
			break
		
		var dx = final_target_x - global_position.x
		var move_dir = sign(dx) if dx != 0 else dir.x
		
		# Keep moving in the current direction
		velocity.x = move_dir * move_speed
		
		if abs(velocity.x) > 0:
			if anim.has_animation("run"):
				anim.play("run")
		
		# Let gravity pull down
		if not is_on_floor():
			velocity.y += gravity * get_process_delta_time() * 1.5
		
		await _safe_process_frame()
		
		# Check if we've passed the marker area
		if move_dir > 0 and global_position.x > target_x + 50:
			reached = true
		elif move_dir < 0 and global_position.x < target_x - 50:
			reached = true
	
	if not _is_still_valid():
		return
	
	# Keep falling until aligned with player
	print("Nataly: Falling to align with player")
	timeout = 2.0
	start_time = Time.get_ticks_msec() / 1000.0
	
	while _is_still_valid() and not taking_damage:
		var current_time = Time.get_ticks_msec() / 1000.0
		if current_time - start_time > timeout:
			print("Nataly: Falling timeout")
			break
		
		# Apply gravity
		velocity.y += gravity * get_process_delta_time() * 1.5
		
		# Check if aligned with player
		if player and is_instance_valid(player):
			var height_diff = player.global_position.y - global_position.y
			if abs(height_diff) < 20:
				print("Nataly: Aligned with player")
				break
		
		await _safe_process_frame()
	
	if not _is_still_valid():
		return
	
	# Play landing effect if available
	if anim.has_animation("land"):
		anim.play("land")
		await anim.animation_finished
	elif anim.has_animation("idle"):
		anim.play("idle")
	
	velocity = Vector2.ZERO

# =====================================================
# OVERRIDE BASE METHODS
# =====================================================
func execute_attack():
	pass

func execute_melee_attack():
	pass

func execute_ranged_attack():
	pass
