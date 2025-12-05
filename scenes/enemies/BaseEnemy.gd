extends CharacterBody2D
class_name BaseEnemy

# Base properties
@export var base_speed = 50
var speed: float:
	get:
		return base_speed * Global.global_time_scale
		
@export var attack_range := 50
@export var enemy_damage := 0
@export var attack_cooldown := 2.0
@export var health := 100
@export var health_max := 100
@export var knockback_force := 100.0


enum AttackType { MELEE, RANGED }
@export var attack_type: AttackType = AttackType.MELEE

# Ranged attack properties - NEW: Moved ranged properties to base
@export var projectile_scene: PackedScene = preload("res://scenes/enemies/Projectile_enemy.tscn")
@export var projectile_speed := 200.0
@export var projectile_lifetime := 2.0
@export var attack_windup_time := 0.3  # Time before attack happens

# Components
@onready var animation_player := $AnimationPlayer
@onready var direction_timer := $DirectionTimer
@onready var sprite := $Sprite2D
@onready var projectile_spawn := $ProjectileSpawn if has_node("ProjectileSpawn") else null

@export var can_drop_health := true
@export var health_drop_chance := 1
var health_amount := 10
@export var health_drop_scene: PackedScene = preload("res://scenes/objects/health_pickup.tscn")

# State variables
var player: CharacterBody2D
var player_in_area = false
var is_enemy_chase: bool = true
var dead: bool = false
var taking_damage: bool = false 
var is_dealing_damage: bool = false
var is_roaming: bool = true
var range = false
var current_animation := ""

# Movement
var dir: Vector2
var enemy_knockback_force = -20
var gravity = 1000.0

# --- NEW: chase jump settings ---
@export var can_jump_chase := false          # enable this per-enemy in Inspector
@export var jump_speed := 600.0              # vertical speed (similar to player jump_force)
@export var jump_min_vertical_diff := 24.0   # minimum height difference to bother jumping
@export var jump_max_vertical_diff := 224.0   
@export var jump_horizontal_speed := 220.0 
@export var jump_horizontal_range := 300.0    # only jump if player roughly within this X range
@export var jump_cooldown := 1             # seconds between jumps

var jump_cooldown_timer: Timer               # internal timer
@export var jump_forward_multiplier := 1.5
@export var jump_forward_distance := 80.0    # where ray looks forward
@export var jump_check_height := 50.0  
@onready var jump_ray: RayCast2D = $JumpRay if has_node("JumpRay") else null
# --- NEW: "hold jump" behaviour for enemies ---
@export var jump_hold_time := 0.5       # how long they "hold" the jump (seconds)
@export var jump_gravity_scale := 0.1
var is_jump_rising: bool = false
var jump_rise_time_left: float = 0.0

@export var vertical_chase_deadzone := 8.0          # if player is this close in X, don't move horizontally
@export var stop_distance_from_player := 20.0      
@export var stuck_check_speed_threshold := 5.0      # min intended speed to consider "trying to move"
@export var stuck_position_epsilon := 1.0           # max movement (px) to still count as "stuck"
@export var stuck_time_threshold := 0.7             # seconds of being stuck before idling
@export var stuck_idle_duration := 1.5              # idle time before turning around

#@export var vertical_chase_deadzone := 8.0          # if player is this close in X, don't move horizontally

var previous_position: Vector2                      # for detecting no movement
var stuck_accumulator := 0.0
var stuck_idle_timer := 0.0
var is_stuck_idle := false

# Attack system
var attack_target: Node2D = null
var attack_cooldown_timer: Timer
var can_attack := true
var has_dealt_damage := false

var melee_attack_cooldown := false

# EDGE DETECTION SETTINGS
@export var use_edge_detection := true
@export var edge_detection_range := 20.0
@export var edge_ray_offset := 10.0

@onready var edge_ray_left := $EdgeRayLeft if has_node("EdgeRayLeft") else null
@onready var edge_ray_right := $EdgeRayRight if has_node("EdgeRayRight") else null

