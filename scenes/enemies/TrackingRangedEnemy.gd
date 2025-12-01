extends BaseEnemy

#@export var projectile_scene: PackedScene = preload("res://scenes/enemies/Projectile_enemy.tscn")
#@export var projectile_speed := 150.0
@export var shoot_range := 180.0
#@export var projectile_lifetime := 3.0
@export var prediction_strength := 2.0  # Strong prediction for slow projectiles
@export var turn_speed := 3.0

#@onready var projectile_spawn := $ProjectileSpawn

# ALERT SYSTEM
var has_alerted := false
var is_alert_animation_playing := false

func _initialize_enemy():
	attack_windup_time = 0.3
	attack_type = AttackType.RANGED
	
	attack_range = shoot_range
	
	# Slow speed properties - NOT AFFECTED BY CAMOUFLAGE
	base_speed = 15
	enemy_damage = 10  # Higher damage to compensate for slow speed
	health = 90
	attack_cooldown = 2.5
	
	# Initialize direction
	dir = Vector2.RIGHT
	use_edge_detection = true
	# Tracking enemies ignore camouflage
	print("Tracking ranged enemy spawned - camouflage immune")

func _process(delta):
	# Override camouflage check - tracking enemies always chase
	if $AnimationPlayer:
		$AnimationPlayer.speed_scale = Global.global_time_scale
		
	if !is_on_floor():
		velocity.y += gravity * delta
		velocity.x = 0
	
	player = Global.playerBody
	
	# TRACKING ENEMIES IGNORE CAMOUFLAGE - always chase if player is alive
	if Global.playerAlive and range:
		is_enemy_chase = true
	else:
		is_enemy_chase = false
	
	# Check for attacks - ignore camouflage
	if is_enemy_chase and player and can_attack and not dead and not taking_damage:
		var distance = global_position.distance_to(player.global_position)
		if distance <= attack_range:
			start_attack()
	
	move(delta)
	handle_animation()
	move_and_slide()

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
		
	if is_enemy_chase:
		is_roaming = false
		
		if player:
			# Simple direction update based on player position
			var player_direction = player.global_position.x - global_position.x
			
			# Update direction with threshold to prevent flickering
			if abs(player_direction) > 5.0:  # Only update if player is significantly to the side
				dir.x = sign(player_direction)
			
			# Move toward player
			velocity.x = dir.x * speed
	else:
		is_roaming = true
		velocity.x = dir.x * speed

#func start_attack():
#	if can_attack and player and not dead and not taking_damage:
#		attack_target = player
#		is_dealing_damage = true
#		has_dealt_damage = false
#		can_attack = false
		
#		print("Tracking slow ranged enemy shooting")
		
		# Ensure correct facing direction before shooting
#		if player:
#			dir.x = sign(player.global_position.x - global_position.x)
		
		# Update projectile spawn position based on direction
#		if has_node("ProjectileSpawn"):
#			var projectile_spawn = $ProjectileSpawn
#			projectile_spawn.position.x = abs(projectile_spawn.position.x) * dir.x
		
		# Wait for shoot animation
#		await get_tree().create_timer(0.5).timeout  # Slower wind-up
		
		# Shoot predictive projectile
#		shoot_predictive_projectile()
		
		# Finish attack animation
#		await get_tree().create_timer(0.4).timeout
#		is_dealing_damage = false
		
		# Start cooldown
#		attack_cooldown_timer.start(attack_cooldown)

func shoot_predictive_projectile():
	if projectile_scene and player:
		var projectile = projectile_scene.instantiate()
		get_tree().current_scene.add_child(projectile)
		
		projectile.global_position = projectile_spawn.global_position
		
		# Calculate predictive aim
		var player_velocity = player.velocity
		var distance_to_player = global_position.distance_to(player.global_position)
		var time_to_reach = distance_to_player / projectile_speed
		
		# Predict where player will be
		var predicted_position = player.global_position + player_velocity * time_to_reach * prediction_strength
		var shoot_direction = (predicted_position - projectile_spawn.global_position).normalized()
		
		# Set projectile properties
		projectile.set_direction(shoot_direction)
		projectile.speed = projectile_speed
		projectile.damage = enemy_damage
		projectile.lifetime = projectile_lifetime
		
		print("Tracking projectile launched with prediction - Direction: ", shoot_direction)

func handle_animation():
	var new_animation := ""
	var moved_x: float = abs(global_position.x - last_anim_position.x)
	
	if dead:
		new_animation = "death"
	elif taking_damage:
		new_animation = "hurt"
	elif is_dealing_damage:
		new_animation = "attack"
	elif is_enemy_chase and not has_alerted:
		# Play alert animation only once when first detecting player
		new_animation = "alert"
		is_alert_animation_playing = true
	elif is_enemy_chase and has_alerted:
		# After alert, use run animation for chasing
		new_animation = "run"
	elif is_preparing_attack:  
		new_animation = "idle"
		
	elif is_roaming:
		new_animation = "run"
	else:
		if is_stuck_idle or moved_x < anim_not_moving_epsilon or abs(velocity.x) < idle_velocity_threshold:
			new_animation = "idle"
		else:
			new_animation = "run"
	
	# Update sprite direction for run/idle animations
	if new_animation == "run" or new_animation == "idle":
		if dir.x < 0:
			sprite.flip_h = true
		elif dir.x > 0:
			sprite.flip_h = false
		
		# Update projectile spawn position
		if has_node("ProjectileSpawn"):
			var projectile_spawn = $ProjectileSpawn
			projectile_spawn.position.x = abs(projectile_spawn.position.x) * dir.x
	
	# Only change animation if it's different
	if new_animation != current_animation:
		current_animation = new_animation
		animation_player.play(new_animation)
		
		# Handle animation completion for specific cases
		if new_animation == "hurt":
			await get_tree().create_timer(0.5).timeout
			taking_damage = false
		elif new_animation == "alert":
			# Wait for alert animation to finish, then mark as alerted
			await animation_player.animation_finished
			has_alerted = true
			is_alert_animation_playing = false
			print("Tracking enemy finished alert animation - now chasing")
		elif new_animation == "death":
			await animation_player.animation_finished
			handle_death()

# Optional: Reset alert state if player leaves and re-enters range
func _on_range_chase_body_exited(body):
	if body.name == "Player":


		pass
