extends BaseEnemy
class_name LuxBoss

signal boss_died

# -------------------------------------------------
# BOSS CONFIG
# -------------------------------------------------
@export var walk_speed := 50.0
@export var melee_range := 60.0
@export var melee_damage := 14
@export var rocket_damage := 20
@export var chase_range := 400.0  # NEW: How far the boss will chase the player
@export var min_chase_distance := 80.0  # NEW: Minimum distance before stopping chase

# -------------------------------------------------
# SHIELD CONFIG
# -------------------------------------------------
@export var shield_health := 80
@export var shield_active := false
@export var shield_activate_delay := 0.3
@export var shield_auto_disable_time := 10.0

var current_shield_health: float
var has_taken_first_hit := false
var shield_activation_timer := 0.0
var shield_idle_timer := 0.0
var last_hit_time := 0.0

# -------------------------------------------------
# BOSS-SPECIFIC FEATURES
# -------------------------------------------------
var boss_attacking := false  # Renamed to avoid conflict
var can_fire_rocket := true
var rocket_cooldown_timer := 0.0
var rocket_attack_cooldown := 8.0
var rocket_windup_time := 0.8
var rocket_scene: PackedScene
@export var boss_rocket_scene: PackedScene

# Jump/Teleport system
var jump_markers: Array[Marker2D] = []
@export var jump_trigger_range := 100.0
@export var jump_duration := 0.35
var teleport_cooldown := 0.0  # NEW: Cooldown between teleports
@export var teleport_cooldown_time := 3.0  # NEW: How long to wait between teleports
# -------------------------------------------------
# NODES
# -------------------------------------------------
@onready var shield_sprite := $ShieldSprite
@onready var rocket_spawn := $RocketSpawn if has_node("RocketSpawn") else $Sprite2D
@onready var melee_hitbox: Area2D = $MeleeHitbox if has_node("MeleeHitbox") else null

var marker_refresh_timer := 0.0
@export var marker_refresh_interval := 1.0  # Refresh markers every 1 second



# -------------------------------------------------
# READY & INITIALIZATION
# -------------------------------------------------
func _ready() -> void:

	player = Global.playerBody
	
	# Get all jump markers in the scene
	var jump_marker_nodes = get_tree().get_nodes_in_group("lux_jump_marker")
	jump_markers = []
	for node in jump_marker_nodes:
		if node is Marker2D:
			jump_markers.append(node)
	
	# Initialize shield
	current_shield_health = shield_health
	update_shield_visual()
	
	# Disable melee hitbox by default
	if melee_hitbox:
		melee_hitbox.monitoring = false
	
	# Set up rocket scene
	rocket_scene = boss_rocket_scene if boss_rocket_scene else preload("res://scenes/enemies/Projectile_enemy.tscn")
	
	# Start with idle animation
	animation_player.play("idle")
	
	super._ready()
	
func _initialize_enemy():
	# Set up BaseEnemy properties for boss
	base_speed = walk_speed
	attack_range = melee_range
	enemy_damage = melee_damage
	health = 280
	health_max = 280
	use_edge_detection = true
	can_drop_health = false
	attack_type = AttackType.MELEE
	
	# Initialize shield
	current_shield_health = shield_health
	update_shield_visual()

