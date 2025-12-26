extends BaseEnemy
class_name NatalyBoss

signal boss_died

# -------------------------------------------------
# BOSS CONFIG
# -------------------------------------------------
@export var walk_speed := 85.0  # Faster than normal enemies
@export var melee_range := 60.0
@export var slash_damage := 10
@export var combo_damage := 25  # AoE combo damage
@export var combo_radius := 120.0  # Radius for AoE combo

# Combo system
var combo_count := 0
var max_combo := 3
var combo_window := 1.0  # Time between attacks to count as combo
var combo_timer := 0.0
var is_in_combo := false
var final_combo_attack := false

# -------------------------------------------------
# PLATFORM JUMP/TELEPORT SYSTEM (Sterling-style)
# -------------------------------------------------
var jump_markers: Array[Marker2D] = []
@export var teleport_cooldown_time := 3.0
var teleport_cooldown := 0.0
@export var platform_height_threshold := 48.0  # Min height difference to consider platform movement
@export var max_jump_distance := 500.0  # Max distance for jump/teleport

# Platform movement states
var is_moving_to_platform := false
var target_marker: Marker2D = null

# -------------------------------------------------
# COMBO ATTACK PATTERNS
# -------------------------------------------------
@export var combo_patterns := [
	["slash", "slash_2", "combo"],  # 2 slashes + AoE combo
	["slash", "combo"],           # Slash + AoE combo
	["slash", "slash_2", "slash"]   # 3 rapid slashes
]
var current_pattern_index := 0
var pattern_step := 0

# -------------------------------------------------
# NODES
# -------------------------------------------------
@onready var combo_hitbox := $ComboHitbox if has_node("ComboHitbox") else null
@onready var melee_hitbox := $MeleeHitbox if has_node("MeleeHitbox") else null
@onready var teleport_markers_group := "nataly_jump_marker"

# -------------------------------------------------
# READY & INITIALIZATION
# -------------------------------------------------
func _ready() -> void:
	player = Global.playerBody
	set_meta("boss_id", "nataly")
	
	# Get all teleport markers
	refresh_jump_markers()
	
	# Initialize as a melee boss
	_initialize_enemy()
	
	# Start with idle animation
	animation_player.play("idle")
	
	super._ready()

func _initialize_enemy():
	# Set up BaseEnemy properties
	base_speed = walk_speed
	attack_range = melee_range
	enemy_damage = slash_damage
	health = 180
	health_max = 180
	use_edge_detection = true
	can_drop_health = true
	health_drop_chance = 1.0
	attack_type = AttackType.MELEE
	
	# Disable hitboxes by default
	if melee_hitbox:
		melee_hitbox.monitoring = false
	if combo_hitbox:
		combo_hitbox.monitoring = false

# -------------------------------------------------
# PROCESS
# -------------------------------------------------
func _process(delta):
	super._process(delta)
	
	# Update teleport cooldown
	if teleport_cooldown > 0:
		teleport_cooldown -= delta * Global.global_time_scale
	
	# Update combo timer
	if is_in_combo:
		combo_timer -= delta * Global.global_time_scale
		if combo_timer <= 0:
			reset_combo()
			print("Nataly: Combo window expired")
	
	# Check for platform movement (like Sterling)
	if (player and not dead and not taking_damage and not is_dealing_damage 
		and not is_moving_to_platform and teleport_cooldown <= 0 
		and _should_move_to_different_platform()):
		_handle_platform_movement()

# -------------------------------------------------
# MOVEMENT OVERRIDE
# -------------------------------------------------
func move(delta):
	if dead or taking_damage or is_dealing_damage or is_preparing_attack or is_moving_to_platform:
		# Use base movement for these states
		super.move(delta)
		return
	
	# Nataly is more aggressive - always chase when player is in range
	if is_enemy_chase and player and not is_in_combo:
		is_roaming = false
		
		var to_player = player.global_position - global_position
		var distance = to_player.length()
		
		# Face player
		dir.x = sign(to_player.x)
		
		# If too far for melee, move closer
		if distance > melee_range:
			velocity.x = dir.x * base_speed * Global.global_time_scale
		else:
			# Within melee range - stop moving and prepare attack
			velocity.x = 0
			if can_attack and not is_preparing_attack:
				start_attack()
	else:
		# Use base movement when not chasing
		super.move(delta)

# -------------------------------------------------
# PLATFORM MOVEMENT SYSTEM (Sterling-style)
# -------------------------------------------------
func refresh_jump_markers():
	# Get all markers in the nataly_jump_marker group
	var marker_nodes = get_tree().get_nodes_in_group(teleport_markers_group)
	jump_markers = []
	for node in marker_nodes:
		if node is Marker2D and is_instance_valid(node):
			jump_markers.append(node)
	
	print("Nataly: Found ", jump_markers.size(), " jump markers")

