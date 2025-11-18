extends BaseEnemy

@export var flight_height := 80.0  # How high above ground to fly
@export var hover_speed := 60.0    # Up/down hover movement speed
@export var dive_attack_speed := 300.0  # Speed when diving at player
@export var dive_cooldown := 3.0   # Cooldown between dive attacks

var initial_y: float
var hover_direction := 1.0
var hover_timer := 0.0
var is_diving := false
var dive_timer := 0.0
var original_knockback_force: float

func _initialize_enemy():
	gravity = 0  # Flying enemies ignore gravity
	initial_y = global_position.y
	original_knockback_force = enemy_knockback_force
	
	# Flying melee enemies are faster and have longer attack range
	base_speed = 60
	attack_range = 80
	attack_cooldown = 1.2
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
	
	# Handle hover movement and dive cooldown
	handle_hover_movement(delta)
	if dive_timer > 0:
		dive_timer -= delta * Global.global_time_scale
	
	# Check for dive attacks
	if is_enemy_chase and player and not is_diving and dive_timer <= 0 and not Global.camouflage and not dead and not taking_damage:
		var distance = global_position.distance_to(player.global_position)
		if distance <= attack_range * 1.5:  # Longer range for dive initiation
			start_dive_attack()
	
	# Regular attack check (for when close but not diving)
	if is_enemy_chase and player and can_attack and not is_diving and not Global.camouflage and not dead and not taking_damage:
		var distance = global_position.distance_to(player.global_position)
		if distance <= attack_range:
			start_attack()
	
	move(delta)
	handle_animation()
	move_and_slide()

func handle_hover_movement(delta):
	if is_diving:
		return  # No hover during dive
	
	# Gentle up/down hover movement
	hover_timer += delta
	if hover_timer >= 1.5:  # Change hover direction every 1.5 seconds
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
		velocity.y = knockback_dir.y * abs(enemy_knockback_force) * 0.5
		is_roaming = false
		return
		
	if is_dealing_damage or is_diving:
		# No horizontal movement during attack or dive (dive has its own movement)
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
		velocity.y += y_diff * 2.0 * delta
	else:
		is_roaming = true
		velocity.x = dir.x * speed * 0.6  # Slower when roaming
		
		# Maintain flight height while roaming
		var target_y = initial_y - flight_height
		var y_diff = target_y - global_position.y
		velocity.y += y_diff * 2.0 * delta

func start_dive_attack():
	if not is_diving and dive_timer <= 0 and player:
		is_diving = true
		print("Flying melee enemy dive attacking")
		
		# Store original position for return
		var start_position = global_position
		
		# Face the player
		dir.x = sign(player.global_position.x - global_position.x)
		
		# Dive towards player
		var dive_direction = (player.global_position - global_position).normalized()
		velocity = dive_direction * dive_attack_speed
		
		# Wait for dive to complete or hit player
		await get_tree().create_timer(0.5).timeout
		
		# Deal damage at end of dive
		if player and global_position.distance_to(player.global_position) <= attack_range:
			deal_dive_damage()
		
		# Return to original height
		var return_tween = create_tween()
		return_tween.tween_property(self, "global_position", Vector2(global_position.x, start_position.y), 0.8)
		await return_tween.finished
		
		# Reset dive state
		is_diving = false
		dive_timer = dive_cooldown
		velocity = Vector2.ZERO

func start_attack():
	if can_attack and player and not dead and not taking_damage and not is_diving:
		attack_target = player
		is_dealing_damage = true
		has_dealt_damage = false
		can_attack = false
		
		print("Flying melee enemy attacking")
		
		# Face the player when attacking
		dir.x = sign(player.global_position.x - global_position.x)
		
		# Wait for attack animation
		await get_tree().create_timer(0.3).timeout
		
		# Deal damage
		deal_melee_damage()
		
		# Finish attack animation
		await get_tree().create_timer(0.2).timeout
		is_dealing_damage = false
		
		# Start cooldown
		attack_cooldown_timer.start(attack_cooldown)

func deal_melee_damage():
	if attack_target and attack_target is Player and attack_target.can_take_damage and not attack_target.dead:
		var knockback_dir = (attack_target.global_position - global_position).normalized()
		Global.enemyAknockback = knockback_dir * knockback_force
		attack_target.take_damage(enemy_damage)
		print("Flying melee enemy dealt damage: ", enemy_damage)

func deal_dive_damage():
	if player and player is Player and player.can_take_damage and not player.dead:
		var knockback_dir = (player.global_position - global_position).normalized()
		Global.enemyAknockback = knockback_dir * (knockback_force * 1.5)  # Stronger knockback from dive
		player.take_damage(enemy_damage * 2)  # Double damage from dive
		print("Flying melee dive attack dealt damage: ", enemy_damage * 2)

func handle_animation():
	var new_animation := ""
	
	if dead:
		new_animation = "death"
	elif taking_damage:
		new_animation = "hurt"
	elif is_diving:
		new_animation = "attack"  # Special dive animation
	elif is_dealing_damage:
		new_animation = "attack"
	else:
		new_animation = "run"  # Use "fly" animation
		# Update direction for sprite
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

# Flying enemies don't use ground-based gravity
func _physics_process(delta):
	# Override parent physics to remove gravity
	pass
