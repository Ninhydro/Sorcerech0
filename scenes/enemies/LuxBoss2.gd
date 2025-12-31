extends BaseEnemy
class_name LuxBoss2

signal boss_died

# =====================================================
# CONFIG
# =====================================================
@export var move_speed := 85.0
@export var melee_range_before := 100.0
@export var melee_range := 60.0
@export var melee_damage := 10
@export var rocket_damage := 15
@export var slam_damage := 10
@export var rocket_radius := 200.0

@export var jump_height_threshold := 64.0
@export var max_reachable_height := 128.0  # Maximum height Lux can reach from her current platform

# Shield config
@export var shield_health := 80
@export var shield_active := false
@export var shield_activate_delay := 0.3
@export var shield_auto_disable_time := 10.0

# Rocket config
@export var rocket_attack_cooldown := 8.0
@export var rocket_windup_time := 0.8

# Slam attack config
@export var slam_speed := 400.0
@export var slam_cooldown := 5.0
var can_slam := true
var slam_cooldown_timer := 0.0
@export var slam_windup_time := 0.5
@export var slam_recovery_time := 1.5

# Visual config for vulnerable state
@export var vulnerable_modulate := Color(1.2, 0.6, 0.6, 1.0)  # Red tint

# =====================================================
# NODES
# =====================================================
@onready var shield_sprite := $ShieldSprite
@onready var rocket_spawn := $RocketSpawn if has_node("RocketSpawn") else $Sprite2D
@onready var melee_hitbox: Area2D = $MeleeHitbox if has_node("MeleeHitbox") else null

# =====================================================
# STATE
# =====================================================
var attack_running := false
var tired := false
var jump_markers: Array[Marker2D] = []
var slam_markers: Array[Marker2D] = []
var is_moving_to_marker := false
var last_platform_check_time := 0.0
var platform_check_cooldown := 1.0  # Check every second if player is reachable

var ai_active := true
var is_invulnerable := false
var last_damage_time := 0.0  # To prevent double damage

# Shield system
var current_shield_health: float
var has_taken_first_hit := false
var shield_activation_timer := 0.0
var shield_idle_timer := 0.0
var last_hit_time := 0.0

# Rocket system
var can_fire_rocket := true
var able_rocket := true
var no_damage := true
var rocket_cooldown_timer := 0.0
var rocket_scene: PackedScene
@export var boss_rocket_scene: PackedScene

var last_fallback_time := 0.0
@export var fallback_cooldown := 3.0 # seconds

var last_platform_move_time := 0.0
@export var platform_retry_cooldown := 1.2

var last_used_marker: Marker2D = null
@export var platform_height_tolerance := 20.0

# Vulnerable state
var is_vulnerable_state := false

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
	enemy_damage = melee_damage
	
	# Initialize shield
	current_shield_health = shield_health
	update_shield_visual()
	
	# Disable melee hitbox by default
	if melee_hitbox:
		melee_hitbox.monitoring = false
	
	# Set up rocket scene
	rocket_scene = boss_rocket_scene if boss_rocket_scene else preload("res://scenes/enemies/Projectile_enemy.tscn")

	_collect_jump_markers()
	_collect_slam_markers()
	
	call_deferred("_start_ai")

# =====================================================
# PROCESS
# =====================================================
func _process(delta: float) -> void:
	if not ai_active or dead:
		return
		
	if animation_player:
		animation_player.speed_scale = Global.global_time_scale

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
	
	# Handle shield activation delay (only in invulnerable state)
	if not is_vulnerable_state and has_taken_first_hit and not shield_active and shield_activation_timer > 0:
		shield_activation_timer -= delta * Global.global_time_scale
		if shield_activation_timer <= 0:
			activate_shield()
	
	# Handle shield auto-disable timer (only in invulnerable state)
	if not is_vulnerable_state and shield_active:
		shield_idle_timer += delta * Global.global_time_scale
		if shield_idle_timer >= shield_auto_disable_time:
			reset_shield()
			print("Lux: Shield automatically disabled after ", shield_auto_disable_time, " seconds")
	
	# Handle rocket cooldown
	if not can_fire_rocket:
		rocket_cooldown_timer -= delta * Global.global_time_scale
		if rocket_cooldown_timer <= 0:
			can_fire_rocket = true
	
	# Handle slam cooldown
	if not can_slam:
		slam_cooldown_timer -= delta * Global.global_time_scale
		if slam_cooldown_timer <= 0:
			can_slam = true