var should_turn_around := false
var edge_turn_cooldown := 0.0

@export var edge_priority_over_chase := false

var hit_stun_time := 0.3
var hit_stun_timer: Timer
var can_be_interrupted := true  # Can attacks be interrupted?

var attack_delay_timer: Timer
var can_start_attack := true
var is_preparing_attack := false

@export var idle_velocity_threshold := 5.0  # if |velocity.x| < this, use idle instead of run

@export var anim_not_moving_epsilon := 0.5 
var last_anim_position: Vector2   

func _ready():
	# Initialize attack cooldown timer
	attack_cooldown_timer = Timer.new()
	attack_cooldown_timer.one_shot = true
	add_child(attack_cooldown_timer)
	attack_cooldown_timer.timeout.connect(_on_attack_cooldown_timeout)
	
	if use_edge_detection:
		setup_edge_detection()
	
	hit_stun_timer = Timer.new()
	hit_stun_timer.one_shot = true
	add_child(hit_stun_timer)
	hit_stun_timer.timeout.connect(_on_hit_stun_timeout)
	
	attack_delay_timer = Timer.new()
	attack_delay_timer.one_shot = true
	add_child(attack_delay_timer)
	attack_delay_timer.timeout.connect(_on_attack_delay_timeout)
	

	jump_cooldown_timer = Timer.new()
	jump_cooldown_timer.one_shot = true
	add_child(jump_cooldown_timer)
	
	# Initialize enemy-specific components
	_initialize_enemy()
	previous_position = global_position
	last_anim_position = global_position  
	
func _on_attack_delay_timeout():
	can_start_attack = true
	
func _on_hit_stun_timeout():
	taking_damage = false
	can_attack = true
	
func setup_edge_detection():
	if edge_ray_left and edge_ray_right:
		edge_ray_left.enabled = true
		edge_ray_right.enabled = true
		edge_ray_left.target_position = Vector2(0, edge_detection_range)
		edge_ray_right.target_position = Vector2(0, edge_detection_range)
	else:
		print("Warning: Edge detection rays not found for ", name)

func _initialize_enemy():
	pass

func _process(delta):
	if $AnimationPlayer:
		$AnimationPlayer.speed_scale = Global.global_time_scale
		
	if !is_on_floor():
		velocity.y += gravity * delta
		velocity.x = 0
	
	_update_jump_rise(delta)
	player = Global.playerBody
	
	# Global camouflage affects all enemies
	if Global.playerAlive and not Global.camouflage and range:
		is_enemy_chase = true
	else:
		is_enemy_chase = false
	
	# Check for attacks during chase
	if is_enemy_chase and player and can_attack and not Global.camouflage and not dead and not taking_damage:
		var distance = global_position.distance_to(player.global_position)
		if distance <= attack_range:
			start_attack()
	
	# Update edge detection cooldown
	if edge_turn_cooldown > 0:
		edge_turn_cooldown -= delta
	
	# Handle edge detection
	if use_edge_detection and not dead and not taking_damage and not is_dealing_damage and not is_preparing_attack:
		detect_edges()
		
	move(delta)
	handle_animation()
	move_and_slide()
	
	_update_stuck_state(delta)

func detect_edges():
	if not use_edge_detection or edge_turn_cooldown > 0:
		return
	if is_enemy_chase and edge_priority_over_chase:
		return
	# Force raycast updates
	if edge_ray_left:
		edge_ray_left.force_raycast_update()
	if edge_ray_right:
		edge_ray_right.force_raycast_update()
	
	# Check edges based on movement direction
	if dir.x > 0:  # Moving right
		if edge_ray_right and not edge_ray_right.is_colliding():
			should_turn_around = true
			turn_around_at_edge()
	elif dir.x < 0:  # Moving left
		if edge_ray_left and not edge_ray_left.is_colliding():
			should_turn_around = true
			turn_around_at_edge()
	else:
		should_turn_around = false

