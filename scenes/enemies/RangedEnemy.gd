extends BaseEnemy

@export var projectile_scene: PackedScene = preload("res://scenes/enemies/Projectile_enemy.tscn")
@export var projectile_speed := 200.0
@export var shoot_range := 150.0
@export var projectile_lifetime := 2.0

@onready var projectile_spawn := $ProjectileSpawn

func _initialize_enemy():
	attack_range = shoot_range
	use_edge_detection = true

func start_attack():
	if can_attack and player and not dead and not taking_damage:
		attack_target = player
		is_dealing_damage = true
		has_dealt_damage = false
		can_attack = false
		
		print("Ranged enemy shooting")
		
		# Face the player when shooting
		dir.x = sign(player.global_position.x - global_position.x)
		
		# Update projectile spawn position based on direction
		if has_node("ProjectileSpawn"):
			var projectile_spawn = $ProjectileSpawn
			projectile_spawn.position.x = abs(projectile_spawn.position.x) * dir.x
		
		# Wait for shoot animation
		await get_tree().create_timer(0.3).timeout
		
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
		get_tree().current_scene.add_child(projectile)
		
		# Use the Marker2D position
		projectile.global_position = projectile_spawn.global_position
		
		# Set projectile properties
		projectile.set_direction(Vector2(dir.x, 0))
		projectile.speed = projectile_speed
		projectile.damage = enemy_damage
		projectile.lifetime = projectile_lifetime
		print("Projectile spawned at: ", projectile.global_position, " direction: ", dir.x)

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