# =====================================================
# TAKE DAMAGE - FIXED TO PREVENT DOUBLE DAMAGE
# =====================================================
func take_damage(amount: int) -> void:
	if dead or is_invulnerable:
		print("Lux: Ignoring damage - dead:", dead, " invulnerable:", is_invulnerable)
		return
	
	# Update last hit time
	last_hit_time = Time.get_ticks_msec() / 1000.0
	
	# In vulnerable state: direct damage, no shield
	if is_vulnerable_state:
		# Use Nataly's damage prevention logic
		var current_time = Time.get_ticks_msec() / 1000.0
		if last_damage_time > 0 and current_time < last_damage_time + 0.1:
			print("Lux: Double damage prevented")
			return
		
		health -= amount
		last_damage_time = current_time
		print("Lux health: ", health)
		
		# Stop everything
		velocity = Vector2.ZERO
		attack_running = false
		tired = false
		is_moving_to_marker = false
		
		# Play hurt animation
		if animation_player.has_animation("hurt"):
			animation_player.play("hurt")
			taking_damage = true
			
			# Wait for hurt animation
			var hurt_duration = animation_player.current_animation_length if animation_player.current_animation else 0.3
			await _safe_wait(hurt_duration / Global.global_time_scale)
			
			taking_damage = false
		else:
			await _safe_wait(0.3 / Global.global_time_scale)
		
		if health <= 0:
			_die()
		return
	
	# In invulnerable state: use shield system
	# Reset shield idle timer when taking damage
	if shield_active:
		shield_idle_timer = 0.0
		print("Lux Shield idle timer reset due to damage")

	# Check if this is the first hit
	if not has_taken_first_hit:
		has_taken_first_hit = true
		shield_activation_timer = shield_activate_delay
		print("Lux First hit! Shield will activate in ", shield_activate_delay, " seconds")
		
		# Take normal damage on first hit
		if shield_auto_disable_time == 1:
			pass
		else:
			if no_damage:
				return
			else:
				# Use Nataly's damage prevention logic
				var current_time = Time.get_ticks_msec() / 1000.0
				if last_damage_time > 0 and current_time < last_damage_time + 0.1:
					print("Lux: Double damage prevented")
					return
				
				health -= amount
				last_damage_time = current_time
				print("Lux health: ", health)
		
	elif shield_active and current_shield_health > 0:
		# Shield takes damage
		current_shield_health -= amount
		taking_damage = true
		
		print("Lux Shield took damage: ", amount, " Shield health: ", current_shield_health)
		
		# Shield hit effect
		if shield_sprite:
			shield_sprite.modulate = Color(1.0, 0.5, 0.5, 0.7)
			await _safe_wait(0.1/Global.global_time_scale)
			update_shield_visual()
		
		taking_damage = false
		
		if current_shield_health <= 0:
			current_shield_health = 0
			deactivate_shield()
			print("Lux: Shield broken!")
	else:
		if no_damage:
			return
		else:
			# Use Nataly's damage prevention logic
			var current_time = Time.get_ticks_msec() / 1000.0
			if last_damage_time > 0 and current_time < last_damage_time + 0.1:
				print("Lux: Double damage prevented")
				return
			
			health -= amount
			last_damage_time = current_time
			print("Lux health: ", health)
	
	# Stop everything
	velocity = Vector2.ZERO
	attack_running = false
	tired = false
	is_moving_to_marker = false
	
	# Play hurt animation
	if animation_player.has_animation("hurt"):
		animation_player.play("hurt")
		taking_damage = true
		
		# Wait for hurt animation
		var hurt_duration = animation_player.current_animation_length if animation_player.current_animation else 0.3
		await _safe_wait(hurt_duration / Global.global_time_scale)
		
		taking_damage = false
	else:
		await _safe_wait(0.3 / Global.global_time_scale)
	
	if health <= 0:
		_die()

