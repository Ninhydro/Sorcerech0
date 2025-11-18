extends BaseEnemy

@export var projectile_scene: PackedScene = preload("res://scenes/enemies/Projectile_enemy.tscn")
@export var projectile_speed := 180.0
@export var shoot_range := 200.0
@export var projectile_lifetime := 2.5

@export var shield_health := 60
@export var shield_active := false
@export var shield_activate_delay := 0.3
@export var shield_auto_disable_time := 10.0  # Time after which shield automatically disables

var current_shield_health: float
var has_taken_first_hit := false
var shield_activation_timer := 0.0
var shield_idle_timer := 0.0
var last_hit_time := 0.0

@onready var shield_sprite := $ShieldSprite
#@onready var shield_animation_player := $ShieldAnimationPlayer
@onready var projectile_spawn := $ProjectileSpawn

func _initialize_enemy():
	current_shield_health = shield_health
	attack_range = shoot_range
	update_shield_visual()
	
	# Slow speed properties
	base_speed = 25
	enemy_damage = 12
	health = 100
	attack_cooldown = 2.0
	use_edge_detection = true
	
func _process(delta):
	super._process(delta)
	
	# Handle shield activation delay
	if has_taken_first_hit and not shield_active and shield_activation_timer > 0:
		shield_activation_timer -= delta * Global.global_time_scale
		if shield_activation_timer <= 0:
			activate_shield()
	
	# Handle shield auto-disable timer
	if shield_active:
		shield_idle_timer += delta * Global.global_time_scale
		if shield_idle_timer >= shield_auto_disable_time:
			reset_shield()
			print("Shield automatically disabled after ", shield_auto_disable_time, " seconds")

func take_damage(damage):
	# Update last hit time
	last_hit_time = Time.get_ticks_msec() / 1000.0
	
	# Reset shield idle timer when taking damage
	if shield_active:
		shield_idle_timer = 0.0

	# Check if this is the first hit
	if not has_taken_first_hit:
		has_taken_first_hit = true
		shield_activation_timer = shield_activate_delay
		print("First hit! Shield will activate in ", shield_activate_delay, " seconds")
		
		# Take normal damage on first hit
		super.take_damage(damage)
		
	elif shield_active and current_shield_health > 0:
		# Shield takes damage
		current_shield_health -= damage
		taking_damage = true
		
		# Shield hit effect
		#if shield_animation_player:
		#	shield_animation_player.play("shield_hit")
		
		if current_shield_health <= 0:
			current_shield_health = 0
			deactivate_shield()
	else:
		# Take normal damage when shield is broken or not active
		super.take_damage(damage)

func activate_shield():
	shield_active = true
	shield_idle_timer = 0.0  # Reset idle timer when shield activates
	print("Shield activated!")
	
	# Play shield activation animation
	#if shield_animation_player:
	#	shield_animation_player.play("shield_activate")
	
	# Update shield visual
	update_shield_visual()
	
	# Stop moving when shield is active
	base_speed = 0

func deactivate_shield():
	shield_active = false
	
	# Play shield break animation
	#if shield_animation_player:
	#	shield_animation_player.play("shield_break")
	
	# Resume movement (slower after shield breaks)
	base_speed = 15
	
	# Update shield visual
	update_shield_visual()

func reset_shield():
	shield_active = false
	has_taken_first_hit = false
	current_shield_health = shield_health
	shield_idle_timer = 0.0
	
	# Resume normal movement speed
	base_speed = 25
	
	# Play shield deactivation animation
	#if shield_animation_player:
	#	shield_animation_player.play("shield_deactivate")
	
	# Update shield visual
	update_shield_visual()
	
	print("Shield reset - ready to activate again on next hit")

func update_shield_visual():
	if shield_active:
		shield_sprite.visible = true
		shield_sprite.modulate.a = 0.5
	else:
		shield_sprite.visible = false

func move(delta):
	# If shield is active, don't move
	if shield_active:
		velocity.x = 0
		is_roaming = false
		return
	
	# Otherwise use normal movement
	super.move(delta)

func start_attack():
	# Can't attack while shield is active
	if shield_active:
		return
	
	if can_attack and player and not dead and not taking_damage:
		attack_target = player
		is_dealing_damage = true
		has_dealt_damage = false
		can_attack = false
		
		print("Shield ranged enemy shooting")
		
		# Face the player when shooting
		dir.x = sign(player.global_position.x - global_position.x)
		
		# Update projectile spawn position
		if has_node("ProjectileSpawn"):
			var projectile_spawn = $ProjectileSpawn
			projectile_spawn.position.x = abs(projectile_spawn.position.x) * dir.x
		
		# Wait for shoot animation
		await get_tree().create_timer(0.4).timeout
		
		# Shoot projectile
		shoot_projectile()
		
		# Finish attack animation
		await get_tree().create_timer(0.3).timeout
		is_dealing_damage = false
		
		# Start cooldown
		attack_cooldown_timer.start(attack_cooldown)

func shoot_projectile():
	if projectile_scene and player:
		var projectile = projectile_scene.instantiate()
		get_tree().current_scene.add_child(projectile)
		
		projectile.global_position = projectile_spawn.global_position
		projectile.set_direction(Vector2(dir.x, 0))
		projectile.speed = projectile_speed
		projectile.damage = enemy_damage
		projectile.lifetime = projectile_lifetime

func handle_animation():
	var new_animation := ""
	
	if dead:
		new_animation = "death"
	elif taking_damage:
		new_animation = "hurt"
	elif shield_active:
		new_animation = "idle"  # Special idle animation when shield is active
	elif is_dealing_damage:
		new_animation = "attack"
	else:
		new_animation = "run"
		if dir.x == -1:
			sprite.flip_h = true
			if shield_sprite:
				shield_sprite.flip_h = true
		elif dir.x == 1:
			sprite.flip_h = false
			if shield_sprite:
				shield_sprite.flip_h = false
		
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