# -------------------------------------------------
# PROCESS
# -------------------------------------------------
func _process(delta):
	super._process(delta)
	
	# Update teleport cooldown
	if teleport_cooldown > 0:
		teleport_cooldown -= delta * Global.global_time_scale
		if Engine.get_process_frames() % 60 == 0:  # Print every second at 60 FPS
			print("LuxBoss: Teleport cooldown: ", teleport_cooldown)
	
	# Periodically refresh jump markers
	marker_refresh_timer -= delta
	if marker_refresh_timer <= 0:
		marker_refresh_timer = marker_refresh_interval
		refresh_jump_markers()
		
	# SAFETY CHECK: Reset boss_attacking if animation is done but state is stuck
	if boss_attacking and not animation_player.is_playing():
		var current_anim = animation_player.current_animation
		if current_anim not in ["melee", "rocket", "jump"]:
			print("LuxBoss: Safety reset - boss_attacking stuck true but no attack animation playing")
			boss_attacking = false
	
	# Handle shield activation delay
	if has_taken_first_hit and not shield_active and shield_activation_timer > 0:
		shield_activation_timer -= delta * Global.global_time_scale
		if shield_activation_timer <= 0:
			activate_shield()
	
	# Handle shield auto-disable timer
	if shield_active:
		shield_idle_timer += delta * Global.global_time_scale
		if shield_idle_timer >= shield_auto_disable_time:
			reset_shield()
			print("LuxBoss: Shield automatically disabled after ", shield_auto_disable_time, " seconds")
	
	# Handle rocket cooldown
	if not can_fire_rocket:
		rocket_cooldown_timer -= delta * Global.global_time_scale
		if rocket_cooldown_timer <= 0:
			can_fire_rocket = true
	
	# Random rocket attack - MORE FREQUENT
	if (can_fire_rocket and player and is_instance_valid(player) and not dead and not taking_damage 
		and not shield_active and not boss_attacking and not is_dealing_damage):
		var distance = global_position.distance_to(player.global_position)
		# Increased chance for rocket attack
		if distance > melee_range and distance < chase_range and randf() < 0.02:
			_start_rocket_attack()
# -------------------------------------------------
# SHIELD SYSTEM
# -------------------------------------------------
func take_damage(damage):
	# Update last hit time
	last_hit_time = Time.get_ticks_msec() / 1000.0
	
	# Reset shield idle timer when taking damage
	if shield_active:
		shield_idle_timer = 0.0
		print("LuxBoss Shield idle timer reset due to damage")

	# Check if this is the first hit
	if not has_taken_first_hit:
		has_taken_first_hit = true
		shield_activation_timer = shield_activate_delay
		print("LuxBoss First hit! Shield will activate in ", shield_activate_delay, " seconds")
		
		# Take normal damage on first hit
		super.take_damage(damage)
		
	elif shield_active and current_shield_health > 0:
		# Shield takes damage
		current_shield_health -= damage
		taking_damage = true
		
		print("LuxBoss Shield took damage: ", damage, " Shield health: ", current_shield_health)
		
		# Shield hit effect
		if shield_sprite:
			shield_sprite.modulate = Color(1.0, 0.5, 0.5, 0.7)
			await get_tree().create_timer(0.1).timeout
			update_shield_visual()
		
		taking_damage = false
		
		if current_shield_health <= 0:
			current_shield_health = 0
			deactivate_shield()
			print("LuxBoss Shield broken!")
	else:
		# Take normal damage when shield is broken or not active
		super.take_damage(damage)

func activate_shield():
	shield_active = true
	shield_idle_timer = 0.0
	print("LuxBoss Shield activated!")
	
	# Update shield visual
	update_shield_visual()
	
	# Stop moving when shield is active
	base_speed = 0
	velocity.x = 0
	
	# Reset attack states
	boss_attacking = false
	
	# Update animation immediately
	handle_animation()

func deactivate_shield():
	shield_active = false
	print("LuxBoss Shield broken!")
	
	# Resume movement (slower after shield breaks)
	base_speed = walk_speed * 0.5
	
	# Reset attack cooldowns so boss can attack again
	can_attack = true
	boss_attacking = false
	
	# Update shield visual
	update_shield_visual()
	
	# Update animation immediately
	handle_animation()

func reset_shield():
	shield_active = false
	has_taken_first_hit = false
	current_shield_health = shield_health
	shield_idle_timer = 0.0
	
	print("LuxBoss Shield reset - ready to activate again on next hit")
	
	# Resume normal movement speed
	base_speed = walk_speed
	
	# Reset attack states
	can_attack = true
	boss_attacking = false
	
	# Update shield visual
	update_shield_visual()
	
	# Update animation immediately
	handle_animation()

func update_shield_visual():
	if shield_sprite:
		if shield_active:
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

