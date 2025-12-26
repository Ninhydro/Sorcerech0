extends BaseEnemy
class_name MayaBoss

signal boss_died

# -------------------------------------------------
# BOSS CONFIG
# -------------------------------------------------
@export var walk_speed := 40.0  # Slower, more stationary
@export var magic_damage := 8
@export var teleport_cooldown_time := 4.0

# Magic attack types
enum MagicAttack {
	SINGLE,
	TRIPLE,
	ARCANE
}
var current_attack_type := MagicAttack.SINGLE
var attack_pattern := [MagicAttack.SINGLE, MagicAttack.SINGLE, MagicAttack.TRIPLE, MagicAttack.ARCANE]
var pattern_index := 0

# -------------------------------------------------
# TELEPORT SYSTEM
# -------------------------------------------------
var teleport_markers: Array[Marker2D] = []
var teleport_cooldown := 0.0
@export var teleport_min_distance := 150.0  # Min distance to consider teleporting
@export var teleport_max_distance := 400.0  # Max distance for teleport

# -------------------------------------------------
# MAGIC ATTACK SETTINGS
# -------------------------------------------------
@export var magic_projectile_scene: PackedScene
@export var triple_shot_spread := 15.0  # Degrees between triple shots
@export var arcane_shots := 5  # Number of arcane shots
@export var arcane_spread := 45.0  # Spread for arcane shots

# -------------------------------------------------
# DEFENSIVE BEHAVIOR
# -------------------------------------------------
var defensive_mode := false
var defensive_timer := 0.0
@export var defensive_duration := 3.0  # How long to stay defensive after teleport
@export var defensive_cooldown := 8.0  # Cooldown before next defensive mode

# -------------------------------------------------
# NODES
# -------------------------------------------------
@onready var magic_spawn := $MagicSpawn if has_node("MagicSpawn") else $Sprite2D
@onready var teleport_markers_group := "maya_teleport_marker"

# Track facing direction for non-bilateral sprite
var is_facing_right := true  # Default facing right

# -------------------------------------------------
# READY & INITIALIZATION
# -------------------------------------------------
func _ready() -> void:
	player = Global.playerBody
	set_meta("boss_id", "maya")
	
	# Get teleport markers
	refresh_teleport_markers()
	
	# Initialize as ranged boss
	_initialize_enemy()
	
	# Start with idle animation (no direction suffix needed)
	animation_player.play("idle")
	
	super._ready()

func _initialize_enemy():
	# Set up BaseEnemy properties
	attack_range = 300.0 
	base_speed = walk_speed
	attack_range = 300.0  # Maya has longer range
	enemy_damage = magic_damage
	health = 150
	health_max = 150
	use_edge_detection = false  # Maya doesn't care about edges as much
	can_drop_health = true
	health_drop_chance = 1.0
	attack_type = AttackType.RANGED
	
	# Load magic projectile if not set
	if not magic_projectile_scene:
		magic_projectile_scene = preload("res://scenes/enemies/Projectile_enemy.tscn")

# -------------------------------------------------
# PROCESS
# -------------------------------------------------
func _process(delta):
	super._process(delta)
	
	# Update teleport cooldown
	if teleport_cooldown > 0:
		teleport_cooldown -= delta * Global.global_time_scale
	
	# Update defensive mode timer
	if defensive_mode:
		defensive_timer -= delta * Global.global_time_scale
		if defensive_timer <= 0:
			defensive_mode = false
			print("Maya: Exiting defensive mode")
	
	# Teleport logic - Maya teleports more frequently when player gets close
	if (player and not dead and not taking_damage and not is_dealing_damage 
		and teleport_cooldown <= 0 and _should_teleport()):
		_execute_teleport()

