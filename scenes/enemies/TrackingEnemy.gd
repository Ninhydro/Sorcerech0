extends BaseEnemy

@export var dash_speed_multiplier := 2.5
@export var dash_duration := 0.8
@export var dash_cooldown := 3.0
@export var extended_chase_range := 400.0  # Much larger detection range

var is_dashing := false
var dash_timer: Timer
var can_dash := true

func _initialize_enemy():
	base_speed = 80  # Faster base speed
	attack_range = 50.0
	
	# Increase the RangeChase area size in code
	if $RangeChase/CollisionShape2D.shape is CircleShape2D:
		$RangeChase/CollisionShape2D.shape.radius = extended_chase_range / 2
	
	# Dash timer
	dash_timer = Timer.new()
	dash_timer.one_shot = true
	add_child(dash_timer)
	dash_timer.timeout.connect(_on_dash_cooldown_timeout)

func _process(delta):
	super._process(delta)
	
	# Dash when player is detected and not already attacking
	if is_enemy_chase and player and can_dash and not is_dashing and not is_dealing_damage and not taking_damage:
		start_dash()

func move(delta):
	if is_dashing:
		# Dash directly at player
		var dash_direction = (player.global_position - global_position).normalized()
		velocity = dash_direction * (base_speed * dash_speed_multiplier) * Global.global_time_scale
		return
	
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
		var dir_to_player = (player.global_position - global_position).normalized()
		velocity.x = dir_to_player.x * speed
		dir.x = sign(velocity.x)
	else:
		is_roaming = true
		velocity.x = dir.x * speed

func start_dash():
	if can_dash and player and not dead:
		print("Fast enemy dashing!")
		is_dashing = true
		can_dash = false
		
		# Dash effect
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.YELLOW, 0.1)
		
		# Dash for duration
		await get_tree().create_timer(dash_duration).timeout
		
		is_dashing = false
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
		
		# Start dash cooldown
		dash_timer.start(dash_cooldown)

func _on_dash_cooldown_timeout():
	can_dash = true
	print("Dash ready!")

func handle_animation():
	var new_animation := ""
	
	if dead:
		new_animation = "death"
	elif taking_damage:
		new_animation = "hurt"
	elif is_dealing_damage:
		new_animation = "attack"
	elif is_dashing:
		new_animation = "dash"  # Special dash animation
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