func _die() -> void:
	dead = true
	ai_active = false
	velocity = Vector2.ZERO
	
	if animation_player.has_animation("die"):
		animation_player.play("die")
		await animation_player.animation_finished
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
# SHIELD SYSTEM
# =====================================================
func activate_shield():
	if is_vulnerable_state:
		return  # No shield in vulnerable state
	
	shield_active = true
	shield_idle_timer = 0.0
	print("Lux: Shield activated!")
	
	# Update shield visual
	update_shield_visual()
	
	# Stop moving when shield is active
	base_speed = 0
	velocity.x = 0
	
	# Reset attack states
	attack_running = false

func deactivate_shield():
	if is_vulnerable_state:
		return  # No shield in vulnerable state
	
	shield_active = false
	print("Lux: Shield broken!")
	
	# Resume movement (slower after shield breaks)
	base_speed = move_speed * 0.5
	
	# Reset attack cooldowns so boss can attack again
	can_attack = true
	attack_running = false
	
	# Update shield visual
	update_shield_visual()

func reset_shield():
	if is_vulnerable_state:
		return  # No shield in vulnerable state
	
	shield_active = false
	has_taken_first_hit = false
	current_shield_health = shield_health
	shield_idle_timer = 0.0
	
	print("Lux: Shield reset - ready to activate again on next hit")
	
	# Resume normal movement speed
	base_speed = move_speed
	
	# Reset attack states
	can_attack = true
	attack_running = false
	
	# Update shield visual
	update_shield_visual()

func update_shield_visual():
	if shield_sprite:
		if shield_active and not is_vulnerable_state:
			shield_sprite.visible = true
			# Visual feedback based on shield health
			var shield_ratio = current_shield_health / shield_health
			shield_sprite.modulate.a = 0.5
			
			# Color based on shield health
			if shield_ratio > 0.5:
				shield_sprite.modulate = Color(0.2, 0.6, 1.0, 0.5)
			elif shield_ratio > 0.25:
				shield_sprite.modulate = Color(1.0, 1.0, 0.2, 0.5)
			else:
				shield_sprite.modulate = Color(1.0, 0.3, 0.2, 0.5)
		else:
			shield_sprite.visible = false

# =====================================================
# COLLECT MARKERS
# =====================================================
func _collect_jump_markers() -> void:
	jump_markers.clear()
	for m in get_tree().get_nodes_in_group("lux_jump_marker"):
		if m is Marker2D:
			jump_markers.append(m)
	print("Lux: Collected ", jump_markers.size(), " jump markers")

func _collect_slam_markers() -> void:
	slam_markers.clear()
	for m in get_tree().get_nodes_in_group("lux_slam_point"):
		if m is Marker2D:
			slam_markers.append(m)
	print("Lux: Collected ", slam_markers.size(), " slam markers")

# =====================================================
# PLATFORM REACHABILITY CHECK
# =====================================================
func _is_player_reachable() -> bool:
	if not player or not is_instance_valid(player):
		return false
	
	# Check vertical distance - if player is too high above, Lux can't reach
	var vertical_dist = player.global_position.y - global_position.y
	
	# If player is too high (more than max_reachable_height above), Lux can't reach
	if vertical_dist < -max_reachable_height:  # Player is way above
		print("Lux: Player is too high to reach (", vertical_dist, " vs max ", max_reachable_height, ")")
		return false
	
	return true

# =====================================================
# MAIN AI LOOP - MODIFIED FOR VULNERABLE STATE
# =====================================================
func _start_ai() -> void:
	if not is_inside_tree():
		return
		
	ai_active = true
	print("Lux AI started")
	_run_ai()

