extends BaseEnemy
class_name FlyingMeleeDrone

@export var flight_height: float = 100.0    # How high above spawn it likes to hover
@export var hover_speed: float = 50.0       # Up/down bobbing speed
@export var melee_range: float = 40.0       # Distance to start melee attack

var initial_y: float
var hover_direction: float = 1.0
var hover_timer: float = 0.0

func _initialize_enemy() -> void:
	# Configure this enemy as a flying melee unit
	attack_type = AttackType.MELEE
	attack_range = melee_range
	attack_windup_time = 0.1
	

	gravity = 0.0                # No gravity for flying
	base_speed = 80.0            # A bit fast
	use_edge_detection = false   # No edges in the air

	initial_y = global_position.y

func _process(delta: float) -> void:
	# Animation time scale
	if $AnimationPlayer:
		$AnimationPlayer.speed_scale = Global.global_time_scale

	player = Global.playerBody

	# Basic chase toggle based on your global flags + range area
	if Global.playerAlive and not Global.camouflage and range:
		is_enemy_chase = true
	else:
		is_enemy_chase = false

	# Hover motion (unless in special state)
	_handle_hover_movement(delta)

	# Check melee attack condition (uses BaseEnemy's attack system)
	if is_enemy_chase and player and can_attack and not Global.camouflage and not dead and not taking_damage:
		var distance := global_position.distance_to(player.global_position)
		if distance <= attack_range:
			start_attack()

	_move_logic(delta)
	_handle_animation()
	move_and_slide()

func _handle_hover_movement(delta: float) -> void:
	if dead or taking_damage or is_dealing_damage or is_preparing_attack:
		return

	hover_timer += delta
	if hover_timer >= 2.0:
		hover_direction *= -1.0
		hover_timer = 0.0

	# Simple up/down bob
	velocity.y = hover_direction * hover_speed * Global.global_time_scale

func _move_logic(delta: float) -> void:
	if dead:
		velocity = Vector2.ZERO
		return

	if taking_damage:
		# Knockback from player direction (if known)
		if player:
			var knockback_dir := (global_position - player.global_position).normalized()
			velocity.x = knockback_dir.x * abs(enemy_knockback_force)
			velocity.y = knockback_dir.y * abs(enemy_knockback_force) * 0.5
		is_roaming = false
		return

	if is_dealing_damage or is_preparing_attack:
		velocity.x = 0.0
		is_roaming = false
		return

	if is_enemy_chase and player:
		is_roaming = false
		var dir_to_player := (player.global_position - global_position).normalized()
		velocity.x = dir_to_player.x * speed
		dir.x = sign(velocity.x)

		# Maintain flight band
		var target_y := initial_y - flight_height
		var y_diff := target_y - global_position.y
		velocity.y += y_diff * 2.0 * delta
	else:
		is_roaming = true
		velocity.x = dir.x * speed * 0.7

		var target_y := initial_y - flight_height
		var y_diff := target_y - global_position.y
		velocity.y += y_diff * 2.0 * delta

func _handle_animation() -> void:
	var new_anim := ""

	if dead:
		new_anim = "death"
	elif taking_damage:
		new_anim = "hurt"
	elif is_dealing_damage:
		new_anim = "attack"
	elif is_preparing_attack:
		new_anim = "idle"
	else:
		if abs(velocity.x) < idle_velocity_threshold:
			new_anim = "idle"
		else:
			new_anim = "run"

		# Sprite flip
		if dir.x == -1:
			sprite.flip_h = true
		elif dir.x == 1:
			sprite.flip_h = false

	if new_anim != current_animation:
		current_animation = new_anim
		animation_player.play(new_anim)

		if new_anim == "hurt":
			# Let BaseEnemy's hit_stun_timer control taking_damage; this wait is just to keep anim visible.
			await get_tree().create_timer(0.1).timeout
		elif new_anim == "death":
			await animation_player.animation_finished
			handle_death()

# No gravity physics from BaseEnemy
func _physics_process(delta: float) -> void:
	pass
func is_player_in_attack_range() -> bool:
	if not player or not is_instance_valid(player):
		return false

	# Separate horizontal and vertical checks so enemy doesn't hit from weird angles
	var dx = abs(player.global_position.x - global_position.x)
	var dy = abs(player.global_position.y - global_position.y)
	print("dx: ", dx)
	print("dy: ", dy)
	# Horizontal reach = attack_range, vertical tolerance = 24 px (tweak as needed)
	return dx <= 30 and dy <= 25

# ===== DAMAGE HANDLING VIA HITBOX =====
# Connect Hitbox.area_entered to this in the editor
#func _on_hitbox_area_entered(area: Area2D) -> void:
	# 1) Rocket hit (Area2D)
#	if area is Rocket:
#		print("Drone hit by rocket via Hitbox!")
#		take_damage(area.damage)
#		area.queue_free()
#		return

	# 2) Player melee
	# Only count the actual attack Area2D, not any player area
#	if area.name == "DealAttackArea" or area.is_in_group("AttackArea"):
#		print("Drone hit by player melee via Hitbox!")
#		take_damage(Global.playerDamageAmount)
#		return
