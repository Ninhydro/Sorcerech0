extends BaseEnemy

@export var flight_height := 100.0  # How high above ground to fly
@export var hover_speed := 50.0     # Up/down hover movement speed
@export var dive_attack_speed := 250.0  # Speed when diving at player
@export var dive_cooldown := 2.0   # Cooldown between dive attacks

var initial_y: float
var hover_direction := 1.0
var hover_timer := 0.0
var is_diving := false
var dive_timer := 0.0

func _initialize_enemy():
	attack_windup_time = 0.3
	attack_type = AttackType.MELEE  # Set as melee
	attack_range = 80  # Close range for melee attacks
	gravity = 0  # Flying enemies ignore gravity
	initial_y = global_position.y
	
	# Flying enemies are faster
	base_speed = 60
	use_edge_detection = false

func _ready():
	# Call parent ready first
	super._ready()
	
	# Debug: Check if hitbox exists
	if has_node("Hitbox"):
		print("Flying melee enemy: Hitbox found")
		var hitbox_collision = $Hitbox/CollisionShape2D
		if hitbox_collision:
			print("Flying melee enemy: Hitbox collision shape found, disabled=", hitbox_collision.disabled)
	else:
		print("Flying melee enemy: No Hitbox found!")

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
		if distance <= attack_range * 1.2:  # Slightly longer range for dive initiation
			start_dive_attack()
	
	move(delta)
	handle_animation()
	move_and_slide()

func handle_hover_movement(delta):
	if is_diving or is_dealing_damage or is_preparing_attack:
		return  # No hover during special states
	
	# Gentle up/down hover movement
	hover_timer += delta
	if hover_timer >= 2.0:  # Change hover direction every 2 seconds
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
		velocity.y = knockback_dir.y * abs(enemy_knockback_force) * 0.5  # Less vertical knockback
		is_roaming = false
		return
		
	if is_dealing_damage or is_diving or is_preparing_attack:
		# No movement during attack states (dive has its own movement)
		if not is_diving:  # Only stop movement if not diving
			velocity.x = 0
			velocity.y = 0
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
		velocity.y += y_diff * 2.0 * delta  # Smooth height adjustment
	else:
		is_roaming = true
		velocity.x = dir.x * speed * 0.7  # Slower when roaming
		
		# Maintain flight height while roaming
		var target_y = initial_y - flight_height
		var y_diff = target_y - global_position.y
		velocity.y += y_diff * 2.0 * delta

func start_dive_attack():
	if not is_diving and dive_timer <= 0 and player:
		is_diving = true
		can_attack = false  # Prevent other attacks during dive
		print("Flying melee enemy dive attacking")
		
		# Store original position for return
		var start_position = global_position
		
		# Face the player
		dir.x = sign(player.global_position.x - global_position.x)
		
		# Dive towards player
		var dive_direction = (player.global_position - global_position).normalized()
		velocity = dive_direction * dive_attack_speed
		
		# Wait for dive to complete
		await get_tree().create_timer(0.6).timeout
		
		# FIX: Increase the damage range from 25 to 40
		if player and global_position.distance_to(player.global_position) <= 40:  # INCREASED RANGE
			deal_dive_damage()
		else:
			print("Dive attack missed - distance: ", global_position.distance_to(player.global_position))
		
		# Return to original height
		var return_tween = create_tween()
		return_tween.tween_property(self, "global_position:y", start_position.y, 0.8)
		return_tween.parallel().tween_property(self, "velocity", Vector2.ZERO, 0.5)
		await return_tween.finished
		
		# Reset dive state
		is_diving = false
		dive_timer = dive_cooldown
		can_attack = true

func deal_dive_damage():
	if player and player is Player and player.can_take_damage and not player.dead:
		var knockback_dir = (player.global_position - global_position).normalized()
		Global.enemyAknockback = knockback_dir * (knockback_force * 1.5)  # Stronger knockback from dive
		player.take_damage(enemy_damage)
		print("Flying melee dive attack dealt damage: ", enemy_damage)

func handle_animation():
	var new_animation := ""
	
	if dead:
		new_animation = "death"
	elif taking_damage:
		new_animation = "hurt"
	elif is_diving:
		new_animation = "attack"  # Use attack animation for dive
	elif is_dealing_damage:
		new_animation = "attack"
	elif is_preparing_attack:
		new_animation = "idle"
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

# Handle hitbox collisions - IMPORTANT: Make sure this is connected!
func _on_hitbox_area_entered(area):
	#print("=== ROCKET COLLISION DEBUG ===")
	#print("Area name: ", area.name)
	#print("Area class: ", area.get_class())
	#print("Area parent: ", area.get_parent().name if area.get_parent() else "No parent")
	#print("Area parent class: ", area.get_parent().get_class() if area.get_parent() else "No parent")
	
	# Check if it's a rocket by checking methods
	#print("Has deal_damage: ", area.has_method("deal_damage"))
	#print("Has apply_damage: ", area.has_method("apply_damage"))
	#print("Has on_hit: ", area.has_method("on_hit"))
	
	#if area.get_parent():
		#print("Parent has deal_damage: ", area.get_parent().has_method("deal_damage"))
		#print("Parent has apply_damage: ", area.get_parent().has_method("apply_damage"))
		#print("Parent has on_hit: ", area.get_parent().has_method("on_hit"))
	
		#print("=== END DEBUG ===")
	#print("Flying melee enemy hitbox entered by: ", area.name)
	
	# Handle enemy taking damage from player rockets with their own damage system
	if area.has_method("deal_damage") or area.has_method("apply_damage"):
		print("Flying melee enemy hit by damage-dealing projectile!")
		# Let the rocket handle the damage
		pass
	
	# Handle rockets that need to be manually triggered
	elif "Rocket" in str(area) or "Projectile" in str(area):
		print("Flying melee enemy triggering rocket hit!")
		if area.has_method("on_enemy_hit"):
			area.on_enemy_hit(self)
		elif area.get_parent() and area.get_parent().has_method("on_enemy_hit"):
			area.get_parent().on_enemy_hit(self)
	
	# Handle melee attacks (this part works)
	elif area.name == "DealAttackArea" or area.get_parent() == Global.playerBody:
		print("Flying melee enemy taking damage from player attack!")
		var damage = Global.playerDamageAmount
		take_damage(damage)
# Flying enemies don't use ground-based gravity
func _physics_process(delta):
	# Override parent physics to remove gravity
	pass
