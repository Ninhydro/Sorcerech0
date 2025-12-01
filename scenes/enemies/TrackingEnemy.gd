extends BaseEnemy

@export var prediction_strength := 1.5
@export var turn_speed := 5.0
@export var dash_speed_multiplier := 2.0
@export var dash_duration := 0.0
@export var dash_cooldown := 2.0

var is_attack_cooldown := false
var is_dash_cooldown := false

var is_dashing := false
var dash_timer := 0.0
var last_player_velocity := Vector2.ZERO

var has_alerted := false
var is_alert_animation_playing := false

func _initialize_enemy():
	base_speed = 80
	attack_range = 40
	enemy_damage = 10
	health = 80
	
	dir = Vector2.RIGHT
	use_edge_detection = true
	print("Tracking enemy spawned - camouflage immune")

func _process(delta):
	if $AnimationPlayer:
		$AnimationPlayer.speed_scale = Global.global_time_scale
		
	if !is_on_floor():
		velocity.y += gravity * delta
		velocity.x = 0
	
	player = Global.playerBody
	
	if Global.playerAlive and not Global.camouflage and range:
		is_enemy_chase = true
	else:
		is_enemy_chase = false

	# dash cooldown
	if dash_timer > 0:
		dash_timer -= delta * Global.global_time_scale
		if dash_timer <= 0:
			is_dash_cooldown = false  


	if is_enemy_chase and player and can_attack and not Global.camouflage and not dead and not taking_damage:
		var distance = global_position.distance_to(player.global_position)

		if distance <= attack_range and not is_attack_cooldown:
			start_attack()

		elif distance <= attack_range * 2 and dash_timer <= 0 and not is_dash_cooldown:
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
		velocity.x = 0
		is_roaming = false
		return


	if is_attack_cooldown or is_dash_cooldown:
		is_roaming = false
		return
		
	if is_enemy_chase:
		is_roaming = false
		
		if player:
			var raw_direction = (player.global_position - global_position).normalized()
			
			if abs(raw_direction.x) > 0.1:
				dir.x = sign(raw_direction.x)
			
			velocity.x = dir.x * speed
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

		if player:
			dir.x = sign(player.global_position.x - global_position.x)

		await get_tree().create_timer(0.2).timeout
		
		if attack_target and attack_target is Player and attack_target.can_take_damage and not attack_target.dead:
			var knockback_dir = (attack_target.global_position - global_position).normalized()
			Global.enemyAknockback = knockback_dir * knockback_force
			attack_target.take_damage(enemy_damage)
			print("Tracking melee enemy dealt damage: ", enemy_damage)

		await get_tree().create_timer(0.15).timeout
		is_dealing_damage = false


		is_attack_cooldown = true

		attack_cooldown_timer.start(attack_cooldown * 0.7)

func _on_attack_cooldown_timeout():

	can_attack = true
	is_attack_cooldown = false

func start_dash_attack():
	if not is_dashing and dash_timer <= 0 and player:
		is_dashing = true
		print("Tracking fast melee enemy dash attacking")

		if player:
			dir.x = sign(player.global_position.x - global_position.x)

		var dash_direction = Vector2(dir.x, 0)
		velocity = dash_direction * speed * dash_speed_multiplier

		await get_tree().create_timer(dash_duration).timeout

		if player and global_position.distance_to(player.global_position) <= attack_range:
			deal_dash_damage()

		is_dashing = false
		velocity.x = 0


		is_dash_cooldown = true
		dash_timer = dash_cooldown

func deal_dash_damage():
	if player and player is Player and player.can_take_damage and not player.dead:
		var knockback_dir = (player.global_position - global_position).normalized()
		Global.enemyAknockback = knockback_dir * (knockback_force * 1.3)
		player.take_damage(enemy_damage)
		print("Tracking dash attack dealt damage: ", enemy_damage)

func handle_animation():
	var new_animation := ""
	var moved_x: float = abs(global_position.x - last_anim_position.x)
	
	if dead:
		new_animation = "death"
	elif taking_damage:
		new_animation = "hurt"
	elif is_dealing_damage:
		new_animation = "attack"
	elif is_attack_cooldown or is_dash_cooldown:     
		new_animation = "idle"
	elif is_enemy_chase and not has_alerted:
		new_animation = "alert"
		is_alert_animation_playing = true
		has_alerted = true
	elif is_enemy_chase and has_alerted:
		# chase animation, but still stop if blocked
		if is_stuck_idle or moved_x < anim_not_moving_epsilon or abs(velocity.x) < idle_velocity_threshold:
			new_animation = "idle"
		else:
			new_animation = "run"
	elif is_roaming:
		if is_stuck_idle or moved_x < anim_not_moving_epsilon or abs(velocity.x) < idle_velocity_threshold:
			new_animation = "idle"
		else:
			new_animation = "run"
	else:
		if is_stuck_idle or moved_x < anim_not_moving_epsilon or abs(velocity.x) < idle_velocity_threshold:
			new_animation = "idle"
		else:
			new_animation = "run"
	
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
	
	last_anim_position = global_position