func _should_move_to_different_platform() -> bool:
	if not player or jump_markers.is_empty() or is_in_combo:
		return false
	
	# Check vertical distance to player
	var height_difference = player.global_position.y - global_position.y
	
	# Only consider platform movement if player is SIGNIFICANTLY above or below
	if abs(height_difference) > platform_height_threshold:
		print("Nataly: Player is ", 
			  "BELOW" if height_difference > 0 else "ABOVE", 
			  " by ", abs(height_difference), "px")
		return true
	
	return false

func _handle_platform_movement():
	if is_dealing_damage or taking_damage or is_moving_to_platform:
		return
	
	print("Nataly: Starting platform movement routine")
	is_moving_to_platform = true
	teleport_cooldown = teleport_cooldown_time
	
	# Find the best marker for current situation
	var height_difference = player.global_position.y - global_position.y
	var best_marker: Marker2D = null
	var best_score = INF
	
	for marker in jump_markers:
		if not is_instance_valid(marker):
			continue
		
		var marker_height_diff = marker.global_position.y - global_position.y
		var horizontal_dist_to_marker = abs(marker.global_position.x - global_position.x)
		var vertical_dist_to_player = abs(marker.global_position.y - player.global_position.y)
		var distance_to_marker = marker.global_position.distance_to(global_position)
		
		# Skip markers that are too far
		if distance_to_marker > max_jump_distance:
			continue
		
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
		
		# Also check if marker is reachable (not blocked)
		if score < best_score:
			best_marker = marker
			best_score = score
	
	if best_marker:
		print("Nataly: Moving to marker at ", best_marker.global_position, 
			  " (player at ", player.global_position, ")")
		target_marker = best_marker
		await _smooth_move_to_marker(best_marker, height_difference < 0)
	else:
		print("Nataly: No suitable marker found for platform movement")
	
	is_moving_to_platform = false
	target_marker = null

func _smooth_move_to_marker(marker: Marker2D, is_upward: bool) -> void:
	print("Nataly: Smooth moving to marker at ", marker.global_position, " (upward: ", is_upward, ")")
	
	# Phase 1: Chase horizontally to get under/over the marker
	var horizontal_target = marker.global_position.x
	var reached_horizontally = false
	var horizontal_timeout = 3.0  # Max time to reach horizontally
	var horizontal_start_time = Time.get_ticks_msec() / 1000.0
	
	print("Nataly: Phase 1 - Moving horizontally to X: ", horizontal_target)
	
	# First, move to get aligned with the marker
	while not reached_horizontally and not dead and not taking_damage:
		var current_time = Time.get_ticks_msec() / 1000.0
		if current_time - horizontal_start_time > horizontal_timeout:
			print("Nataly: Horizontal movement timeout")
			break
		
		var dx = horizontal_target - global_position.x
		var horizontal_dir = sign(dx) if dx != 0 else dir.x
		
		# Update direction
		if horizontal_dir != 0:
			dir.x = horizontal_dir
			sprite.flip_h = horizontal_dir < 0
		
		# Move horizontally
		velocity.x = horizontal_dir * base_speed * 0.8  * Global.global_time_scale# Slightly slower when positioning
		
		# Apply gravity if we're on ground
		if not is_on_floor():
			velocity.y += gravity * get_process_delta_time()
		
		# Play run animation
		if abs(velocity.x) > 0.1:
			current_animation = "run"
			if animation_player.current_animation != current_animation:
				animation_player.play(current_animation)
		
		await get_tree().process_frame
		
		# Check if we've reached the horizontal position
		if abs(dx) < 10.0:  # Increased tolerance for Nataly
			reached_horizontally = true
			velocity.x = 0
			print("Nataly: Reached horizontal position")
	
	# Stop movement before teleport
	velocity = Vector2.ZERO
	
	# Phase 2: Teleport (with jump animation)
	if is_upward:
		print("Nataly: Phase 2 - Jumping/Teleporting upward")
		
		# Play jump animation
		if animation_player.has_animation("jump"):
			animation_player.play("jump")
			is_dealing_damage = true
			
			# Wait for jump animation midpoint
			await get_tree().create_timer(0.15/Global.global_time_scale).timeout
			
			# Teleport to marker position during jump
			global_position = marker.global_position
			
			# Wait for jump animation to complete
			await animation_player.animation_finished
			
			is_dealing_damage = false
		else:
			# No jump animation, just teleport
			global_position = marker.global_position
		
		print("Nataly: Teleported to marker position")
	else:
		# For downward movement, we can walk off and teleport
		print("Nataly: Phase 2 - Teleporting downward")
		
		# Play jump animation for downward teleport too
		if animation_player.has_animation("jump"):
			animation_player.play("jump")
			is_dealing_damage = true
			
			# Wait briefly then teleport
			await get_tree().create_timer(0.1/Global.global_time_scale).timeout
			global_position = marker.global_position
			
			# Wait for animation to complete
			await animation_player.animation_finished
			
			is_dealing_damage = false
		else:
			global_position = marker.global_position
	
	# Face player after teleport
	if player:
		dir.x = sign(player.global_position.x - global_position.x)
		sprite.flip_h = dir.x < 0
	
	# Reset and idle
	velocity = Vector2.ZERO
	current_animation = "idle"
	animation_player.play("idle")
	
	print("Nataly: Successfully reached marker at ", global_position)
	
	# Brief pause before continuing normal behavior
	await get_tree().create_timer(0.3/Global.global_time_scale).timeout