func turn_around_at_edge():
	if edge_turn_cooldown > 0:
		return
	
	# Reverse direction
	dir.x *= -1
	should_turn_around = false
	edge_turn_cooldown = 1.0
	
	#print(name, " turned around at edge! New direction: ", dir.x)
	
	# Small pause after turning
	var previous_velocity = velocity
	velocity = Vector2.ZERO
	await get_tree().create_timer(0.3).timeout
	
	# Restore velocity in new direction if not in special state
	if not (dead or taking_damage or is_dealing_damage or is_preparing_attack):
		velocity.x = previous_velocity.x * -1
		
func move(delta):
	if dead:
		velocity.x = 0
		return
	
	if taking_damage:
		var knockback_dir = (global_position - player.global_position).normalized()
		velocity.x = knockback_dir.x * abs(enemy_knockback_force)
		is_roaming = false
		return
	

	if is_stuck_idle:
		velocity.x = 0
		is_roaming = false
		return
		
	if is_dealing_damage or is_preparing_attack:
		velocity.x = 0
		is_roaming = false
		return
	
	if should_turn_around and edge_turn_cooldown <= 0:
	# If NOT chasing → always turn
	# If chasing → only turn if this enemy prioritizes edges
		if (not is_enemy_chase) or edge_priority_over_chase:
			turn_around_at_edge()
			return
		
	if is_enemy_chase and player:
		is_roaming = false
		
		var to_player: Vector2 = player.global_position - global_position
		var abs_dx: float = abs(to_player.x)
		
		# Decide facing direction towards player first
		var chase_dir_x: float = sign(to_player.x)
		if chase_dir_x == 0.0:
			chase_dir_x = dir.x if dir.x != 0.0 else 1.0
		dir.x = chase_dir_x
		
		# ===== HARD EDGE PRIORITY WHILE CHASING =====
		if use_edge_detection and edge_priority_over_chase:
			# Update rays
			if edge_ray_left:
				edge_ray_left.force_raycast_update()
			if edge_ray_right:
				edge_ray_right.force_raycast_update()
			
			# If about to walk off → stop and don't move horizontally
			if dir.x > 0 and edge_ray_right and not edge_ray_right.is_colliding():
				velocity.x = 0
				return
			elif dir.x < 0 and edge_ray_left and not edge_ray_left.is_colliding():
				velocity.x = 0
				return
		# ===== END EDGE PRIORITY BLOCK =====
		
		# 🔹 If close enough, stop a bit in front and just idle/attack
		if abs_dx <= stop_distance_from_player:
			velocity.x = 0
			return
		
		# If player is almost directly above – don't jitter left/right
		if abs_dx < vertical_chase_deadzone:
			velocity.x = 0
		else:
			var dir_to_player: Vector2 = to_player.normalized()
			velocity.x = dir_to_player.x * speed
			dir.x = sign(velocity.x)
		
		_try_chase_jump_to_platform()
	else:
		is_roaming = true
		velocity.x = dir.x * speed

func handle_animation():
	var new_animation := ""
	

	var moved_x: float = abs(global_position.x - last_anim_position.x)
	
	if dead:
		new_animation = "death"
	elif taking_damage:
		new_animation = "hurt"
	elif is_dealing_damage:
		new_animation = "attack"
	elif is_preparing_attack:
		new_animation = "idle"
		# Face the player during preparation
		if player:
			dir.x = sign(player.global_position.x - global_position.x)
			if dir.x == -1:
				sprite.flip_h = true
			elif dir.x == 1:
				sprite.flip_h = false
			if projectile_spawn:
				projectile_spawn.position.x = abs(projectile_spawn.position.x) * dir.x
	else:
		# --- NORMAL LOCOMOTION / IDLE ---
		
		# in special "stuck idle" state → idle
		if is_stuck_idle:
			new_animation = "idle"
		
		# 2) barely moved horizontally at all → idle
		elif moved_x < anim_not_moving_epsilon:
			new_animation = "idle"
		
		# 3) If speed is very low → idle
		elif abs(velocity.x) < idle_velocity_threshold:
			new_animation = "idle"
		
		# 4) Otherwise → run
		else:
			new_animation = "run"
		
		# Handle facing direction
		if dir.x == -1:
			sprite.flip_h = true
		elif dir.x == 1:
			sprite.flip_h = false
		if projectile_spawn:
			projectile_spawn.position.x = abs(projectile_spawn.position.x) * dir.x
	
	# Only play if animation changed
	if new_animation != current_animation:
		current_animation = new_animation
		animation_player.play(new_animation)
		
		# Handle animation completion for specific cases
		if new_animation == "hurt":
			await get_tree().create_timer(0.5).timeout
			taking_damage = false
		elif new_animation == "death":
			await animation_player.animation_finished
			handle_death()
	
	# 🔹 Update last_anim_position AFTER deciding animation
	last_anim_position = global_position