func _run_ai() -> void:
	print("Lux: AI loop starting")
	
	while _is_still_valid() and ai_active:
		await _safe_process_frame()
			
		if dead:
			break

		if taking_damage or attack_running or tired or is_moving_to_marker or (not is_vulnerable_state and shield_active):
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
			if animation_player.has_animation("idle"):
				animation_player.play("idle")
			velocity.x = 0
			await _safe_wait(0.5)  # Wait half second before checking again
			continue
		
		# Calculate distances
		var horizontal_dist = abs(player.global_position.x - global_position.x)
		var vertical_dist = player.global_position.y - global_position.y

		# Check for platform movement
		var now := Time.get_ticks_msec() / 1000.0

		if not is_moving_to_marker \
		and abs(vertical_dist) > jump_height_threshold \
		and now - last_platform_move_time > platform_retry_cooldown:
			
			print("Lux: Need platform movement (height diff: ", vertical_dist, ")")
			last_platform_move_time = now
			await _handle_platform_movement()
			await _safe_wait(0.3)
			continue

		# Normal chasing/attacking
		if horizontal_dist > melee_range * 1.5:
			_chase_player()
			await _safe_wait(0.15)
			continue

		if horizontal_dist <= melee_range_before:
			print("Lux: In melee range, starting attack")
			await _start_attack()
			await _safe_wait(0.1)
		else:
			# In vulnerable state, consider slam attack when far away
				_chase_player()
				await _safe_wait(0.08)

	print("Lux AI stopped")

# =====================================================
# CHASE - IDENTICAL TO NATALY
# =====================================================
func _chase_player() -> void:
	if not _is_still_valid() or not player or not is_instance_valid(player):
		return

	var dx := player.global_position.x - global_position.x
	var chase_dir = sign(dx) if dx != 0 else dir.x
	
	dir.x = chase_dir
	
	if chase_dir != 0:
		velocity.x = dir.x * move_speed
		_update_facing_from_movement_or_target(player.global_position.x)

		if rocket_spawn:
			rocket_spawn.position.x = abs(rocket_spawn.position.x) * chase_dir
		
	velocity.x = dir.x * move_speed
	
	if abs(velocity.x) > 0:
		if animation_player.has_animation("walk"):
			animation_player.play("walk")
		elif animation_player.has_animation("chase"):
			animation_player.play("chase")
	else:
		if animation_player.has_animation("idle"):
			animation_player.play("idle")

# =====================================================
# ATTACK SYSTEM - MODIFIED FOR VULNERABLE STATE
# =====================================================
func _start_attack() -> void:
	if not _is_still_valid():
		return
		
	attack_running = true
	velocity = Vector2.ZERO
	
	# Decide which attack to use
	var distance = global_position.distance_to(player.global_position)
	var horizontal_dist = abs(player.global_position.x - global_position.x)
	# In vulnerable state: melee or rocket
	if is_vulnerable_state:
		if distance <= melee_range:
			await _execute_melee_attack()
		elif can_fire_rocket and able_rocket and distance > melee_range and distance <= rocket_radius:
			#if randf() < 0.1:
				await _execute_rocket_attack()
		#	else:
		#elif can_slam and horizontal_dist > rocket_radius and randf() < 0.9:
				#await _execute_slam_attack()
				await _safe_wait(0.1)
		else:
			pass
	# In invulnerable state: only melee when close
	else:
		if distance <= melee_range:
			await _execute_melee_attack()

	attack_running = false

