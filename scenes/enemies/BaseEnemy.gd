extends CharacterBody2D
class_name BaseEnemy

# Base properties
@export var base_speed = 50
var speed: float:
	get:
		return base_speed * Global.global_time_scale
		
@export var attack_range := 60
@export var enemy_damage := 10
@export var attack_cooldown := 1.0
@export var health := 100
@export var health_max := 100
@export var knockback_force := 100.0

# Attack type - NEW: Added attack type system
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
@export var health_amount := 10
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

func _ready():
	# Initialize attack cooldown timer
	attack_cooldown_timer = Timer.new()
	attack_cooldown_timer.one_shot = true
	add_child(attack_cooldown_timer)
	attack_cooldown_timer.timeout.connect(_on_attack_cooldown_timeout)
	
	if use_edge_detection:
		setup_edge_detection()
	
	# Initialize enemy-specific components
	_initialize_enemy()

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
	if use_edge_detection and not dead and not taking_damage and not is_dealing_damage:
		detect_edges()
		
	move(delta)
	handle_animation()
	move_and_slide()

func detect_edges():
	if not use_edge_detection or edge_turn_cooldown > 0:
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
	
	print(name, " turned around at edge! New direction: ", dir.x)
	
	# Small pause after turning
	var previous_velocity = velocity
	velocity = Vector2.ZERO
	await get_tree().create_timer(0.3).timeout
	
	# Restore velocity in new direction if not in special state
	if not (dead or taking_damage or is_dealing_damage):
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
		
	if is_dealing_damage:
		velocity.x = 0
		is_roaming = false
		return
	
	if should_turn_around and not is_enemy_chase and edge_turn_cooldown <= 0:
		turn_around_at_edge()
		return
		
	if is_enemy_chase:
		is_roaming = false
		var dir_to_player = (player.global_position - global_position).normalized()
		velocity.x = dir_to_player.x * speed
		dir.x = sign(velocity.x)
	else:
		is_roaming = true
		velocity.x = dir.x * speed

func handle_animation():
	var new_animation := ""
	
	if dead:
		new_animation = "death"
	elif taking_damage:
		new_animation = "hurt"
	elif is_dealing_damage:
		new_animation = "attack"
	else:
		new_animation = "run"
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
	health -= damage
	taking_damage = true
	if health <= 0:
		health = 0
		dead = true

func start_attack():
	if can_attack and player and not dead and not taking_damage:
		attack_target = player
		is_dealing_damage = true
		has_dealt_damage = false
		can_attack = false
		
		print(name, " starting ", AttackType.keys()[attack_type], " attack")
		
		# Face the player when attacking
		dir.x = sign(player.global_position.x - global_position.x)
		
		# Update projectile spawn position based on direction
		if projectile_spawn:
			projectile_spawn.position.x = abs(projectile_spawn.position.x) * dir.x
		
		# Play attack animation
		animation_player.play("attack")
		
		# Use unified attack coroutine
		attack_coroutine()

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
	return global_position.distance_to(player.global_position) <= attack_range

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
	if area == Global.playerDamageZone:
		take_damage(damage)