func handle_death():
	if can_drop_health and health_drop_scene:
		try_drop_health()
	
	queue_free()

func try_drop_health():
	if randf() <= health_drop_chance:
		drop_health()

func drop_health():
	if not health_drop_scene:
		print("No health drop scene assigned to ", name)
		return
	
	var health_pickup = health_drop_scene.instantiate()
	get_tree().current_scene.add_child(health_pickup)
	
	# Position above ground level
	var drop_position = global_position + Vector2(0, -20)
	health_pickup.global_position = drop_position
	
	print(name, " dropped health pickup!")
	
func take_damage(damage):
	if taking_damage:  # Prevent multiple hits during stun
		return
	health -= damage
	taking_damage = true
	
	# Cancel attack preparation if hit during preparation
	if is_preparing_attack:
		is_preparing_attack = false
		can_start_attack = true
		print("Attack preparation interrupted by damage")
	
	if is_dealing_damage and can_be_interrupted:
		is_dealing_damage = false
		can_attack = false
		print("Attack interrupted by damage")
	
	# Apply hit stun
	hit_stun_timer.start(hit_stun_time / Global.global_time_scale)
	
	if health <= 0:
		health = 0
		dead = true

func start_attack():
	# Prevent multiple attack preparations
	if not can_start_attack or is_preparing_attack or is_dealing_damage:
		return
		
	if (can_attack and player and not dead and not taking_damage and 
		hit_stun_timer.time_left <= 0 and not Global.camouflage):
		var distance = global_position.distance_to(player.global_position)
		if distance <= attack_range:
			if player_can_be_targeted():
				# Set preparing state
				is_preparing_attack = true
				can_start_attack = false
				attack_delay_timer.start(0.5 / Global.global_time_scale)
				
				print(name, " preparing attack (1 second delay)")
				
				# Face the player during delay
				dir.x = sign(player.global_position.x - global_position.x)
				
				# Wait for delay then execute attack
				await attack_delay_timer.timeout
				
				# Clear preparing state
				is_preparing_attack = false
				
				# Check conditions again after delay
				if (can_attack and player and not dead and not taking_damage and 
					hit_stun_timer.time_left <= 0 and not Global.camouflage and
					global_position.distance_to(player.global_position) <= attack_range):
					
					_execute_attack_after_delay()
				else:
					print("Attack cancelled during delay")
					can_start_attack = true

func _execute_attack_after_delay():
	attack_target = player
	is_dealing_damage = true
	has_dealt_damage = false
	can_attack = false
	
	print(name, " executing attack after delay")
	
	if projectile_spawn:
		projectile_spawn.position.x = abs(projectile_spawn.position.x) * dir.x
	
	animation_player.play("attack")
	attack_coroutine()

func player_can_be_targeted() -> bool:
	if not player or not is_instance_valid(player):
		return false
	
	# Check if player is in damageable state
	if player.has_method("can_take_damage"):
		return player.can_take_damage
	
	return true
	