# -------------------------------------------------
# MOVEMENT
# -------------------------------------------------
func move(delta):
	# If shield is active or boss is attacking, don't move
	if shield_active or boss_attacking:
		velocity.x = 0
		is_roaming = false
		print("LuxBoss: Not moving (shield/attack state)")
		return
	
	# Check for teleport jump (with cooldown check)
	if not boss_attacking and teleport_cooldown <= 0 and _should_jump():
		_jump_to_best_marker()
		return
	
	# BOSS-SPECIFIC CHASE LOGIC
	if player and not dead and not taking_damage:
		var distance = global_position.distance_to(player.global_position)
		
		# If player is outside chase range, use base enemy movement
		if distance > chase_range:
			super.move(delta)
			return
		
		# If player is between min_chase_distance and melee_range, STAY IDLE
		# This is the key fix - prevent glitching in the "medium range"
		if distance > melee_range and distance <= min_chase_distance:
			velocity.x = 0
			is_roaming = false
			
			# Still face the player
			var dx = player.global_position.x - global_position.x
			dir.x = sign(dx)
			
			if Engine.get_process_frames() % 60 == 0:
				print("LuxBoss: In medium range - staying idle | Distance: ", distance)
			
			return
		
		# If player is within chase range but outside min_chase_distance, chase them
		if distance > min_chase_distance and distance <= chase_range:
			# Face player
			var dx = player.global_position.x - global_position.x
			dir.x = sign(dx)
			
			# Move toward player
			velocity.x = dir.x * base_speed
			is_roaming = false
			
			# Debug
			if Engine.get_process_frames() % 60 == 0:
				print("LuxBoss: Chasing | Distance: ", distance, " | Velocity.x: ", velocity.x, " | Speed: ", base_speed)
			
			return
		# If player is too close (within melee range), back up a bit
		elif distance <= melee_range:
			var dx = player.global_position.x - global_position.x
			dir.x = -sign(dx)  # Move away from player
			velocity.x = dir.x * base_speed * 0.5  # Slower when backing up
			is_roaming = false
			
			if Engine.get_process_frames() % 60 == 0:
				print("LuxBoss: Backing up | Distance: ", distance, " | Velocity.x: ", velocity.x)
			
			return
	
	# If no conditions met, use base enemy movement
	super.move(delta)

# -------------------------------------------------
# BOSS-SPECIFIC ATTACKS
# -------------------------------------------------
func start_attack():
	# Can't attack while shield is active or already attacking
	if shield_active or boss_attacking or is_dealing_damage:
		return
	
	if can_attack and player and not dead and not taking_damage:
		var distance = global_position.distance_to(player.global_position)
		
		# Melee attack when close - HIGHER PRIORITY
		if distance <= melee_range:
			_do_melee_attack()
		# Rocket attack when at medium range
		elif distance <= chase_range and can_fire_rocket:
			# 30% chance for rocket when in range (reduced from 50%)
			if randf() < 0.3:
				_start_rocket_attack()

func _do_melee_attack():
	if boss_attacking:
		return
	
	boss_attacking = true
	is_dealing_damage = true
	can_attack = false
	
	print("LuxBoss: Melee attack!")
	
	# Face player
	if player:
		dir.x = sign(player.global_position.x - global_position.x)
		sprite.flip_h = dir.x < 0
		# Update rocket spawn position
		if rocket_spawn:
			rocket_spawn.position.x = abs(rocket_spawn.position.x) * dir.x
	
	# Play melee animation
	animation_player.play("melee")
	
	# Enable hitbox after delay
	await get_tree().create_timer(0.2).timeout
	if melee_hitbox:
		melee_hitbox.monitoring = true
	
	# Deal damage
	await get_tree().create_timer(0.1).timeout
	if player and global_position.distance_to(player.global_position) <= melee_range:
		var knockback_dir = (player.global_position - global_position).normalized()
		Global.enemyAknockback = knockback_dir * knockback_force
		player.take_damage(melee_damage)
		print("LuxBoss dealt melee damage: ", melee_damage)
	
	# Disable hitbox after short time
	await get_tree().create_timer(0.15).timeout
	if melee_hitbox:
		melee_hitbox.monitoring = false
	
	# Finish attack
	await animation_player.animation_finished
	
	# RESET STATES IMMEDIATELY
	boss_attacking = false
	is_dealing_damage = false
	
	# Force animation update
	handle_animation()
	
	# Start cooldown
	attack_cooldown_timer.start(attack_cooldown)


