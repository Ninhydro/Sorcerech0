extends BaseEnemy
class_name MayaBoss

signal boss_died

# -------------------------------------------------
# BOSS CONFIG
# -------------------------------------------------
@export var walk_speed := 40.0
@export var magic_damage := 5
@export var teleport_cooldown_time := 4.0

# Magic attack types
enum MagicAttack {
	SINGLE,
	TRIPLE,
	ARCANE
}
var current_attack_type := MagicAttack.SINGLE
var attack_pattern := [MagicAttack.SINGLE, MagicAttack.TRIPLE, MagicAttack.SINGLE, MagicAttack.ARCANE]
var pattern_index := 0

# -------------------------------------------------
# TELEPORT SYSTEM
# -------------------------------------------------
var teleport_markers: Array[Marker2D] = []
var teleport_cooldown := 0.0
@export var teleport_min_distance := 150.0
@export var teleport_max_distance := 400.0

# -------------------------------------------------
# MAGIC ATTACK SETTINGS
# -------------------------------------------------
@export var magic_projectile_scene: PackedScene
@export var triple_shot_spread := 15.0
@export var arcane_spread := 45.0

# -------------------------------------------------
# DEFENSIVE BEHAVIOR
# -------------------------------------------------
var defensive_mode := false
var defensive_timer := 0.0
@export var defensive_duration := 3.0
@export var defensive_cooldown := 8.0

# -------------------------------------------------
# NODES
# -------------------------------------------------
@onready var magic_spawn := $MagicSpawn if has_node("MagicSpawn") else $Sprite2D
@onready var teleport_markers_group := "maya_teleport_marker"

# Track facing direction for non-bilateral sprite
var is_facing_right := true
var attack_preparation_timer := 0.0

var min_time_between_teleports := 3.0
var time_since_last_teleport := 100.0

var is_teleporting := false
var teleport_target_pos := Vector2.ZERO

@export var arcane_shots := 9
@export var arcane_tired_time := 4.0
var is_tired := false
var tired_timer := 0.0

var force_teleport_on_next_hit := false
var consecutive_hits := 0
@export var max_consecutive_hits_before_teleport := 1

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
	
	# Start with idle animation
	animation_player.play("idle")
	current_animation = "idle"
	
	super._ready()

func _initialize_enemy():
	attack_range = 300.0 
	base_speed = walk_speed
	enemy_damage = magic_damage
	health = 200
	health_max = 200
	use_edge_detection = false
	can_drop_health = true
	health_drop_chance = 1.0
	attack_type = AttackType.RANGED
	
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
	
	time_since_last_teleport += delta * Global.global_time_scale
	
	if is_tired:
		tired_timer -= delta * Global.global_time_scale
		if tired_timer <= 0:
			is_tired = false
			print("Maya: Recovered from tired state")
			
	# Update defensive mode timer
	if defensive_mode:
		defensive_timer -= delta * Global.global_time_scale
		if defensive_timer <= 0:
			defensive_mode = false
			print("Maya: Exiting defensive mode")
	
	if is_preparing_attack:
		attack_preparation_timer += delta
		if attack_preparation_timer > 5.0:
			print("Maya: Resetting stuck attack preparation state")
			is_preparing_attack = false
			attack_preparation_timer = 0.0
	
	# Teleport logic
	if force_teleport_on_next_hit and not is_teleporting and teleport_cooldown <= 0:
		print("Maya: Forced teleport due to consecutive hits!")
		force_teleport_on_next_hit = false
		_execute_teleport()
		return
		
	if not is_tired and (player and not dead and not taking_damage and not is_dealing_damage 
		and not is_teleporting and teleport_cooldown <= 0 and _should_teleport()):
		_execute_teleport()