# -------------------------------------------------
# MOVEMENT OVERRIDE
# -------------------------------------------------
func move(delta):
	if dead or taking_damage or is_dealing_damage or is_preparing_attack:
		super.move(delta)
		return
	
	# Maya prefers to keep distance
	if is_enemy_chase and player:
		is_roaming = false
		
		var to_player = player.global_position - global_position
		var distance = to_player.length()
		
		# Update facing direction without flipping sprite
		is_facing_right = (to_player.x >= 0)
		dir.x = sign(to_player.x)
		
		# Update magic spawn position based on facing
		if magic_spawn:
			magic_spawn.position.x = abs(magic_spawn.position.x) * (1 if is_facing_right else -1)
		
		# If in defensive mode, try to move away
		if defensive_mode:
			if distance < teleport_min_distance:
				# Move away from player
				velocity.x = -dir.x * base_speed * 0.7 * Global.global_time_scale
			else:
				# Just maintain distance
				velocity.x = 0
		else:
			# Normal behavior: maintain optimal range
			if distance > attack_range:
				# Too far - move closer
				velocity.x = dir.x * base_speed * 0.5 * Global.global_time_scale
			elif distance < teleport_min_distance:
				# Too close - consider teleporting or moving away
				velocity.x = -dir.x * base_speed * 0.3 * Global.global_time_scale
			else:
				# Perfect range - stay still and attack
				velocity.x = 0
				
				# Attack if in range and not already attacking
				if distance <= attack_range and can_attack and not is_preparing_attack:
					start_attack()
	else:
		# Use base movement when not chasing
		super.move(delta)

# -------------------------------------------------
# TELEPORT SYSTEM
# -------------------------------------------------
func refresh_teleport_markers():
	# Get all markers in the maya_teleport_marker group
	var marker_nodes = get_tree().get_nodes_in_group(teleport_markers_group)
	teleport_markers = []
	for node in marker_nodes:
		if node is Marker2D and is_instance_valid(node):
			teleport_markers.append(node)
	
	print("Maya: Found ", teleport_markers.size(), " teleport markers")

func _should_teleport() -> bool:
	if not player or teleport_markers.is_empty() or defensive_mode:
		return false
	
	var distance = global_position.distance_to(player.global_position)
	
	# Teleport if:
	# 1. Player is too close (defensive teleport)
	# 2. Health is low (tactical retreat)
	# 3. Random chance (keep player guessing)
	return (distance < teleport_min_distance or 
			health < health_max * 0.3 or 
			randf() < 0.1)

func _execute_teleport():
	if is_dealing_damage or taking_damage:
		return
	
	teleport_cooldown = teleport_cooldown_time
	
	# Find best teleport marker (away from player when defensive, random otherwise)
	var best_marker = null
	var best_score = -INF
	
	var wants_distance = teleport_max_distance  # Default: want to be far from player
	if defensive_mode or health < health_max * 0.5:
		wants_distance = teleport_max_distance  # Stay far away when defensive
	else:
		wants_distance = attack_range * 0.8  # Maintain attack range
	
	for marker in teleport_markers:
		if not is_instance_valid(marker):
			continue
		
		var dist_to_player = marker.global_position.distance_to(player.global_position)
		var dist_to_boss = marker.global_position.distance_to(global_position)
		
		# Score based on desired distance
		var distance_score = 1.0 / (1.0 + abs(dist_to_player - wants_distance))
		var boss_distance_score = dist_to_boss * 0.1  # Slight preference for moving far
		
		var score = distance_score + boss_distance_score
		
		if score > best_score:
			best_score = score
			best_marker = marker
	
	if best_marker:
		print("Maya: Teleporting to new position!")
		
		# Enter defensive mode after teleport
		defensive_mode = true
		defensive_timer = defensive_duration
		
		# Play teleport_out animation
		_play_animation_with_direction("teleport_out")
		is_dealing_damage = true
		
		# Store current position
		var start_pos = global_position
		var end_pos = best_marker.global_position
		
		# Determine facing direction for destination
		var to_player_at_dest = player.global_position - end_pos
		var will_face_right_at_dest = (to_player_at_dest.x >= 0)
		
		# Wait for teleport_out animation to complete
		await animation_player.animation_finished
		
		# Update position instantly (actual teleport)
		global_position = end_pos
		
		# Update facing direction for new position
		is_facing_right = will_face_right_at_dest
		dir.x = 1 if is_facing_right else -1
		
		# Update magic spawn position
		if magic_spawn:
			magic_spawn.position.x = abs(magic_spawn.position.x) * (1 if is_facing_right else -1)
		
		# Play teleport_in animation
		_play_animation_with_direction("teleport_in")
		
		# Wait for teleport_in animation to complete
		await animation_player.animation_finished
		
		# Reset state
		is_dealing_damage = false
		_play_animation_with_direction("idle")
		
		print("Maya: Entering defensive mode for ", defensive_duration, " seconds")