func _execute_melee_attack() -> void:
	if not _is_still_valid():
		attack_running = false
		return
	
	is_invulnerable = true
	attack_running = true
	
	# Face player
	if player and is_instance_valid(player):
		var to_player = player.global_position.x - global_position.x
		if abs(to_player) > 5.0:
			dir.x = sign(to_player)
			_update_facing_from_movement_or_target(player.global_position.x)
			if shield_sprite:
				shield_sprite.flip_h = sprite.flip_h
			if rocket_spawn:
				rocket_spawn.position.x = abs(rocket_spawn.position.x) * dir.x
	
	animation_player.play("melee")
	
	# Wait for animation to start dealing damage
	await _safe_wait(0.2 / Global.global_time_scale)
	
	# Enable hitbox
	if melee_hitbox:
		melee_hitbox.monitoring = true
	
	# Deal damage
	await _safe_wait(0.1 / Global.global_time_scale)
	if player and global_position.distance_to(player.global_position) <= melee_range:
		player.take_damage(melee_damage)
		print("Lux dealt melee damage: ", melee_damage)
	
	# Disable hitbox
	await _safe_wait(0.15 / Global.global_time_scale)
	if melee_hitbox:
		melee_hitbox.monitoring = false
	
	# Wait for animation
	await animation_player.animation_finished
	
	is_invulnerable = false
	
	# Cooldown
	tired = true
	animation_player.play("idle")
	await _safe_wait(1.0 / Global.global_time_scale)
	tired = false

func _execute_rocket_attack() -> void:
	if not _is_still_valid():
		attack_running = false
		return
	
	is_invulnerable = true
	attack_running = true
	can_fire_rocket = false
	
	# Face player before attacking
	if player and is_instance_valid(player):
		var to_player = player.global_position.x - global_position.x
		if abs(to_player) > 5.0:
			dir.x = sign(to_player)
			_update_facing_from_movement_or_target(player.global_position.x)
			if shield_sprite:
				shield_sprite.flip_h = sprite.flip_h
			if rocket_spawn:
				rocket_spawn.position.x = abs(rocket_spawn.position.x) * dir.x
	
	animation_player.play("rocket")
	
	# Windup time
	await _safe_wait(rocket_windup_time / Global.global_time_scale)
	
	if not player or dead or not _is_still_valid():
		attack_running = false
		animation_player.play("idle")
		return
	
	# Fire rocket
	_fire_single_rocket()
	
	# Return to idle
	animation_player.play("idle")
	
	is_invulnerable = false
	
	# Cooldown
	rocket_cooldown_timer = rocket_attack_cooldown
	tired = true
	await _safe_wait(1.0 / Global.global_time_scale)
	tired = false

func _fire_single_rocket():
	if rocket_scene and player and _is_still_valid():
		var rocket = rocket_scene.instantiate()
		get_tree().current_scene.add_child(rocket)
		
		var spawn_pos = rocket_spawn.global_position if rocket_spawn else global_position
		rocket.global_position = spawn_pos
		
		# Set rocket properties
		if rocket.has_method("set_target"):
			rocket.set_target(player)
		if rocket.has_method("set_initial_direction"):
			var to_player = player.global_position - spawn_pos
			var initial_dir = to_player.normalized()
			initial_dir.y -= 0.2
			initial_dir = initial_dir.normalized()
			rocket.set_initial_direction(initial_dir)
		
		# Set speed and damage if available
		if "speed" in rocket:
			rocket.speed = 200.0
		if "turn_rate" in rocket:
			rocket.turn_rate = 1.5
		if "damage" in rocket:
			rocket.damage = rocket_damage
		if "lifetime" in rocket:
			rocket.lifetime = 4.0