# -------------------------------------------------
# MOVEMENT OVERRIDE - FIXED
# -------------------------------------------------
func move(delta):
	if dead or taking_damage or is_dealing_damage or is_preparing_attack or is_teleporting or is_tired:
		velocity.x = 0
		# Still call super.move() to apply gravity and collision
		#super.move(delta)
		return
	
	# Maya prefers to keep distance
	if is_enemy_chase and player:
		is_roaming = false
		
		var to_player = player.global_position - global_position
		var distance = to_player.length()
		
		# Update facing direction
		is_facing_right = (to_player.x >= 0)
		dir.x = sign(to_player.x)
		
		# Update magic spawn position based on facing
		if magic_spawn:
			magic_spawn.position.x = abs(magic_spawn.position.x) * (1 if is_facing_right else -1)
		
		# If in defensive mode, try to move away
		if defensive_mode:
			if distance < teleport_min_distance:
				velocity.x = -dir.x * base_speed * 0.7 * Global.global_time_scale
				#velocity.x = 0
			else:
				velocity.x = 0
		else:
			# Normal behavior: maintain optimal range
			if distance > attack_range:
				#velocity.x = 0
				velocity.x = dir.x * base_speed * 0.5 * Global.global_time_scale
			elif distance < teleport_min_distance:
				#velocity.x = 0
				velocity.x = -dir.x * base_speed * 0.3 * Global.global_time_scale
			else:
				velocity.x = 0
				
				# Attack if in range and not already attacking
				if distance <= attack_range and can_attack and not is_preparing_attack and not is_tired:
					start_attack()
	#else:
	#	super.move(delta)

# -------------------------------------------------
# ANIMATION HANDLING - SIMPLIFIED
# -------------------------------------------------
func handle_animation():
	if dead:
		#die()
		if current_animation != "die":
			animation_player.play("die")
			current_animation = "die"
			print("MayaBoss: Playing death animation")
			await animation_player.animation_finished
			die()
		return
	
	if taking_damage:
		if current_animation != "hurt":
			animation_player.play("hurt")
			current_animation = "hurt"
		return
	
	if is_teleporting:
		# Teleport animations are handled separately
		return
	
	if is_dealing_damage:
		# Attack animations are handled in attack methods
		return
	
	if is_tired:
		if current_animation != "idle":
			animation_player.play("idle")
			current_animation = "idle"
		return
	
	# MOVEMENT ANIMATIONS - SIMPLIFIED CHECK
	# Check if we should be moving based on velocity AND not in any special state
	if abs(velocity.x) > 0.1:  # Increased threshold
		var walk_anim = "walk" + ("2" if not is_facing_right else "")
		if current_animation != walk_anim:
			animation_player.play(walk_anim)
			current_animation = walk_anim
			print("Maya: Playing walk animation (velocity: ", velocity.x, ")")
	else:
		if current_animation != "idle":
			animation_player.play("idle")
			current_animation = "idle"


func _get_animation_with_direction(base_name: String) -> String:
	var directional_animations = ["walk", "magic"]
	
	if base_name in directional_animations:
		return base_name + ("2" if not is_facing_right else "")
	return base_name

func _play_animation(animation_name: String):
	var actual_animation = _get_animation_with_direction(animation_name)
	
	# Don't interrupt teleport or death animations
	if is_teleporting and animation_name not in ["teleport_out", "teleport_in"]:
		return
	
	if dead:
		return
	
	# Don't change to same animation
	if actual_animation == current_animation:
		return
	
	current_animation = actual_animation
	animation_player.play(actual_animation)
	print("Maya: Playing animation: ", actual_animation)

func _on_animation_finished(anim_name: String):
	print("Maya: Animation finished: ", anim_name)
	
	if anim_name == "hurt":
		taking_damage = false
		handle_animation()

# -------------------------------------------------
# TELEPORT SYSTEM - FIX MOVEMENT DURING TELEPORT
# -------------------------------------------------
func refresh_teleport_markers():
	var marker_nodes = get_tree().get_nodes_in_group(teleport_markers_group)
	teleport_markers = []
	for node in marker_nodes:
		if node is Marker2D and is_instance_valid(node):
			teleport_markers.append(node)
	
	print("Maya: Found ", teleport_markers.size(), " teleport markers")