func attack_coroutine():
	# Wait for animation to actually start playing
	await get_tree().process_frame
	
	# Calculate the actual time to wait based on animation speed
	var actual_windup_time = attack_windup_time / animation_player.speed_scale
	
	# Wait for the attack frame (respects both animation speed and global time scale)
	await get_tree().create_timer(actual_windup_time).timeout
	
	# Check if we're still attacking and animation is still playing
	if is_dealing_damage and animation_player.current_animation == "attack":
		# Execute the attack based on type
		execute_attack()
	
	# Wait for the remaining animation time
	var remaining_animation_time = (animation_player.current_animation_length - attack_windup_time) / animation_player.speed_scale
	if remaining_animation_time > 0:
		await get_tree().create_timer(remaining_animation_time).timeout
	
	# Reset attack state
	is_dealing_damage = false
	
	# Start cooldown
	attack_cooldown_timer.start(attack_cooldown)

func execute_attack():
	match attack_type:
		AttackType.MELEE:
			execute_melee_attack()
		AttackType.RANGED:
			execute_ranged_attack()

func execute_melee_attack():
	if is_player_in_attack_range():
		deal_damage()
	else:
		print("Melee attack missed - player moved away")

func execute_ranged_attack():
	if projectile_scene and player:
		shoot_projectile()
	else:
		print("Ranged attack failed - no projectile scene or player")

func shoot_projectile():
	var projectile = projectile_scene.instantiate()
	get_tree().current_scene.add_child(projectile)
	
	# Use the projectile spawn position if available, otherwise use enemy position
	var spawn_position = projectile_spawn.global_position if projectile_spawn else global_position
	projectile.global_position = spawn_position
	
	# Set projectile properties
	projectile.set_direction(Vector2(dir.x, 0))
	projectile.speed = projectile_speed
	projectile.damage = enemy_damage
	projectile.lifetime = projectile_lifetime
	print("Projectile spawned at: ", projectile.global_position, " direction: ", dir.x)

func deal_damage():
	if (attack_target and attack_target is Player and 
		attack_target.can_take_damage and not attack_target.dead):
		
		var knockback_dir = (attack_target.global_position - global_position).normalized()
		Global.enemyAknockback = knockback_dir * knockback_force
		attack_target.take_damage(enemy_damage)
		has_dealt_damage = true
		print("Enemy dealt damage: ", enemy_damage)

func is_player_in_attack_range() -> bool:
	if not player or not is_instance_valid(player):
		return false

	# Separate horizontal and vertical checks so enemy doesn't hit from weird angles
	var dx = abs(player.global_position.x - global_position.x)
	var dy = abs(player.global_position.y - global_position.y)
	print("dx: ", dx)
	print("dy: ", dy)
	# Horizontal reach = attack_range, vertical tolerance = 24 px (tweak as needed)
	return dx <= attack_range and dy <= attack_range
	
func _on_attack_cooldown_timeout():
	can_attack = true
	
func _on_direction_timer_timeout():
	direction_timer.wait_time = choose([1.5, 2.0, 2.5])
	if !is_enemy_chase:
		dir = choose([Vector2.RIGHT, Vector2.LEFT])
		velocity.x = 0

func choose(array):
	array.shuffle()
	return array.front()

func _on_range_chase_body_entered(body):
	if body.name == "Player":
		range = true

func _on_range_chase_body_exited(body):
	if body.name == "Player":
		range = false

func _on_hitbox_area_entered(area):
	var damage = Global.playerDamageAmount
	#print(name, " hitbox entered by: ", area.name)
	if area == Global.playerDamageZone:
		#print(" -> matches Global.playerDamageZone, taking damage: ", damage)
		take_damage(damage)
	elif area.is_in_group("player_attack"):
		# Optional fallback: if you have a group on the player's attack hitbox
	#	print(" -> in group 'player_attack', taking damage: ", damage)
		take_damage(damage)