# =====================================================
# SLAM ATTACK - NEW FOR VULNERABLE STATE
# =====================================================
func _execute_slam_attack() -> void:
	if not _is_still_valid() or not can_slam or slam_markers.is_empty():
		return
	
	attack_running = true
	can_slam = false
	
	print("Lux: Starting slam attack!")
	
	# Find a random slam marker
	var valid_markers: Array[Marker2D] = []
	for marker in slam_markers:
		if is_instance_valid(marker) and marker != last_used_marker:
			valid_markers.append(marker)
	
	if valid_markers.is_empty():
		# No unique markers, use any marker
		for marker in slam_markers:
			if is_instance_valid(marker):
				valid_markers.append(marker)
	
	if valid_markers.is_empty():
		attack_running = false
		return
	
	var slam_marker = valid_markers[randi() % valid_markers.size()]
	last_used_marker = slam_marker
	
	# Phase 1: Jump to slam marker
	print("Lux: Jumping to slam marker at ", slam_marker.global_position)
	is_moving_to_marker = true
	
	# Face marker
	var dx = slam_marker.global_position.x - global_position.x
	dir.x = sign(dx)
	_update_facing_from_movement_or_target(slam_marker.global_position.x)
	
	# Play jump animation
	if animation_player.has_animation("jump"):
		animation_player.play("jump")
		await _safe_wait(0.2 / Global.global_time_scale)
	
	# Teleport to slam marker
	global_position = slam_marker.global_position
	is_moving_to_marker = false
	
	# Check if player is above (cancel attack if player is above)
	if player and is_instance_valid(player):
		var player_height_diff = player.global_position.y - global_position.y
		if player_height_diff < -20:  # Player is above
			print("Lux: Player is above, cancelling slam attack")
			attack_running = false
			can_slam = true  # Reset cooldown since attack was cancelled
			return
	
	# Phase 2: Aim at player
	print("Lux: Aiming at player")
	if player and is_instance_valid(player):
		# Calculate direction to player
		var to_player = player.global_position - global_position
		var target_rotation = atan2(to_player.y, to_player.x)
		
		# Rotate sprite to aim (simplified - just flip if needed)
		if to_player.x < 0:
			sprite.flip_h = true
			if shield_sprite:
				shield_sprite.flip_h = true
		else:
			sprite.flip_h = false
			if shield_sprite:
				shield_sprite.flip_h = false
		
		# Windup animation
		if animation_player.has_animation("jump"):
			animation_player.play("jump")
		else:
			animation_player.play("idle")
		
		await _safe_wait(slam_windup_time / Global.global_time_scale)
		
		# Phase 3: Slam toward player
		print("Lux: Slamming toward player!")
		if animation_player.has_animation("slam"):
			animation_player.play("slam")
		else:
			animation_player.play("jump")  # Fallback animation
		
		# Calculate slam direction
		var slam_direction = to_player.normalized()
		var slam_distance = to_player.length()
		var travel_time = slam_distance / slam_speed
		
		# Move toward player
		var start_pos = global_position
		var target_pos = player.global_position
		var elapsed_time = 0.0
		
		while elapsed_time < travel_time and _is_still_valid() and not taking_damage:
			var t = elapsed_time / travel_time
			global_position = start_pos.lerp(target_pos, t)
			
			# Check for collision with player
			if player and is_instance_valid(player):
				var distance_to_player = global_position.distance_to(player.global_position)
				if distance_to_player <= melee_range:
					# Hit player
					player.take_damage(slam_damage)
					print("Lux slam hit player for ", slam_damage, " damage!")
					break
			
			elapsed_time += get_process_delta_time()
			await _safe_process_frame()
		
		# Check if we hit the ground instead
		if is_on_floor() and player and is_instance_valid(player):
			var distance_to_player = global_position.distance_to(player.global_position)
			if distance_to_player > melee_range:
				print("Lux: Slam hit the ground, missed player")
		
		# Phase 4: Recovery
		print("Lux: Slam recovery")
		velocity = Vector2.ZERO
		
		if animation_player.has_animation("slam_recovery"):
			animation_player.play("slam_recovery")
		else:
			animation_player.play("idle")
		
		await _safe_wait(slam_recovery_time / Global.global_time_scale)
	
	attack_running = false
	slam_cooldown_timer = slam_cooldown