func _should_teleport() -> bool:
	if not player or teleport_markers.is_empty() or defensive_mode:
		return false
	
	if time_since_last_teleport < min_time_between_teleports:
		return false
	
	var distance = global_position.distance_to(player.global_position)
	
	if taking_damage and distance < teleport_min_distance * 2:
		print("Maya: Emergency teleport - taking damage!")
		return true
		
	if distance < teleport_min_distance:
		print("Maya: Emergency teleport - player too close!")
		return true
	
	if health < health_max * 0.3:
		print("Maya: Retreat teleport - low health!")
		return true
	
	if distance > teleport_max_distance * 1.2:
		print("Maya: Strategic teleport - too far from player")
		return true
	
	# Check attack pattern
	var next_attack = attack_pattern[pattern_index]
	match next_attack:
		MagicAttack.ARCANE:
			if distance < attack_range * 0.5 or distance > attack_range * 1.2:
				print("Maya: Strategic teleport - bad distance for arcane")
				return true
		MagicAttack.TRIPLE:
			if distance > attack_range * 1.0:
				print("Maya: Strategic teleport - too far for triple shot")
				return true
		_:
			pass
	
	# Random teleport
	if not is_dealing_damage and not is_preparing_attack:
		if randf() < 0.02 and time_since_last_teleport > min_time_between_teleports * 2:
			print("Maya: Random tactical teleport")
			return true
	
	return false

func _execute_teleport():
	if is_dealing_damage or taking_damage or is_teleporting or dead:
		return
	
	print("Maya: Starting teleport sequence")
	_cleanup_attack_state()
	
	is_preparing_attack = false
	can_attack = true
	
	teleport_cooldown = teleport_cooldown_time
	time_since_last_teleport = 0.0
	
	# Find best marker
	var best_marker = _find_best_teleport_marker()
	if not best_marker:
		return
	
	var new_distance = best_marker.global_position.distance_to(player.global_position)
	var current_distance = global_position.distance_to(player.global_position)
	print("Maya: Teleporting! Current distance: %.1f | New distance: %.1f" % [current_distance, new_distance])
	
	# Enter defensive mode after teleport if close
	if new_distance < teleport_min_distance * 1.5:
		defensive_mode = true
		defensive_timer = defensive_duration
		print("Maya: Entering defensive mode")
	
	# Set teleporting state - STOP MOVEMENT
	is_teleporting = true
	velocity.x = 0  # IMPORTANT: Stop movement
	teleport_target_pos = best_marker.global_position
	
	# Play teleport_out animation
	_play_teleport_out()

func _find_best_teleport_marker():
	var current_distance = global_position.distance_to(player.global_position)
	var best_marker = null
	var best_score = -INF
	
	for marker in teleport_markers:
		if not is_instance_valid(marker):
			continue
		
		var dist_to_player = marker.global_position.distance_to(player.global_position)
		var score = 0.0
		
		# Prefer markers that are not too close or too far
		if current_distance < teleport_min_distance:  # Escaping
			score = dist_to_player * 2.0
			if dist_to_player < teleport_min_distance * 1.5:
				score -= 500.0
		elif health < health_max * 0.3:  # Retreating
			score = dist_to_player * 3.0
		elif current_distance > teleport_max_distance * 1.2:  # Approaching
			if dist_to_player < current_distance:
				score = (current_distance - dist_to_player) * 2.0
			else:
				score = -1000.0
		else:  # Repositioning
			score = 1000.0 / (1.0 + abs(dist_to_player - attack_range * 0.8))
			if dist_to_player < teleport_min_distance * 1.2:
				score -= 300.0
		
		score += randf_range(-10.0, 10.0)
		
		if score > best_score:
			best_score = score
			best_marker = marker
	
	return best_marker

func _play_teleport_out():
	# Stop any current animation and movement
	animation_player.stop()
	velocity.x = 0
	
	# Play teleport_out
	animation_player.play("teleport_out")
	current_animation = "teleport_out"
	
	# Set timer for completion
	var anim_length = animation_player.current_animation_length
	var timer = get_tree().create_timer(anim_length / Global.global_time_scale)
	timer.timeout.connect(_on_teleport_out_completed, CONNECT_ONE_SHOT)
	
func _on_teleport_out_completed():
	if not is_instance_valid(self) or dead:
		return
	
	print("Maya: Teleport_out completed, moving to new position")
	
	# Update position instantly
	global_position = teleport_target_pos
	
	# Update facing direction for new position
	if player:
		var to_player = player.global_position - teleport_target_pos
		is_facing_right = (to_player.x >= 0)
		dir.x = 1 if is_facing_right else -1
		
		if magic_spawn:
			magic_spawn.position.x = abs(magic_spawn.position.x) * (1 if is_facing_right else -1)
	
	# Play teleport_in animation
	_play_teleport_in()