# -------------------------------------------------
# ATTACK SYSTEM (unchanged except for animation updates)
# -------------------------------------------------
func start_attack():
	# Don't start new attack during combo or special states
	if is_in_combo or is_dealing_damage or is_preparing_attack or not can_attack or is_moving_to_platform:
		return
	
	super.start_attack()

func _execute_attack_after_delay():
	# Override to use Nataly's combo system
	if is_in_combo:
		_execute_next_combo_step()
	else:
		_start_new_combo()

func _start_new_combo():
	# Start a new combo pattern
	is_in_combo = true
	combo_count = 0
	current_pattern_index = randi() % combo_patterns.size()
	pattern_step = 0
	combo_timer = combo_window
	
	print("Nataly: Starting new combo pattern ", current_pattern_index)
	
	# Execute first step
	_execute_next_combo_step()

func _execute_next_combo_step():
	if pattern_step >= combo_patterns[current_pattern_index].size():
		# Combo finished
		reset_combo()
		return
	
	var attack_type = combo_patterns[current_pattern_index][pattern_step]
	pattern_step += 1
	combo_count += 1
	combo_timer = combo_window  # Reset timer for next attack
	
	# Check if this is the final attack in the combo
	final_combo_attack = (pattern_step >= combo_patterns[current_pattern_index].size())
	
	match attack_type:
		"slash":
			_execute_slash_attack()
		"slash_2":
			_execute_slash_2_attack()
		"combo":
			_execute_combo_attack()
		_:
			_execute_slash_attack()

func reset_combo():
	is_in_combo = false
	combo_count = 0
	pattern_step = 0
	final_combo_attack = false
	can_attack = true
	is_dealing_damage = false
	
	# Start cooldown before next combo
	attack_cooldown_timer.start(attack_cooldown * 0.5)  # Shorter cooldown between combos
	
	print("Nataly: Combo finished")

func _execute_slash_attack():
	is_dealing_damage = true
	can_attack = false
	
	print("Nataly: Slash attack! (Combo: ", combo_count, ")")
	
	# Face player
	if player:
		dir.x = sign(player.global_position.x - global_position.x)
		sprite.flip_h = dir.x < 0
	
	# Play slash animation
	animation_player.play("slash")
	
	# Enable hitbox after delay
	await get_tree().create_timer(0.15/Global.global_time_scale).timeout
	if melee_hitbox:
		melee_hitbox.monitoring = true
	
	# Deal damage
	await get_tree().create_timer(0.1/Global.global_time_scale).timeout
	if melee_hitbox and player and global_position.distance_to(player.global_position) <= melee_range:
		var knockback_dir = (player.global_position - global_position).normalized()
		Global.enemyAknockback = knockback_dir * knockback_force
		player.take_damage(slash_damage)
		print("Nataly dealt slash damage: ", slash_damage)
	
	# Disable hitbox
	await get_tree().create_timer(0.15/Global.global_time_scale).timeout
	if melee_hitbox:
		melee_hitbox.monitoring = false
	
	# Wait for animation to complete
	await animation_player.animation_finished
	
	# Reset state and prepare for next attack in combo
	is_dealing_damage = false
	_continue_combo_or_finish()

