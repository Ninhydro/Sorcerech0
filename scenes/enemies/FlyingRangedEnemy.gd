extends BaseEnemy

@export var projectile_scene: PackedScene =  preload("res://scenes/enemies/Projectile_enemy.tscn") # Will hold the preloaded Fireball.tscn
@export var projectile_speed := 200.0  # ADD THIS LINE
@export var flight_height := 80.0
@export var hover_speed := 50.0
var initial_y: float

func _initialize_enemy():
	initial_y = global_position.y
	# Flying enemies ignore gravity - now this works since gravity is a variable
	gravity = 0
	attack_range = 120.0  # Medium range for flying ranged

func _process(delta):
	# Override to add flying behavior
	if $AnimationPlayer:
		$AnimationPlayer.speed_scale = Global.global_time_scale
	
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
	
	move(delta)
	handle_animation()
	move_and_slide()

func move(delta):
	if dead:
		velocity = Vector2.ZERO
		return
	
	if taking_damage:
		# Flying enemies get knockback but can move in air
		var knockback_dir = (global_position - player.global_position).normalized()
		velocity = knockback_dir * abs(enemy_knockback_force)
		return
		
	if is_dealing_damage:
		velocity.x = 0
		return
		
	if is_enemy_chase and player:
		# Fly towards player while maintaining height
		var target_x = player.global_position.x
		var target_y = initial_y - flight_height
		var target_pos = Vector2(target_x, target_y)
		
		var direction = (target_pos - global_position).normalized()
		velocity = direction * speed
		dir.x = sign(velocity.x)
		
		# Add gentle hovering motion
		velocity.y += sin(Time.get_ticks_msec() * 0.005) * hover_speed
	else:
		# Roaming flight pattern
		velocity.x = dir.x * speed * 0.5
		velocity.y = sin(Time.get_ticks_msec() * 0.005) * hover_speed

func start_attack():
	if can_attack and player and not dead and not taking_damage:
		attack_target = player
		is_dealing_damage = true
		has_dealt_damage = false
		can_attack = false
		
		print("Flying ranged enemy shooting")
		
		# Face the player
		dir.x = sign(player.global_position.x - global_position.x)
		
		await get_tree().create_timer(0.3).timeout
		shoot_projectile()
		await get_tree().create_timer(0.2).timeout
		is_dealing_damage = false
		
		attack_cooldown_timer.start(attack_cooldown)

func shoot_projectile():
	if projectile_scene and player:
		var projectile = projectile_scene.instantiate()
		get_parent().add_child(projectile)
		projectile.global_position = global_position
		
		var direction = (player.global_position - global_position).normalized()
		projectile.direction = direction
		projectile.speed = projectile_speed  # Now this variable exists
		projectile.damage = enemy_damage

func handle_animation():
	var new_animation := ""
	
	if dead:
		new_animation = "death"
	elif taking_damage:
		new_animation = "hurt"
	elif is_dealing_damage:
		new_animation = "shoot"
	else:
		new_animation = "fly"  # Flying animation
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