func _update_stuck_state(delta: float) -> void:
	# Reset tracking during special states
	if dead or taking_damage or is_dealing_damage or is_preparing_attack:
		previous_position = global_position
		stuck_accumulator = 0.0
		return
	

	if is_stuck_idle:
		stuck_idle_timer -= delta
		if stuck_idle_timer <= 0.0:
			is_stuck_idle = false
			stuck_accumulator = 0.0
			
			# Turn around when idle ends
			if dir.x == 0:
				# Choose a random direction
				if randf() < 0.5:
					dir.x = -1
				else:
					dir.x = 1
			else:
				dir.x *= -1
		previous_position = global_position
		return
	

	if abs(velocity.x) > stuck_check_speed_threshold:
		var dx = abs(global_position.x - previous_position.x)
		if dx < stuck_position_epsilon:

			stuck_accumulator += delta
			if stuck_accumulator >= stuck_time_threshold:
				# Enter idle-stuck state
				is_stuck_idle = true
				stuck_idle_timer = stuck_idle_duration
				velocity.x = 0
		else:

			stuck_accumulator = 0.0
	else:
		stuck_accumulator = 0.0
	
	previous_position = global_position

func _try_chase_jump() -> void:
	if not can_jump_chase:
		return
	
	if not is_enemy_chase or player == null or not is_instance_valid(player):
		return
	
	if not is_on_floor():
		return
	
	if jump_cooldown_timer.time_left > 0.0:
		return
	
	var to_player: Vector2 = player.global_position - global_position
	var dx: float = abs(to_player.x)
	var dy: float = to_player.y
	
	if dx <= jump_horizontal_range \
	and dy < -jump_min_vertical_diff \
	and dy > -jump_max_vertical_diff:
		
		# vertical jump
		velocity.y = -jump_speed
		
		# determine direction
		var dir_x: float = sign(to_player.x)
		if dir_x == 0:
			# valid GDScript ternary:
			dir_x = dir.x if dir.x != 0 else 1
		
		# horizontal boost forward
		if abs(velocity.x) < speed:
			velocity.x = dir_x * speed * jump_forward_multiplier
			dir.x = dir_x
		
		jump_cooldown_timer.start(jump_cooldown)

func _try_chase_jump_to_platform() -> void:
	if not can_jump_chase:
		return
	
	if not is_enemy_chase or player == null or not is_instance_valid(player):
		return
	
	# Only jump if grounded
	if not is_on_floor():
		return
	
	# Cooldown
	if jump_cooldown_timer.time_left > 0.0:
		return
	
	if jump_ray == null:
		return
	
	var to_player: Vector2 = player.global_position - global_position
	var abs_dx: float = abs(to_player.x)
	
	# Only try if player roughly in front horizontally
	if abs_dx > jump_horizontal_range:
		return
	
	# Decide facing direction (towards player)
	var dir_x: float = sign(to_player.x)
	if dir_x == 0.0:
		dir_x = dir.x if dir.x != 0.0 else 1.0
	
	# Aim ray to (≈80, -50) in local space, flipped by dir_x
	var local_target: Vector2 = Vector2(
		jump_forward_distance * dir_x,
		-jump_check_height
	)
	jump_ray.target_position = local_target
	
	jump_ray.force_raycast_update()
	

	if not jump_ray.is_colliding():
		return
	
	var hit_point: Vector2 = jump_ray.get_collision_point()
	
	# Make sure the platform is at least a bit above us
	if hit_point.y >= global_position.y - 4.0:
		return
	
	# --- Do the jump ---
	velocity.y = -jump_speed
	velocity.x = dir_x * jump_horizontal_speed
	dir.x = dir_x
	
	is_jump_rising = true
	jump_rise_time_left = jump_hold_time
	
	
	jump_cooldown_timer.start(jump_cooldown)

func _update_jump_rise(delta: float) -> void:
	if not is_jump_rising:
		return
	
	jump_rise_time_left -= delta
	
	# Stop holding if time is up, enemy starts falling, or lands again
	if jump_rise_time_left <= 0.0 or is_on_floor() or velocity.y >= 0.0:
		is_jump_rising = false
		return
	

	# velocity.y += gravity * delta

	
	var full_g: float = gravity * delta
	var reduced_g: float = full_g * (1.0 - jump_gravity_scale)

	velocity.y -= reduced_g

	
