extends BaseEnemy

#@export var projectile_scene: PackedScene = preload("res://scenes/enemies/Projectile_enemy.tscn")
#@export var projectile_speed := 200.0
@export var shoot_range := 150.0
#@export var projectile_lifetime := 2.0

# WALL SETTINGS - Set this in the Inspector!
@export_enum("Left Wall", "Right Wall") var wall_side: int = 0  # 0 = Left, 1 = Right

#@onready var projectile_spawn := $ProjectileSpawn
@onready var wall_ray := $WallRay
@onready var edge_detection_ray := $EdgeDetectionRay

var is_on_wall := true

func _ready():
	super._ready()
	print("Wall Spider ready - Side: ", "Left" if wall_side == 0 else "Right")
	setup_wall_spider()

func setup_wall_spider():
	# Set up based on wall side
	if wall_side == 0:  # Left Wall
		sprite.rotation_degrees = 90
		sprite.position = Vector2(45, 0)
		wall_ray.position = Vector2(-15, 0)
		wall_ray.target_position = Vector2(-25, 0)
	else:  # Right Wall
		sprite.rotation_degrees = -90
		sprite.position = Vector2(45, 0)
		wall_ray.position = Vector2(15, 0)
		wall_ray.target_position = Vector2(25, 0)
	
	# Set up edge detection
	update_edge_detection_ray()

func _initialize_enemy():
	attack_windup_time = 0.3
	attack_type = AttackType.RANGED
	attack_range = shoot_range
	base_speed = 35
	enemy_damage = 10
	health = 80
	attack_cooldown = 1.8
	gravity = 0
	use_edge_detection = false
	
func _process(delta):
	if $AnimationPlayer:
		$AnimationPlayer.speed_scale = Global.global_time_scale
	
	player = Global.playerBody
	
	if Global.playerAlive and not Global.camouflage and range:
		is_enemy_chase = true
	else:
		is_enemy_chase = false
	
	# Always on wall for this version
	is_on_wall = true
	
	detect_edges()
	
	if is_on_wall:
		if is_enemy_chase and player and can_attack and not dead and not taking_damage:
			var distance = global_position.distance_to(player.global_position)
			if distance <= attack_range:
				start_attack()
		
		move(delta)
		handle_animation()
		move_and_slide()

func detect_edges():
	if not is_on_wall:
		return
	
	wall_ray.force_raycast_update()
	edge_detection_ray.force_raycast_update()
	
	var wall_colliding = wall_ray.is_colliding()
	var edge_colliding = edge_detection_ray.is_colliding()
	
	# If we lose contact with wall or hit an edge, turn around
	if not wall_colliding or not edge_colliding:
		turn_around()

func update_edge_detection_ray():
	if wall_side == 0:  # Left Wall
		if dir.x > 0:  # Moving "up"
			edge_detection_ray.position = Vector2(-10, -15)
			edge_detection_ray.target_position = Vector2(-25, 0)
		else:  # Moving "down"
			edge_detection_ray.position = Vector2(-10, 15)
			edge_detection_ray.target_position = Vector2(-25, 0)
	else:  # Right Wall
		if dir.x > 0:  # Moving "down"
			edge_detection_ray.position = Vector2(10, 15)
			edge_detection_ray.target_position = Vector2(25, 0)
		else:  # Moving "up"
			edge_detection_ray.position = Vector2(10, -15)
			edge_detection_ray.target_position = Vector2(25, 0)

func move(delta):
	if dead:
		velocity = Vector2.ZERO
		return
	
	if taking_damage:
		# Simple knockback - push away from player
		velocity.y = -dir.x * abs(enemy_knockback_force)  # Use Y for vertical knockback on walls
		return
	
	if is_dealing_damage:
		velocity = Vector2.ZERO
		return
	
	if is_enemy_chase:
		is_roaming = false
		if player:
			move_toward_player()
	else:
		is_roaming = true
		roam()
	
	# Update edge detection based on current direction
	update_edge_detection_ray()

func turn_around():
	# Reverse direction
	dir.x *= -1
	#print("Wall Spider turned around! New direction: ", dir.x)
	
	# Small pause after turning
	velocity = Vector2.ZERO
	await get_tree().create_timer(0.5).timeout

func move_toward_player():
	if not player:
		return
	
	# Move vertically toward player (Y-axis movement on walls)
	var direction = sign(player.global_position.y - global_position.y)
	velocity.x = 0
	velocity.y = direction * speed
	dir.x = direction
	
	update_spider_visuals(direction)

func roam():
	# Simple vertical roaming on wall
	velocity.x = 0
	velocity.y = dir.x * speed * 0.5
	update_spider_visuals(dir.x)

func update_spider_visuals(direction: float):
	# Update sprite flipping based on direction
	if wall_side == 0:  # Left Wall
		sprite.flip_h = (direction < 0)
		if has_node("ProjectileSpawn"):
			$ProjectileSpawn.position = Vector2(0, -20 * direction)
	else:  # Right Wall
		sprite.flip_h = (direction > 0)
		if has_node("ProjectileSpawn"):
			$ProjectileSpawn.position = Vector2(0, 20 * direction)

#func start_attack():
#	if can_attack and player and not dead and not taking_damage and is_on_wall:
#		attack_target = player
#		is_dealing_damage = true
#		has_dealt_damage = false
#		can_attack = false
		
#		print("Wall Spider attacking")
		
#		await get_tree().create_timer(0.3).timeout
#		shoot_projectile()
#		await get_tree().create_timer(0.2).timeout
#		is_dealing_damage = false
		
		# Start cooldown
#		attack_cooldown_timer.start(attack_cooldown)

func shoot_projectile():
	if projectile_scene and player:
		var projectile = projectile_scene.instantiate()
		get_tree().current_scene.add_child(projectile)
		
		projectile.global_position = projectile_spawn.global_position
		var shoot_direction = (player.global_position - projectile_spawn.global_position).normalized()
		
		projectile.set_direction(shoot_direction)
		projectile.speed = projectile_speed
		projectile.damage = enemy_damage
		projectile.lifetime = projectile_lifetime

func handle_animation():
	var new_animation := ""
	var moved_x: float = abs(global_position.x - last_anim_position.x)
	
	if dead:
		new_animation = "death"
	elif taking_damage:
		new_animation = "hurt"
	elif is_dealing_damage:
		new_animation = "attack"
	elif is_on_wall:
		new_animation = "run"
	elif is_preparing_attack:  # ADDED: Preparation state uses idle animation
		new_animation = "idle"
		
	else:
		if is_stuck_idle or moved_x < anim_not_moving_epsilon or abs(velocity.x) < idle_velocity_threshold:
			new_animation = "idle"
		else:
			new_animation = "run"
	
	if new_animation != current_animation:
		current_animation = new_animation
		animation_player.play(new_animation)
		
		if new_animation == "hurt":
			await get_tree().create_timer(0.5).timeout
			taking_damage = false
		elif new_animation == "death":
			await animation_player.animation_finished
			handle_death()

func _on_direction_timer_timeout():
	# Simple direction change for roaming
	if !is_enemy_chase and is_on_wall:
		dir = choose([Vector2.RIGHT, Vector2.LEFT])
		#print("Wall Spider changed roam direction to: ", dir.x)