func _play_teleport_in():
	velocity.x = 0  # Ensure no movement
	animation_player.play("teleport_in")
	current_animation = "teleport_in"
	
	# Set timer for completion
	var anim_length = animation_player.current_animation_length
	var timer = get_tree().create_timer(anim_length / Global.global_time_scale)
	timer.timeout.connect(_on_teleport_in_completed, CONNECT_ONE_SHOT)
	
func _on_teleport_in_completed():
	if not is_instance_valid(self) or dead:
		return
	
	print("Maya: Teleport_in completed, returning to normal")
	
	# Reset state
	is_teleporting = false
	teleport_target_pos = Vector2.ZERO
	velocity.x = 0  # Reset velocity
	
	# Update animation based on current state
	handle_animation()

# -------------------------------------------------
# ATTACK SYSTEM
# -------------------------------------------------
func start_attack():
	if defensive_mode or is_dealing_damage or is_preparing_attack or not can_attack or is_teleporting or is_tired or dead:
		return
	
	if teleport_cooldown <= 0.5 and _should_teleport():
		print("Maya: Skipping attack - about to teleport")
		return
	
	super.start_attack()

func _execute_attack_after_delay():
	if is_teleporting or defensive_mode or dead:
		print("Maya: Attack cancelled - teleporting or defensive or dead")
		is_preparing_attack = false
		return
	
	current_attack_type = attack_pattern[pattern_index]
	pattern_index = (pattern_index + 1) % attack_pattern.size()
	
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
	if is_teleporting or defensive_mode or dead or taking_damage:
		print("Maya: Single shot cancelled - state invalid")
		_reset_attack_state()
		return
	
	is_dealing_damage = true
	can_attack = false
	
	print("Maya: Single magic shot!")
	
	# Update facing direction
	if player:
		is_facing_right = (player.global_position.x - global_position.x) >= 0
		dir.x = 1 if is_facing_right else -1
		if magic_spawn:
			magic_spawn.position.x = abs(magic_spawn.position.x) * (1 if is_facing_right else -1)
	
	# Play animation
	_play_animation("magic")
	
	# Fire after delay
	var fire_timer = get_tree().create_timer(0.3 / Global.global_time_scale)
	fire_timer.timeout.connect(_fire_single_shot, CONNECT_ONE_SHOT)
	
	# Safety timeout
	var safety_timer = get_tree().create_timer(2.0 / Global.global_time_scale)
	safety_timer.timeout.connect(func():
		if is_dealing_damage:
			print("Maya: Single shot safety timeout")
			_reset_attack_state()
	, CONNECT_ONE_SHOT)

func _fire_single_shot():
	if not player or dead or is_teleporting or defensive_mode or taking_damage:
		print("Maya: Cannot fire single shot")
		_reset_attack_state()
		return
	
	# Create projectile
	var projectile = magic_projectile_scene.instantiate()
	get_tree().current_scene.add_child(projectile)
	
	var spawn_pos = magic_spawn.global_position if magic_spawn else global_position
	projectile.global_position = spawn_pos
	
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
	var anim_length = animation_player.current_animation_length
	var anim_timer = get_tree().create_timer(anim_length)
	anim_timer.timeout.connect(_on_single_shot_completed, CONNECT_ONE_SHOT)

func _on_single_shot_completed():
	if not is_instance_valid(self) or dead or is_teleporting:
		return
	
	_reset_attack_state()
	attack_cooldown_timer.start(attack_cooldown)

func _execute_triple_shot():
	if is_teleporting or defensive_mode or dead or taking_damage:
		print("Maya: Triple shot cancelled - state invalid")
		_reset_attack_state()
		return
	
	is_dealing_damage = true
	can_attack = false
	
	print("Maya: Triple magic shot!")
	
	# Update facing direction
	if player:
		is_facing_right = (player.global_position.x - global_position.x) >= 0
		dir.x = 1 if is_facing_right else -1
		if magic_spawn:
			magic_spawn.position.x = abs(magic_spawn.position.x) * (1 if is_facing_right else -1)
	
	# Play animation
	_play_animation("magic")
	
	# Fire after delay
	var fire_timer = get_tree().create_timer(0.3 / Global.global_time_scale)
	fire_timer.timeout.connect(_fire_triple_shot, CONNECT_ONE_SHOT)
	
	# Safety timeout
	var safety_timer = get_tree().create_timer(3.0 / Global.global_time_scale)
	safety_timer.timeout.connect(func():
		if is_dealing_damage:
			print("Maya: Triple shot safety timeout")
			_reset_attack_state()
	, CONNECT_ONE_SHOT)

