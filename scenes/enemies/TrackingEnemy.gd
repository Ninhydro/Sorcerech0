extends BaseEnemy

@export var prediction_strength := 1.5  # How far ahead to predict player movement
@export var turn_speed := 5.0  # How quickly to turn toward target
@export var dash_speed_multiplier := 2.0
@export var dash_duration := 0.3
@export var dash_cooldown := 2.0

var is_dashing := false
var dash_timer := 0.0
var last_player_velocity := Vector2.ZERO

var has_alerted := false
var is_alert_animation_playing := false

func _initialize_enemy():
	# Fast speed properties - NOT AFFECTED BY CAMOUFLAGE
	base_speed = 80
	attack_range = 40
	enemy_damage = 15
	health = 80  # Less health for balance
	
	# Initialize direction
	dir = Vector2.RIGHT
	use_edge_detection = true
	# Tracking enemies ignore camouflage
	print("Tracking enemy spawned - camouflage immune")

func _process(delta):
	# Override camouflage check - tracking enemies always chase
	if $AnimationPlayer:
		$AnimationPlayer.speed_scale = Global.global_time_scale
		
	if !is_on_floor():
		velocity.y += gravity * delta
		velocity.x = 0
	
	player = Global.playerBody
	
	# TRACKING ENEMIES IGNORE CAMOUFLAGE - always chase if player is alive
	if Global.playerAlive and not Global.camouflage and range:
		is_enemy_chase = true
	else:
		is_enemy_chase = false
	
	# Update dash timer
	if dash_timer > 0:
		dash_timer -= delta * Global.global_time_scale
	
	# Check for attacks - ignore camouflage
	if is_enemy_chase and player and can_attack and not Global.camouflage and not dead and not taking_damage:
		var distance = global_position.distance_to(player.global_position)
		if distance <= attack_range:
			start_attack()
		elif distance <= attack_range * 2 and dash_timer <= 0:
			# Dash attack from further range
			start_dash_attack()
	
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
		
	if is_dealing_damage or is_dashing:
		# Only stop horizontal movement during attacks, keep vertical
		velocity.x = 0
		is_roaming = false
		return
		
	if is_enemy_chase:
		is_roaming = false
		
		if player:
			# Get raw direction to player (no prediction for basic movement)
			var raw_direction = (player.global_position - global_position).normalized()
			
			# Update direction based on player position
			if abs(raw_direction.x) > 0.1:  # Only update if there's significant horizontal movement
				dir.x = sign(raw_direction.x)
			
			# Simple movement toward player
			velocity.x = dir.x * speed
			
			# Debug output
			#print("Player X: ", player.global_position.x, " Enemy X: ", global_position.x, " Direction: ", dir.x)
	else:
		is_roaming = true
		velocity.x = dir.x * speed

func start_attack():
	if can_attack and player and not dead and not taking_damage and not is_dashing:
		attack_target = player
		is_dealing_damage = true
		has_dealt_damage = false
		can_attack = false
		
		print("Tracking fast melee enemy attacking")
		
		# Ensure correct facing direction before attacking
		if player:
			dir.x = sign(player.global_position.x - global_position.x)
		
		# Wait for attack animation
		await get_tree().create_timer(0.2).timeout  # Faster attack
		
		# Deal damage
		if attack_target and attack_target is Player and attack_target.can_take_damage and not attack_target.dead:
			var knockback_dir = (attack_target.global_position - global_position).normalized()
			Global.enemyAknockback = knockback_dir * knockback_force
			attack_target.take_damage(enemy_damage)
			print("Tracking melee enemy dealt damage: ", enemy_damage)
		
		# Finish attack animation
		await get_tree().create_timer(0.15).timeout
		is_dealing_damage = false
		
		# Start cooldown
		attack_cooldown_timer.start(attack_cooldown * 0.7)  # Faster cooldown

func start_dash_attack():
	if not is_dashing and dash_timer <= 0 and player:
		is_dashing = true
		print("Tracking fast melee enemy dash attacking")
		
		# Face player before dashing
		if player:
			dir.x = sign(player.global_position.x - global_position.x)
		
		# Dash toward player
		var dash_direction = Vector2(dir.x, 0)  # Only horizontal dash
		velocity = dash_direction * speed * dash_speed_multiplier
		
		# Dash duration
		await get_tree().create_timer(dash_duration).timeout
		
		# Deal damage if close enough after dash
		if player and global_position.distance_to(player.global_position) <= attack_range:
			deal_dash_damage()
		
		# Reset
		is_dashing = false
		dash_timer = dash_cooldown
		velocity.x = 0

func deal_dash_damage():
	if player and player is Player and player.can_take_damage and not player.dead:
		var knockback_dir = (player.global_position - global_position).normalized()
		Global.enemyAknockback = knockback_dir * (knockback_force * 1.3)
		player.take_damage(enemy_damage)
		print("Tracking dash attack dealt damage: ", enemy_damage)
func handle_animation():
	var new_animation := ""
	
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
	elif is_roaming:
		new_animation = "run"
	else:
		new_animation = "idle"
	
	# Update sprite direction
	if dir.x < 0:
		sprite.flip_h = true
	elif dir.x > 0:
		sprite.flip_h = false
	
	if new_animation != current_animation:
		current_animation = new_animation
		animation_player.play(new_animation)
		
		if new_animation == "hurt":
			await get_tree().create_timer(0.4).timeout
			taking_damage = false
		elif new_animation == "alert":
			await animation_player.animation_finished
			has_alerted = true
			is_alert_animation_playing = false
		elif new_animation == "death":
			await animation_player.animation_finished
			handle_death()