# -------------------------------------------------
# ANIMATION HELPERS
# -------------------------------------------------
func _get_animation_with_direction(base_name: String) -> String:
	# For animations that have directional variants
	var directional_animations = ["walk", "magic"]  # Add others if needed
	
	if base_name in directional_animations:
		return base_name + ("2" if not is_facing_right else "")
	else:
		return base_name  # idle, hurt, die, teleport_in, teleport_out don't need direction

func _play_animation_with_direction(animation_name: String):
	var actual_animation = _get_animation_with_direction(animation_name)
	current_animation = actual_animation
	animation_player.play(actual_animation)

# -------------------------------------------------
# ATTACK SYSTEM
# -------------------------------------------------
func start_attack():
	# Don't attack in defensive mode
	if defensive_mode or is_dealing_damage or is_preparing_attack or not can_attack:
		return
	
	super.start_attack()

func _execute_attack_after_delay():
	# Get next attack in pattern
	current_attack_type = attack_pattern[pattern_index]
	pattern_index = (pattern_index + 1) % attack_pattern.size()
	
	# Execute the attack
	match current_attack_type:
		MagicAttack.SINGLE:
			_execute_single_shot()
		MagicAttack.TRIPLE:
			_execute_triple_shot()
		MagicAttack.ARCANE:
			_execute_arcane_shot()
		_:
			_execute_single_shot()

func _execute_single_shot():
	is_dealing_damage = true
	can_attack = false
	
	print("Maya: Single magic shot!")
	
	# Update facing direction before attack
	if player:
		is_facing_right = (player.global_position.x - global_position.x) >= 0
		dir.x = 1 if is_facing_right else -1
		if magic_spawn:
			magic_spawn.position.x = abs(magic_spawn.position.x) * (1 if is_facing_right else -1)
	
	# Play magic animation with correct direction
	_play_animation_with_direction("magic")
	
	# Fire projectile after delay
	await get_tree().create_timer(0.3/Global.global_time_scale).timeout
	
	if not player or dead:
		is_dealing_damage = false
		_play_animation_with_direction("idle")
		return
	
	# Create single projectile
	var projectile = magic_projectile_scene.instantiate()
	get_tree().current_scene.add_child(projectile)
	
	var spawn_pos = magic_spawn.global_position if magic_spawn else global_position
	projectile.global_position = spawn_pos
	
	# Aim directly at player
	var to_player = (player.global_position - spawn_pos).normalized()
	
	# Set projectile properties
	if projectile.has_method("set_direction"):
		projectile.set_direction(to_player)
	if "speed" in projectile:
		projectile.speed = 180.0
	if "damage" in projectile:
		projectile.damage = magic_damage
	if "lifetime" in projectile:
		projectile.lifetime = 3.0
	
	# Wait for animation to complete
	await animation_player.animation_finished
	
	# Reset state
	is_dealing_damage = false
	
	# Start cooldown
	attack_cooldown_timer.start(attack_cooldown)
	
	# Return to idle
	_play_animation_with_direction("idle")

func _execute_triple_shot():
	is_dealing_damage = true
	can_attack = false
	
	print("Maya: Triple magic shot!")
	
	# Update facing direction before attack
	if player:
		is_facing_right = (player.global_position.x - global_position.x) >= 0
		dir.x = 1 if is_facing_right else -1
		if magic_spawn:
			magic_spawn.position.x = abs(magic_spawn.position.x) * (1 if is_facing_right else -1)
	
	# Play magic animation with correct direction
	_play_animation_with_direction("magic")
	
	# Fire projectiles after delay
	await get_tree().create_timer(0.3/Global.global_time_scale).timeout
	
	if not player or dead:
		is_dealing_damage = false
		_play_animation_with_direction("idle")
		return
	
	var spawn_pos = magic_spawn.global_position if magic_spawn else global_position
	var to_player = (player.global_position - spawn_pos).normalized()
	
	# Fire three shots with spread
	for i in range(3):
		var projectile = magic_projectile_scene.instantiate()
		get_tree().current_scene.add_child(projectile)
		projectile.global_position = spawn_pos
		
		# Calculate spread angle
		var spread_angle = deg_to_rad(triple_shot_spread * (i - 1))  # -15°, 0°, +15°
		var direction = to_player.rotated(spread_angle)
		
		# Set projectile properties
		if projectile.has_method("set_direction"):
			projectile.set_direction(direction)
		if "speed" in projectile:
			projectile.speed = 160.0
		if "damage" in projectile:
			projectile.damage = magic_damage * 0.8  # Slightly less damage per shot
		if "lifetime" in projectile:
			projectile.lifetime = 3.0
		
		# Small delay between shots
		await get_tree().create_timer(0.1/Global.global_time_scale).timeout
	
	# Wait for animation to complete
	await animation_player.animation_finished
	
	# Reset state
	is_dealing_damage = false
	
	# Longer cooldown for powerful attack
	attack_cooldown_timer.start(attack_cooldown * 1.5)
	
	# Return to idle
	_play_animation_with_direction("idle")