func _fire_triple_shot():
	if not player or dead or is_teleporting or defensive_mode or taking_damage:
		print("Maya: Cannot fire triple shot")
		_reset_attack_state()
		return
	
	var spawn_pos = magic_spawn.global_position if magic_spawn else global_position
	var to_player = (player.global_position - spawn_pos).normalized()
	
	# Fire three shots
	for i in range(3):
		var projectile = magic_projectile_scene.instantiate()
		get_tree().current_scene.add_child(projectile)
		projectile.global_position = spawn_pos
		
		var spread_angle = deg_to_rad(triple_shot_spread * (i - 1))
		var direction = to_player.rotated(spread_angle)
		
		if projectile.has_method("set_direction"):
			projectile.set_direction(direction)
		if "speed" in projectile:
			projectile.speed = 160.0
		if "damage" in projectile:
			projectile.damage = magic_damage * 0.8
		if "lifetime" in projectile:
			projectile.lifetime = 3.0
	
	# Wait for animation to complete
	var anim_length = animation_player.current_animation_length
	var anim_timer = get_tree().create_timer(anim_length)
	anim_timer.timeout.connect(_on_triple_shot_completed, CONNECT_ONE_SHOT)

func _on_triple_shot_completed():
	if not is_instance_valid(self) or dead or is_teleporting:
		return
	
	is_tired = true
	tired_timer = 1.0
	_reset_attack_state()
	attack_cooldown_timer.start(attack_cooldown * 1.5)
	
	# Recover from tired state
	var recover_timer = get_tree().create_timer(1.0 / Global.global_time_scale)
	recover_timer.timeout.connect(func():
		if is_instance_valid(self):
			is_tired = false
	, CONNECT_ONE_SHOT)

func _execute_arcane_shot():
	if is_teleporting or defensive_mode or dead or taking_damage:
		print("Maya: Arcane shot cancelled - state invalid")
		_reset_attack_state()
		return
	
	is_dealing_damage = true
	can_attack = false
	
	print("Maya: Arcane barrage - WIDE FAN ATTACK!")
	
	# Update facing direction
	if player:
		is_facing_right = (player.global_position.x - global_position.x) >= 0
		dir.x = 1 if is_facing_right else -1
		if magic_spawn:
			magic_spawn.position.x = abs(magic_spawn.position.x) * (1 if is_facing_right else -1)
	
	# Play animation
	_play_animation("magic")
	
	# Fire after delay
	var fire_timer = get_tree().create_timer(0.5 / Global.global_time_scale)
	fire_timer.timeout.connect(_fire_arcane_shot, CONNECT_ONE_SHOT)
	
	# Safety timeout
	var safety_timer = get_tree().create_timer(4.0 / Global.global_time_scale)
	safety_timer.timeout.connect(func():
		if is_dealing_damage:
			print("Maya: Arcane shot safety timeout")
			_reset_attack_state()
	, CONNECT_ONE_SHOT)

func _fire_arcane_shot():
	if not player or dead or is_teleporting or defensive_mode or taking_damage:
		print("Maya: Cannot fire arcane shot")
		_reset_attack_state()
		return
	
	var spawn_pos = magic_spawn.global_position if magic_spawn else global_position
	
	var upward_angle = deg_to_rad(-100.0)
	var downward_angle = deg_to_rad(60.0)
	var total_spread = downward_angle - upward_angle
	
	# Fire shots
	for i in range(arcane_shots):
		var projectile = magic_projectile_scene.instantiate()
		get_tree().current_scene.add_child(projectile)
		projectile.global_position = spawn_pos
		
		var t = i / float(arcane_shots - 1) if arcane_shots > 1 else 0.5
		var angle = upward_angle + (total_spread * t)
		
		var base_direction = Vector2.RIGHT if is_facing_right else Vector2.LEFT
		var direction = base_direction.rotated(angle)
		
		if projectile.has_method("set_direction"):
			projectile.set_direction(direction)
		if "speed" in projectile:
			projectile.speed = 130.0
		if "damage" in projectile:
			projectile.damage = magic_damage * 0.55
		if "lifetime" in projectile:
			projectile.lifetime = 3.0
	
	# Wait for animation to complete
	var anim_length = animation_player.current_animation_length
	var anim_timer = get_tree().create_timer(anim_length)
	anim_timer.timeout.connect(_on_arcane_shot_completed, CONNECT_ONE_SHOT)