func _start_rocket_attack():
	if boss_attacking or not can_fire_rocket:
		return
	
	boss_attacking = true
	can_fire_rocket = false
	is_roaming = false
	
	print("LuxBoss: Rocket attack!")
	
	# Face player before attacking
	if player:
		var dx = player.global_position.x - global_position.x
		dir.x = sign(dx)
		sprite.flip_h = dir.x < 0
		# Update rocket spawn position
		if rocket_spawn:
			rocket_spawn.position.x = abs(rocket_spawn.position.x) * dir.x
	
	# Play rocket animation
	animation_player.play("rocket")
	
	# Windup time
	await get_tree().create_timer(rocket_windup_time).timeout
	
	if not player or dead:
		boss_attacking = false
		animation_player.play("idle")
		return
	
	# Fire rocket
	_fire_single_rocket()
	
	# Return to idle
	animation_player.play("idle")
	
	# RESET STATES IMMEDIATELY
	boss_attacking = false
	is_roaming = true
	
	# Force animation update
	handle_animation()
	
	# Cooldown
	rocket_cooldown_timer = rocket_attack_cooldown

func _fire_single_rocket():
	if rocket_scene and player:
		var rocket = rocket_scene.instantiate()
		get_tree().current_scene.add_child(rocket)
		
		var spawn_pos = rocket_spawn.global_position if rocket_spawn else global_position
		rocket.global_position = spawn_pos
		
		# Set rocket properties
		if rocket.has_method("set_target"):
			rocket.set_target(player)
		if rocket.has_method("set_initial_direction"):
			# Calculate direction from spawn position to player
			var to_player = player.global_position - spawn_pos
			
			# Give it a slight upward angle (adjust -0.2 for more/less upward angle)
			# This makes it go up first, then curve toward player
			var initial_dir = to_player.normalized()
			initial_dir.y -= 0.2  # Add upward bias
			initial_dir = initial_dir.normalized()
			
			rocket.set_initial_direction(initial_dir)
		
		# Set speed and damage if available
		if "speed" in rocket:
			rocket.speed = 200.0
		if "turn_rate" in rocket:
			rocket.turn_rate = 1.5  # Lower turn rate for more arcing motion
		if "damage" in rocket:
			rocket.damage = rocket_damage
		if "lifetime" in rocket:
			rocket.lifetime = 4.0  # Longer lifetime for arcing rockets