func _execute_slash_2_attack():
	is_dealing_damage = true
	can_attack = false
	
	print("Nataly: Slash attack! (Combo: ", combo_count, ")")
	
	# Face player
	if player:
		dir.x = sign(player.global_position.x - global_position.x)
		sprite.flip_h = dir.x < 0
	
	# Play slash animation
	animation_player.play("slash_2")
	
	# Enable hitbox after delay
	await get_tree().create_timer(0.15/Global.global_time_scale).timeout
	if melee_hitbox:
		melee_hitbox.monitoring = true
	
	# Deal damage
	await get_tree().create_timer(0.1/Global.global_time_scale).timeout
	if melee_hitbox and player and global_position.distance_to(player.global_position) <= melee_range:
		var knockback_dir = (player.global_position - global_position).normalized()
		Global.enemyAknockback = knockback_dir * knockback_force
		player.take_damage(slash_damage)
		print("Nataly dealt slash damage: ", slash_damage)
	
	# Disable hitbox
	await get_tree().create_timer(0.15/Global.global_time_scale).timeout
	if melee_hitbox:
		melee_hitbox.monitoring = false
	
	# Wait for animation to complete
	await animation_player.animation_finished
	
	# Reset state and prepare for next attack in combo
	is_dealing_damage = false
	_continue_combo_or_finish()
	

func _execute_combo_attack():
	is_dealing_damage = true
	can_attack = false
	
	print("Nataly: COMBO ATTACK! (Combo: ", combo_count, ")")
	
	# Face player
	if player:
		dir.x = sign(player.global_position.x - global_position.x)
		sprite.flip_h = dir.x < 0
	
	# Play combo animation
	animation_player.play("combo")
	
	# Enable AoE hitbox after delay
	await get_tree().create_timer(0.3/Global.global_time_scale).timeout
	if combo_hitbox:
		combo_hitbox.monitoring = true
	
	# Deal AoE damage
	await get_tree().create_timer(0.2/Global.global_time_scale).timeout
	if combo_hitbox and player:
		var distance = global_position.distance_to(player.global_position)
		if distance <= combo_radius:
			var knockback_dir = (player.global_position - global_position).normalized()
			Global.enemyAknockback = knockback_dir * knockback_force * 1.5  # Stronger knockback
			player.take_damage(combo_damage)
			print("Nataly dealt COMBO damage: ", combo_damage)
	
	# Disable hitbox
	await get_tree().create_timer(0.2/Global.global_time_scale).timeout
	if combo_hitbox:
		combo_hitbox.monitoring = false
	
	# Wait for animation to complete
	await animation_player.animation_finished
	
	# Reset state
	is_dealing_damage = false
	_continue_combo_or_finish()

func _continue_combo_or_finish():
	if is_in_combo and combo_timer > 0:
		# Continue with next step in combo
		await get_tree().create_timer(0.2/Global.global_time_scale).timeout  # Brief pause between combo steps
		_execute_next_combo_step()
	else:
		# Combo finished or window expired
		reset_combo()
		current_animation = "idle"
		animation_player.play("idle")

# -------------------------------------------------
# ANIMATION HANDLING (updated to include is_moving_to_platform)
# -------------------------------------------------
func handle_animation():
	var new_animation := ""
	
	# Priority list
	if dead:
		new_animation = "die"
	elif taking_damage:
		new_animation = "hurt"
	elif is_dealing_damage:
		# Keep current attack animation
		if animation_player.current_animation in ["slash", "combo", "jump"]:
			return
		else:
			new_animation = "idle"
	elif is_moving_to_platform:
		# Use run animation while moving to platform
		if abs(velocity.x) > 0.1:
			new_animation = "run"
		else:
			new_animation = "idle"
	else:
		# Normal movement animations
		if abs(velocity.x) > 0.1:
			new_animation = "run"
		else:
			new_animation = "idle"
	
	# Update facing direction
	if not dead and not taking_damage:
		if dir.x == -1:
			sprite.flip_h = true
		elif dir.x == 1:
			sprite.flip_h = false
	
	# Play animation if changed
	if new_animation != current_animation:
		current_animation = new_animation
		animation_player.play(new_animation)
		
		# Handle special animation completions
		if new_animation == "hurt":
			await get_tree().create_timer(0.3/Global.global_time_scale).timeout
			taking_damage = false
		elif new_animation == "die":
			await animation_player.animation_finished
			die()

# -------------------------------------------------
# DEATH
# -------------------------------------------------
func die():
	if can_drop_health:
		try_drop_health()
	
	print("NatalyBoss: Died!")
	emit_signal("boss_died")
	queue_free()

# -------------------------------------------------
# OVERRIDE BASE METHODS
# -------------------------------------------------
func execute_attack():
	# Not used - Nataly uses her own combo system
	pass

func execute_melee_attack():
	# Not used - Nataly uses her own combo system
	pass

func execute_ranged_attack():
	# Nataly doesn't use ranged attacks
	pass