func _on_arcane_shot_completed():
	if not is_instance_valid(self) or dead or is_teleporting:
		return
	
	is_tired = true
	tired_timer = arcane_tired_time
	_reset_attack_state()
	attack_cooldown_timer.start(attack_cooldown * 2.5)
	
	print("Maya: Entering tired state for ", arcane_tired_time, " seconds")
	
	animation_player.play("idle")
	current_animation = "idle"
	
	# Recover from tired state
	var recover_timer = get_tree().create_timer(arcane_tired_time / Global.global_time_scale)
	recover_timer.timeout.connect(func():
		if is_instance_valid(self):
			is_tired = false
			print("Maya: Recovered from arcane attack")
	, CONNECT_ONE_SHOT)

# -------------------------------------------------
# HELPER FUNCTIONS
# -------------------------------------------------
func _reset_attack_state():
	is_dealing_damage = false
	is_preparing_attack = false
	can_attack = true
	handle_animation()

func _cleanup_attack_state():
	is_dealing_damage = false
	is_preparing_attack = false
	can_start_attack = true
	can_attack = true
	
	if animation_player.current_animation in ["magic", "magic2"]:
		animation_player.stop()
		handle_animation()
	
	print("Maya: Attack state cleaned up")

func take_damage(damage: int) -> void:
	if is_teleporting or dead or defensive_mode or taking_damage:
		print("Maya: Ignoring damage (teleporting/defensive/dead/immune)")
		return
	
	if animation_player.current_animation in ["teleport_out", "teleport_in"]:
		print("Maya: Ignoring damage during teleport animation")
		return
	
	print("Maya: Taking damage: ", damage)
	consecutive_hits += 1
	
	super.take_damage(damage)
	
	if consecutive_hits >= max_consecutive_hits_before_teleport:
		print("Maya: Too many consecutive hits, forcing teleport!")
		force_teleport_on_next_hit = true
		consecutive_hits = 0
		
	if taking_damage:
		_cleanup_attack_state()

func _on_attack_delay_timeout():
	if is_teleporting or defensive_mode or dead:
		print("Maya: Attack delay timeout ignored - teleporting or dead")
		is_preparing_attack = false
		can_start_attack = true
		return
	
	if (can_attack and player and not dead and not taking_damage and 
		hit_stun_timer.time_left <= 0 and not Global.camouflage and
		global_position.distance_to(player.global_position) <= attack_range):
		
		_execute_attack_after_delay()
	else:
		print("Maya: Attack cancelled during delay")
		can_start_attack = true

func _cancel_teleport():
	if is_teleporting:
		print("Maya: Teleport cancelled by damage!")
		is_teleporting = false
		is_dealing_damage = false
		_play_animation("hurt")

func _emergency_reset():
	print("Maya: EMERGENCY RESET CALLED")
	is_dealing_damage = false
	is_preparing_attack = false
	is_teleporting = false
	can_attack = true
	defensive_mode = false
	is_tired = false
	taking_damage = false
	
	animation_player.stop()
	animation_player.play("idle")
	current_animation = "idle"
	
	print("Maya: State reset complete")

func die():
	#if dead:
	#	return
	
	#dead = true
	print("MayaBoss: Died!")
	emit_signal("boss_died")
	queue_free()
	try_drop_health()
	# Play death animation
	handle_animation()

# -------------------------------------------------
# OVERRIDE BASE METHODS
# -------------------------------------------------
func execute_attack():
	pass

func execute_melee_attack():
	pass

func execute_ranged_attack():
	pass

func _on_hit_stun_timeout():
	taking_damage = false
	can_attack = true
	# NEW: Reset consecutive hits after hit stun ends
	consecutive_hits = 0
	
