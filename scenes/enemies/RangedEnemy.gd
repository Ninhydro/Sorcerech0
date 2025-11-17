extends BaseEnemy

@export var projectile_scene: PackedScene =  preload("res://scenes/enemies/Projectile_enemy.tscn") # Will hold the preloaded Fireball.tscn
@export var projectile_speed := 200.0
@export var shoot_range := 150.0  # Longer range than melee

func _initialize_enemy():
	# Override attack range for ranged enemy
	attack_range = shoot_range

func start_attack():
	if can_attack and player and not dead and not taking_damage:
		attack_target = player
		is_dealing_damage = true
		has_dealt_damage = false
		can_attack = false
		
		print("Ranged enemy shooting")
		
		# Face the player when shooting
		dir.x = sign(player.global_position.x - global_position.x)
		
		# Wait for shoot animation
		await get_tree().create_timer(0.4).timeout
		
		# Shoot projectile
		shoot_projectile()
		
		# Finish attack animation
		await get_tree().create_timer(0.2).timeout
		is_dealing_damage = false
		
		# Start cooldown
		attack_cooldown_timer.start(attack_cooldown)

func shoot_projectile():
	if projectile_scene and player:
		var projectile = projectile_scene.instantiate()
		get_parent().add_child(projectile)
		projectile.global_position = global_position
		
		# Calculate direction to player
		var direction = (player.global_position - global_position).normalized()
		projectile.direction = direction
		projectile.speed = projectile_speed
		projectile.damage = enemy_damage

func handle_animation():
	var new_animation := ""
	
	if dead:
		new_animation = "death"
	elif taking_damage:
		new_animation = "hurt"
	elif is_dealing_damage:
		new_animation = "shoot"  # Different animation for shooting
	else:
		new_animation = "run"
		if dir.x == -1:
			sprite.flip_h = true
		elif dir.x == 1:
			sprite.flip_h = false
	
	if new_animation != current_animation:
		current_animation = new_animation
		animation_player.play(new_animation)
		
		if new_animation == "hurt":
			await get_tree().create_timer(0.5).timeout
			taking_damage = false
		elif new_animation == "death":
			await animation_player.animation_finished
			handle_death()
