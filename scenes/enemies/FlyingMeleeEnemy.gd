extends BaseEnemy

@export var explosion_damage := 25
@export var explosion_radius := 80.0
@export var warning_time := 1.0
@export var charge_speed := 150.0

var is_charging := false
var is_exploding := false

func _initialize_enemy():
	gravity = 0  # Flying - now this works
	attack_range = 40.0  # Very close for melee/explosion

func _process(delta):
	if $AnimationPlayer:
		$AnimationPlayer.speed_scale = Global.global_time_scale
	
	player = Global.playerBody
	
	if Global.playerAlive and not Global.camouflage and range:
		is_enemy_chase = true
	else:
		is_enemy_chase = false
	
	# Check for explosion range
	if is_enemy_chase and player and can_attack and not Global.camouflage and not dead and not taking_damage:
		var distance = global_position.distance_to(player.global_position)
		if distance <= attack_range:
			start_attack()
	
	move(delta)
	handle_animation()
	move_and_slide()

func move(delta):
	if dead or is_exploding:
		velocity = Vector2.ZERO
		return
	
	if taking_damage:
		var knockback_dir = (global_position - player.global_position).normalized()
		velocity = knockback_dir * abs(enemy_knockback_force)
		return
		
	if is_charging:
		# Charge directly at player
		var direction = (player.global_position - global_position).normalized()
		velocity = direction * charge_speed
		dir.x = sign(velocity.x)
		return
		
	if is_enemy_chase and player:
		# Standard flying chase
		var direction = (player.global_position - global_position).normalized()
		velocity = direction * speed
		dir.x = sign(velocity.x)
	else:
		velocity.x = dir.x * speed * 0.5

func start_attack():
	if can_attack and player and not dead and not taking_damage:
		attack_target = player
		can_attack = false
		
		print("Flying melee enemy charging!")
		
		# Start charge attack
		is_charging = true
		
		# Warning effect (flash red)
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.RED, 0.2)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)
		tween.set_loops(3)
		
		await get_tree().create_timer(warning_time).timeout
		
		# Explode when close enough or after charge time
		var charge_timer = get_tree().create_timer(2.0)
		var distance_check_timer = get_tree().create_timer(0.1)
		
		while not is_exploding and charge_timer.time_left > 0:
			var distance = global_position.distance_to(player.global_position)
			if distance <= 20.0:  # Very close range for explosion
				break
			await distance_check_timer.timeout
			distance_check_timer = get_tree().create_timer(0.1)
		
		explode()

func explode():
	is_exploding = true
	is_charging = false
	print("Flying melee enemy exploding!")
	
	# Play explosion animation
	animation_player.play("explode")
	
	# Check if player is in explosion radius
	var distance = global_position.distance_to(player.global_position)
	if distance <= explosion_radius:
		var knockback_dir = (player.global_position - global_position).normalized()
		Global.enemyAknockback = knockback_dir * knockback_force * 2.0  # Stronger knockback
		player.take_damage(explosion_damage)
	
	# Wait for explosion animation then die
	await animation_player.animation_finished
	handle_death()

func handle_animation():
	var new_animation := ""
	
	if is_exploding:
		new_animation = "explode"
	elif dead:
		new_animation = "death"
	elif taking_damage:
		new_animation = "hurt"
	elif is_charging:
		new_animation = "charge"
	else:
		new_animation = "fly"
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