# =====================================================
# PLATFORM MOVEMENT - IDENTICAL TO NATALY
# =====================================================
func _handle_platform_movement() -> void:
	if not _is_still_valid() or not player or not is_instance_valid(player) or jump_markers.is_empty():
		return
	
	var height_difference = player.global_position.y - global_position.y
	
	# First check if player is even reachable
	if not _is_player_reachable():
		print("Lux: Player is on unreachable platform, staying idle")
		velocity.x = 0
		if animation_player.has_animation("idle"):
			animation_player.play("idle")
		return
	
	# Find the nearest marker
	var nearest_marker: Marker2D = null
	var nearest_distance = INF
	
	for marker in jump_markers:
		if not is_instance_valid(marker):
			continue
		
		var distance = marker.global_position.distance_to(global_position)
		var height_diff = abs(marker.global_position.y - global_position.y)

		if distance < nearest_distance \
		and distance < 600 \
		and height_diff > platform_height_tolerance:
			nearest_marker = marker
			nearest_distance = distance
	
	if nearest_marker:
		print("Lux: Moving to nearest marker at ", nearest_marker.global_position)
		is_moving_to_marker = true
		
		# Determine if going up or down
		var going_up = height_difference < 0
		
		if going_up:
			await _move_up_to_marker(nearest_marker)
		else:
			await _move_down_to_marker(nearest_marker)
		
		is_moving_to_marker = false

func _move_up_to_marker(marker: Marker2D) -> void:
	print("Lux: Moving UP to marker")
	
	# Move horizontally to marker
	var target_x = marker.global_position.x
	var reached = false
	var timeout = 2.0
	var start_time = Time.get_ticks_msec() / 1000.0
	
	while not reached and _is_still_valid() and not taking_damage:
		var current_time = Time.get_ticks_msec() / 1000.0
		if current_time - start_time > timeout:
			print("Lux: Movement timeout")
			break
		
		var dx = target_x - global_position.x
		var move_dir = sign(dx) if dx != 0 else dir.x
		
		if abs(dx) > 10.0:
			dir.x = move_dir
			sprite.flip_h = move_dir < 0
			if shield_sprite:
				shield_sprite.flip_h = sprite.flip_h
			if rocket_spawn:
				rocket_spawn.position.x = abs(rocket_spawn.position.x) * move_dir
		
		velocity.x = move_dir * move_speed
		_update_facing_from_movement_or_target(marker.global_position.x)

		if abs(velocity.x) > 0:
			if animation_player.has_animation("walk"):
				animation_player.play("walk")
		
		await _safe_process_frame()
		
		if abs(dx) < 20.0:
			reached = true
			velocity.x = 0
	
	if not _is_still_valid() or not reached:
		print("Lux: Cannot reach upper marker → fallback")
		await _fallback_when_cannot_jump()
		return
	
	# Teleport up with jump animation
	print("Lux: Teleporting upward")
	
	# Play jump animation if available
	if animation_player.has_animation("jump"):
		animation_player.play("jump")
		await _safe_wait(0.1 / Global.global_time_scale)
	
	if not _is_still_valid() or not reached:
		print("Lux: Cannot reach upper marker → fallback")
		await _fallback_when_cannot_jump()
		return
	
	# Instant teleport to marker
	global_position = marker.global_position
	
	# Play landing animation or return to idle
	if animation_player.has_animation("idle"):
		animation_player.play("idle")
	velocity = Vector2.ZERO
	
	last_used_marker = marker
	last_platform_move_time = Time.get_ticks_msec() / 1000.0

