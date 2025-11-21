extends BaseEnemy

#@export var projectile_scene: PackedScene = preload("res://scenes/enemies/Projectile_enemy.tscn")
#@export var projectile_speed := 200.0
@export var shoot_range := 150.0
#@export var projectile_lifetime := 2.0
@export var flight_height := 100.0  # How high above ground to fly
@export var hover_speed := 50.0     # Up/down hover movement speed

#@onready var projectile_spawn := $ProjectileSpawn

var initial_y: float
var hover_direction := 1.0
var hover_timer := 0.0

func _initialize_enemy():
	attack_windup_time = 0.3
	attack_type = AttackType.RANGED
	attack_range = shoot_range
	gravity = 0  # Flying enemies ignore gravity
	initial_y = global_position.y
	
	# Flying enemies are faster
	base_speed = 40
	use_edge_detection = false

func _process(delta):
	# Call parent process but override gravity behavior
	if $AnimationPlayer:
		$AnimationPlayer.speed_scale = Global.global_time_scale
	
	player = Global.playerBody
	
	# Global camouflage affects all enemies
	if Global.playerAlive and not Global.camouflage and range:
		is_enemy_chase = true
	else:
		is_enemy_chase = false
	
	# Handle hover movement
	handle_hover_movement(delta)
	
	# Check for attacks during chase
	if is_enemy_chase and player and can_attack and not Global.camouflage and not dead and not taking_damage:
		var distance = global_position.distance_to(player.global_position)
		if distance <= attack_range:
			start_attack()
	
	move(delta)
	handle_animation()
	move_and_slide()

func handle_hover_movement(delta):
	# Gentle up/down hover movement
	hover_timer += delta
	if hover_timer >= 2.0:  # Change hover direction every 2 seconds
		hover_direction *= -1
		hover_timer = 0.0
	
	# Apply hover movement
	velocity.y = hover_direction * hover_speed * Global.global_time_scale

func move(delta):
	if dead:
		velocity.x = 0
		velocity.y = 0
		return
	
	if taking_damage:
		# Flying enemies get knockback in both directions
		var knockback_dir = (global_position - player.global_position).normalized()
		velocity.x = knockback_dir.x * abs(enemy_knockback_force)
		velocity.y = knockback_dir.y * abs(enemy_knockback_force) * 0.5  # Less vertical knockback
		is_roaming = false
		return
		
	if is_dealing_damage:
		velocity.x = 0
		is_roaming = false
		return
		
	if is_enemy_chase:
		is_roaming = false
		var dir_to_player = (player.global_position - global_position).normalized()
		velocity.x = dir_to_player.x * speed
		dir.x = sign(velocity.x)
		
		# Maintain flight height while chasing
		var target_y = initial_y - flight_height
		var y_diff = target_y - global_position.y
		velocity.y += y_diff * 2.0 * delta  # Smooth height adjustment
	else:
		is_roaming = true
		velocity.x = dir.x * speed * 0.7  # Slower when roaming
		
		# Maintain flight height while roaming
		var target_y = initial_y - flight_height
		var y_diff = target_y - global_position.y
		velocity.y += y_diff * 2.0 * delta

#func start_attack():
#	if can_attack and player and not dead and not taking_damage:
#		attack_target = player
#		is_dealing_damage = true
#		has_dealt_damage = false
#		can_attack = false
		
#		print("Flying ranged enemy shooting")
		
		# Face the player when shooting
#		dir.x = sign(player.global_position.x - global_position.x)
		
		# Update projectile spawn position based on direction
#		if has_node("ProjectileSpawn"):
#			var projectile_spawn = $ProjectileSpawn
#			projectile_spawn.position.x = abs(projectile_spawn.position.x) * dir.x
		
		# Wait for shoot animation
#		await get_tree().create_timer(0.3).timeout
		
		# Shoot projectile
#		shoot_projectile()
		
		# Finish attack animation
#		await get_tree().create_timer(0.2).timeout
#		is_dealing_damage = false
		
		# Start cooldown
#		attack_cooldown_timer.start(attack_cooldown)

func shoot_projectile():
	if projectile_scene and player:
		var projectile = projectile_scene.instantiate()
		get_tree().current_scene.add_child(projectile)
		
		# Use the Marker2D position
		projectile.global_position = projectile_spawn.global_position
		
		# Calculate direction towards player (including vertical component)
		var direction_to_player = (player.global_position - projectile_spawn.global_position).normalized()
		
		# Set projectile properties
		projectile.set_direction(direction_to_player)
		projectile.speed = projectile_speed
		projectile.damage = enemy_damage
		projectile.lifetime = projectile_lifetime
		print("Flying enemy projectile spawned at: ", projectile.global_position)

func handle_animation():
	var new_animation := ""
	
	if dead:
		new_animation = "death"
	elif taking_damage:
		new_animation = "hurt"
	elif is_dealing_damage:
		new_animation = "attack" #shoot
	elif is_preparing_attack:  # ADDED: Preparation state uses idle animation
		new_animation = "idle"
	else:
		new_animation = "run"  # Use "fly" animation instead of "run"
		# Update direction for sprite and projectile spawn
		if dir.x == -1:
			sprite.flip_h = true
		elif dir.x == 1:
			sprite.flip_h = false
		
		# Update projectile spawn position
		if has_node("ProjectileSpawn"):
			var projectile_spawn = $ProjectileSpawn
			projectile_spawn.position.x = abs(projectile_spawn.position.x) * dir.x
	
	if new_animation != current_animation:
		current_animation = new_animation
		animation_player.play(new_animation)
		
		if new_animation == "hurt":
			await get_tree().create_timer(0.5).timeout
			taking_damage = false
		elif new_animation == "death":
			await animation_player.animation_finished
			handle_death()

# Flying enemies don't use ground-based gravity
func _physics_process(delta):
	# Override parent physics to remove gravity
	pass