# -------------------------------------------------
# TELEPORT JUMP SYSTEM
# -------------------------------------------------
func _should_jump() -> bool:
	if not player or not is_instance_valid(player):
		return false
	
	# Clean up invalid markers first
	cleanup_jump_markers()
	
	if jump_markers.is_empty():
		print("LuxBoss DEBUG: No jump markers available (empty array)")
		return false
	
	if boss_attacking:
		print("LuxBoss DEBUG: Can't jump - boss is attacking")
		return false
	
	# Don't teleport if on cooldown
	if teleport_cooldown > 0:
		print("LuxBoss DEBUG: Can't jump - teleport cooldown: ", teleport_cooldown)
		return false
	
	# Only jump when player is within trigger range AND boss is too far for melee
	var distance_to_player = global_position.distance_to(player.global_position)
	
	print("LuxBoss DEBUG: Checking jump - distance to player: ", distance_to_player, 
		  " | melee_range: ", melee_range, " | condition: distance > 200 (", distance_to_player > 200, 
		  ") OR distance <= melee_range (", distance_to_player <= melee_range, ")")
	
	# Only teleport if player is far enough away (outside easy chase range)
	if distance_to_player > 200 or distance_to_player <= melee_range:
		print("LuxBoss DEBUG: Distance condition failed - won't teleport")
		return false
	
	print("LuxBoss DEBUG: Distance OK, checking ", jump_markers.size(), " markers...")
	
	# Check if player is near any jump marker AND boss is not already near that marker
	for i in range(jump_markers.size()):
		var marker = jump_markers[i]
		# Check if marker is still valid
		if not is_instance_valid(marker):
			print("LuxBoss DEBUG: Marker ", i, " is invalid")
			continue
		
		var distance_to_marker = marker.global_position.distance_to(player.global_position)
		var boss_to_marker = marker.global_position.distance_to(global_position)
		
		print("LuxBoss DEBUG: Marker ", i, " - player distance: ", distance_to_marker, 
			  " (needs < 120) | boss distance: ", boss_to_marker, " (needs > 50)")
		
		# Only teleport if:
		# 1. Player is near marker (within 120 pixels)
		# 2. Boss is NOT already near that marker (more than 50 pixels away)
		# 3. Teleporting would actually get boss closer to player
		if (distance_to_marker < 120 and 
			boss_to_marker > 50 and
			boss_to_marker > distance_to_marker):
			print("LuxBoss DEBUG: ✓ Found valid marker at index ", i)
			return true
		else:
			print("LuxBoss DEBUG: ✗ Marker ", i, " failed: ", 
				  "player_near=", distance_to_marker < 120,
				  " boss_far=", boss_to_marker > 50,
				  " gets_closer=", boss_to_marker > distance_to_marker)
	
	print("LuxBoss DEBUG: No valid markers found")
	return false


func _jump_to_best_marker():
	if boss_attacking:
		return
	
	boss_attacking = true
	velocity = Vector2.ZERO
	is_roaming = false
	
	# Find the best marker (closest to player but not too close to boss)
	var best_marker: Marker2D = null
	var best_score = -INF
	
	# Clean up invalid markers first
	cleanup_jump_markers()
	
	for marker in jump_markers:
		# Check if marker is still valid
		if not is_instance_valid(marker):
			continue
		
		var distance_to_player = marker.global_position.distance_to(player.global_position)
		var distance_to_boss = marker.global_position.distance_to(global_position)
		
		# Only consider markers that are:
		# 1. Close to player (within 120 pixels)
		# 2. Not too close to boss (more than 50 pixels away)
		# 3. Actually move boss closer to player
		if distance_to_player < 120 and distance_to_boss > 50:
			# Score based on how close to player and how far from boss
			var score = (200 - distance_to_player) + (distance_to_boss * 0.5)
			if score > best_score:
				best_score = score
				best_marker = marker
	
	if not best_marker:
		boss_attacking = false
		return
	
	print("LuxBoss: Teleporting to marker near player!")
	
	# Set teleport cooldown
	teleport_cooldown = teleport_cooldown_time
	
	# Face destination
	var dx = best_marker.global_position.x - global_position.x
	dir.x = sign(dx)
	sprite.flip_h = dir.x < 0
	if shield_sprite:
		shield_sprite.flip_h = sprite.flip_h
	# Update rocket spawn position
	if rocket_spawn:
		rocket_spawn.position.x = abs(rocket_spawn.position.x) * dir.x
	
	# Play jump animation
	animation_player.play("jump")
	
	# Disable collisions during teleport
	collision_layer = 0
	collision_mask = 0
	
	# Smooth teleport animation
	var start = global_position
	var end = best_marker.global_position
	var t = 0.0
	
	while t < jump_duration:
		t += get_process_delta_time()
		global_position = start.lerp(end, t / jump_duration)
		await get_tree().process_frame
	
	global_position = end
	
	# Restore collision
	collision_layer = 3
	collision_mask = 3
	
	# RESET STATES IMMEDIATELY
	boss_attacking = false
	is_roaming = true
	
	# Force animation update
	handle_animation()
	
	# Debug: Log teleport completion
	print("LuxBoss: Teleport complete! Cooldown: ", teleport_cooldown_time, " seconds")