func _move_down_to_marker(marker: Marker2D) -> void:
	print("Lux: Moving DOWN past marker")
	
	# Move horizontally PAST the marker
	var target_x = marker.global_position.x
	var move_past_distance = 100.0  # How far past the marker to go
	var final_target_x = target_x + (move_past_distance if dir.x > 0 else -move_past_distance)
	
	var reached = false
	var timeout = 3.0
	var start_time = Time.get_ticks_msec() / 1000.0
	
	# Play jump animation before falling
	if animation_player.has_animation("jump") and _is_still_valid():
		animation_player.play("jump")
		await _safe_wait(0.2 / Global.global_time_scale)
	
	while not reached and _is_still_valid() and not taking_damage:
		var current_time = Time.get_ticks_msec() / 1000.0
		if current_time - start_time > timeout:
			print("Lux: Movement timeout")
			break
		
		var dx = final_target_x - global_position.x
		var move_dir = sign(dx) if dx != 0 else dir.x
		
		# Keep moving in the current direction
		velocity.x = move_dir * move_speed
		_update_facing_from_movement_or_target(marker.global_position.x)

		if abs(velocity.x) > 0:
			if animation_player.has_animation("walk"):
				animation_player.play("walk")
		
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
	print("Lux: Falling to align with player")
	timeout = 2.0
	start_time = Time.get_ticks_msec() / 1000.0
	
	while _is_still_valid() and not taking_damage:
		var current_time = Time.get_ticks_msec() / 1000.0
		if current_time - start_time > timeout:
			print("Lux: Falling timeout")
			break
		
		# Apply gravity
		velocity.y += gravity * get_process_delta_time() * 1.5
		
		# Check if aligned with player
		if player and is_instance_valid(player):
			var height_diff = player.global_position.y - global_position.y
			if abs(height_diff) < 20:
				print("Lux: Aligned with player")
				break
		
		await _safe_process_frame()
	
	if not _is_still_valid():
		return
	
	# Play landing effect if available
	if animation_player.has_animation("land"):
		animation_player.play("land")
		await animation_player.animation_finished
	elif animation_player.has_animation("idle"):
		animation_player.play("idle")
	
	velocity = Vector2.ZERO

# =====================================================
# SPECIAL FUNCTIONS
# =====================================================
func set_invulnerable():
	is_vulnerable_state = false
	shield_auto_disable_time = 1
	able_rocket = false
	melee_damage = 5
	no_damage = true
	
	# Reset visual to normal - SAFE CHECK
	if sprite:
		sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
	
	if shield_sprite:
		shield_sprite.visible = true
		update_shield_visual()
	
	print("set_invulnerable")
	
func set_vulnerable():
	is_vulnerable_state = true
	shield_auto_disable_time = 10
	able_rocket = true
	melee_damage = 10
	no_damage = false
	
	# Apply red tint visual - SAFE CHECK
	if sprite:
		sprite.modulate = vulnerable_modulate
	
	if shield_sprite:
		shield_sprite.visible = false  # No shield in vulnerable state
	
	# Reset shield system
	shield_active = false
	has_taken_first_hit = false
	current_shield_health = shield_health
	
	print("set_vulnerable")

# =====================================================
# HELPER FUNCTIONS
# =====================================================
func _update_facing_from_movement_or_target(target_x: float = 0.0):
	# Priority 1: real movement (prevents moonwalk)
	if abs(velocity.x) > 1.0:
		sprite.flip_h = velocity.x < 0
	else:
		# Priority 2: target direction (player or marker)
		var dx = target_x - global_position.x
		if abs(dx) > 1.0:
			sprite.flip_h = dx < 0

	# Sync attachments
	if shield_sprite:
		shield_sprite.flip_h = sprite.flip_h
	if rocket_spawn:
		rocket_spawn.position.x = abs(rocket_spawn.position.x) * (-1 if sprite.flip_h else 1)

func _fallback_when_cannot_jump() -> void:
	if not _is_still_valid():
		return

	var now := Time.get_ticks_msec() / 1000.0
	if now - last_fallback_time < fallback_cooldown:
		return # too soon, do nothing

	last_fallback_time = now

	# Decide action
	if able_rocket and randi() % 2 == 0:
		print("Lux: Fallback → Rocket attack")
		await _execute_rocket_attack()
	else:
		print("Lux: Fallback → Idle")
		if animation_player.has_animation("idle"):
			animation_player.play("idle")

# =====================================================
# OVERRIDE BASE METHODS - IDENTICAL TO NATALY
# =====================================================
func execute_attack():
	pass

func execute_melee_attack():
	pass

func execute_ranged_attack():
	pass