func _execute_arcane_shot():
	is_dealing_damage = true
	can_attack = false
	
	print("Maya: Arcane barrage!")
	
	# Update facing direction before attack
	if player:
		is_facing_right = (player.global_position.x - global_position.x) >= 0
		dir.x = 1 if is_facing_right else -1
		if magic_spawn:
			magic_spawn.position.x = abs(magic_spawn.position.x) * (1 if is_facing_right else -1)
	
	# Play magic animation (longer for arcane) with correct direction
	_play_animation_with_direction("magic")
	
	# Fire arcane shots after delay
	await get_tree().create_timer(0.4/Global.global_time_scale).timeout
	
	if not player or dead:
		is_dealing_damage = false
		_play_animation_with_direction("idle")
		return
	
	var spawn_pos = magic_spawn.global_position if magic_spawn else global_position
	var base_direction = Vector2.RIGHT if is_facing_right else Vector2.LEFT
	
	# Fire multiple shots in an arc
	for i in range(arcane_shots):
		var projectile = magic_projectile_scene.instantiate()
		get_tree().current_scene.add_child(projectile)
		projectile.global_position = spawn_pos
		
		# Calculate arc spread
		var angle = deg_to_rad(arcane_spread * (i / float(arcane_shots - 1) - 0.5))
		var direction = base_direction.rotated(angle)
		
		# Set projectile properties
		if projectile.has_method("set_direction"):
			projectile.set_direction(direction)
		if "speed" in projectile:
			projectile.speed = 140.0
		if "damage" in projectile:
			projectile.damage = magic_damage * 0.6  # Less damage per shot
		if "lifetime" in projectile:
			projectile.lifetime = 2.5
		
		# Small delay between shots
		await get_tree().create_timer(0.08).timeout
	
	# Wait for animation to complete
	await animation_player.animation_finished
	
	# Reset state
	is_dealing_damage = false
	
	# Long cooldown for ultimate attack
	attack_cooldown_timer.start(attack_cooldown * 2.0)
	
	# Return to idle
	_play_animation_with_direction("idle")

# -------------------------------------------------
# ANIMATION HANDLING
# -------------------------------------------------
func handle_animation():
	var new_animation := ""
	
	# Maya has priority for her special animations
	if dead:
		new_animation = "die"
	elif taking_damage:
		new_animation = "hurt"
	elif is_dealing_damage:
		# Keep current attack animation
		if animation_player.current_animation in ["magic", "magic2", "teleport_in", "teleport_out"]:
			return
		else:
			new_animation = "idle"
	else:
		# Normal movement animations
		if abs(velocity.x) > 0.1:
			new_animation = "walk"  # Will be converted to walk/walk2
		else:
			new_animation = "idle"
	
	# Convert to directional animation if needed
	var actual_animation = _get_animation_with_direction(new_animation)
	
	# Play animation if changed
	if actual_animation != current_animation:
		current_animation = actual_animation
		animation_player.play(actual_animation)
		
		# Handle special animation completions
		if new_animation == "hurt":
			await get_tree().create_timer(0.3/Global.global_time_scale).timeout
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
	if can_drop_health:
		try_drop_health()
	
	print("MayaBoss: Died!")
	emit_signal("boss_died")
	queue_free()

# -------------------------------------------------
# OVERRIDE BASE METHODS
# -------------------------------------------------
func execute_attack():
	# Not used - Maya uses her own magic system
	pass

func execute_melee_attack():
	# Maya doesn't use melee attacks
	pass

func execute_ranged_attack():
	# Not used - Maya uses her own magic system
	pass