# Add this helper function to clean up invalid markers
func cleanup_jump_markers():
	var valid_markers: Array[Marker2D] = []
	for marker in jump_markers:
		if is_instance_valid(marker):
			valid_markers.append(marker)
	jump_markers = valid_markers
	
func refresh_jump_markers():
	# Get all jump markers currently in the scene
	var jump_marker_nodes = get_tree().get_nodes_in_group("lux_jump_marker")
	var new_markers: Array[Marker2D] = []
	
	for node in jump_marker_nodes:
		if node is Marker2D and is_instance_valid(node):
			new_markers.append(node)
	
	jump_markers = new_markers
	print("LuxBoss: Refreshed jump markers - found ", jump_markers.size(), " markers")
	
	# If we have no markers, print a warning
	if jump_markers.is_empty():
		print("LuxBoss WARNING: No jump markers found in scene! Make sure platforms have markers in 'lux_jump_marker' group.")
		
# -------------------------------------------------
# ANIMATION HANDLING
# -------------------------------------------------
func handle_animation():
	var new_animation := ""
	
	# Priority list (from highest to lowest)
	if dead:
		new_animation = "die"
	elif taking_damage:
		new_animation = "hurt"
	elif shield_active:
		new_animation = "shield"
	elif boss_attacking or is_dealing_damage:
		# Keep attack animations ONLY if currently playing one
		if animation_player.current_animation in ["melee", "rocket", "jump"]:
			return  # Let attack animation continue
		else:
			# Attack state but no attack animation playing - check movement
			if abs(velocity.x) > 0.1:
				new_animation = "walk"
			else:
				new_animation = "idle"
	else:
		# NORMAL STATE: Walk if moving, idle if not
		if abs(velocity.x) > 0.1:  # Any movement at all
			new_animation = "walk"
		else:
			new_animation = "idle"
	
	# Update facing direction when not in special states
	if not dead and not taking_damage:
		if dir.x == -1:
			sprite.flip_h = true
			if shield_sprite:
				shield_sprite.flip_h = true
			if rocket_spawn:
				rocket_spawn.position.x = -abs(rocket_spawn.position.x)
		elif dir.x == 1:
			sprite.flip_h = false
			if shield_sprite:
				shield_sprite.flip_h = false
			if rocket_spawn:
				rocket_spawn.position.x = abs(rocket_spawn.position.x)
	
	# Only change animation if different
	if new_animation != current_animation:
		current_animation = new_animation
		animation_player.play(new_animation)
		
		# Handle special animation completions
		if new_animation == "hurt":
			await get_tree().create_timer(0.5).timeout
			taking_damage = false
			# Force animation update after hurt
			handle_animation()
		elif new_animation == "die":
			await animation_player.animation_finished
			die()


# -------------------------------------------------
# DEATH
# -------------------------------------------------
func die():
	if can_drop_health and health_drop_scene:
		try_drop_health()
	
	print("LuxBoss: Died!")
	emit_signal("boss_died")
	queue_free()

# -------------------------------------------------
# OVERRIDE BASE ENEMY METHODS - FIXED
# -------------------------------------------------
func execute_attack():
	# Override to use boss-specific attacks
	# Call boss attack system
	start_attack()

func _on_attack_cooldown_timeout():
	# Override to also reset boss_attacking
	super._on_attack_cooldown_timeout()
	boss_attacking = false

func _on_hit_stun_timeout():
	# Override to also reset boss_attacking
	super._on_hit_stun_timeout()
	boss_attacking = false

func _on_attack_delay_timeout():
	# Override to also reset boss_attacking
	super._on_attack_delay_timeout()
	boss_attacking = false

# Keep these to satisfy BaseEnemy requirements
func execute_melee_attack():
	pass

func execute_ranged_attack():
	pass

func is_player_in_attack_range() -> bool:
	return super.is_player_in_attack_range()

func player_can_be_targeted() -> bool:
	return super.player_can_be_targeted()

