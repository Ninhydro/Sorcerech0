extends BaseEnemy
class_name MagusKingBoss

signal boss_died

# =====================================================
# CONFIG - ADDED MELEE ATTACK CONFIG
# =====================================================
@export var move_speed := 80.0
@export var melee_range := 50.0
@export var chase_range := 300.0
@export var melee_damage := 20  # ADDED
@export var melee_cooldown := 2.0  # ADDED

@export var summon_scene: PackedScene  # SET THIS IN INSPECTOR!
@export var laser_area: Area2D
@export var laser_damage := 20
@export var laser_duration := 0.3  # ADDED
@export var laser_windup := 0.6  # ADDED
@export var laser_recovery := 1.0  # ADDED

@export var summon_cooldown := 5.0
@export var laser_cooldown := 4.0
@export var teleport_cooldown := 2.0
@export var attack_interval := 3.0
@export var laser_chance := 0.3
@export var melee_chance := 0.5  # ADDED - Chance to use melee attack when available

# Platform markers
var platform_low: Marker2D
var platform_mid: Marker2D
var platform_high: Marker2D
var current_platform: Marker2D  # Where the boss CURRENTLY IS
var target_platform: Marker2D   # Where the boss SHOULD GO (NEW!)

# =====================================================
# NODES - ADDED MELEE NODES
# =====================================================
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var summon_marker: Marker2D = $SummonMarker
@onready var melee_hitbox: Area2D = $MeleeHitbox  # ADD THIS NODE IN SCENE!
@onready var laser_beam: Sprite2D = $LaserBeam/Sprite2D  # ADD THIS FOR VISUAL LASER
@onready var laser_collision: CollisionShape2D = $LaserBeam/CollisionShape2D  # FOR LASER COLLISION

# =====================================================
# STATE - ADDED MELEE STATE
# =====================================================
var attack_running := false
var was_taking_damage := false
var is_casting := false
var is_teleporting := false
var ai_active := false
var platforms_set := false
var invulnerable_during_attack := false  # ADDED - similar to Sterling

# Attack cooldowns
var can_summon := true
var can_laser := true
var can_teleport := true
var can_melee := true  # ADDED

# Timers
var summon_timer: Timer
var laser_timer: Timer
var teleport_timer: Timer
var attack_decision_timer: Timer
var melee_timer: Timer  # ADDED

# Debug tracking
var debug_frame_count := 0
var last_attack_decision_time := 0.0
var laser_active := false  # ADDED: Track if laser is currently active
var laser_duration_timer: Timer  # ADDED: For laser duration


# =====================================================
# READY - UPDATED WITH MELEE SETUP
# =====================================================
func _ready() -> void:
	super._ready()
	
	add_to_group("boss")
	
	# Disable BaseEnemy systems
	is_enemy_chase = false
	is_roaming = false
	use_edge_detection = false
	can_jump_chase = false
	
	# Boss-specific initialization
	health = 300
	dead = false
	
	print("MAGUS KING: _ready() called, health=", health, " player exists=", (Global.playerBody != null))
	
	# Initialize melee hitbox if exists
	if melee_hitbox:
		melee_hitbox.monitoring = false
		melee_hitbox.area_entered.connect(_on_melee_hit)
		print("MAGUS KING: Melee hitbox initialized")
	
	# Initialize laser if exists
	if laser_beam:
		laser_beam.visible = false
		print("MAGUS KING: Laser beam sprite initialized")
		print("MAGUS KING: Laser beam texture: ", laser_beam.texture)
		print("MAGUS KING: Laser beam size: ", laser_beam.texture.get_size() if laser_beam.texture else "No texture")
	else:
		print("MAGUS KING: ERROR - laser_beam is null!")
	
	if laser_collision:
		laser_collision.disabled = true
		print("MAGUS KING: Laser collision initialized")
	
	# Initialize timers
	summon_timer = Timer.new()
	summon_timer.one_shot = true
	add_child(summon_timer)
	summon_timer.timeout.connect(_on_summon_cooldown_timeout)
	
	laser_timer = Timer.new()
	laser_timer.one_shot = true
	add_child(laser_timer)
	laser_timer.timeout.connect(_on_laser_cooldown_timeout)
	
	teleport_timer = Timer.new()
	teleport_timer.one_shot = true
	add_child(teleport_timer)
	teleport_timer.timeout.connect(_on_teleport_cooldown_timeout)
	
	melee_timer = Timer.new()  # ADDED
	melee_timer.one_shot = true
	add_child(melee_timer)
	melee_timer.timeout.connect(_on_melee_cooldown_timeout)
	
	laser_duration_timer = Timer.new()
	laser_duration_timer.one_shot = true
	add_child(laser_duration_timer)
	laser_duration_timer.timeout.connect(_on_laser_duration_timeout)
	
	attack_decision_timer = Timer.new()
	attack_decision_timer.one_shot = false
	attack_decision_timer.wait_time = attack_interval
	add_child(attack_decision_timer)
	attack_decision_timer.timeout.connect(_on_attack_decision_timeout)
	
	# Initialize laser area if it exists (for backward compatibility)
	if laser_area:
		laser_area.monitoring = false
		print("MAGUS KING: Laser area initialized (legacy)")
	
	print("MAGUS KING: Ready complete, waiting for platform setup")

# =====================================================
# PLATFORM SETUP (UNCHANGED)
# =====================================================
func set_platform_markers(low: Marker2D, mid: Marker2D, high: Marker2D) -> void:
	print("MAGUS KING: set_platform_markers called!")
	print("  Low: ", low, " at ", low.global_position if low else "null")
	print("  Mid: ", mid, " at ", mid.global_position if mid else "null")
	print("  High: ", high, " at ", high.global_position if high else "null")
	
	platform_low = low
	platform_mid = mid
	platform_high = high
	
	platforms_set = true
	
	# Start at low platform
	current_platform = platform_low
	if platform_low:
		global_position = platform_low.global_position
		print("MAGUS KING: Position set to low platform: ", global_position)
		
		# Start AI immediately
		_start_ai()
	else:
		print("MAGUS KING: ERROR - platform_low is null!")

# =====================================================
# PROCESS - UPDATED WITH INVULNERABILITY
# =====================================================
func _process(delta: float) -> void:
	if not ai_active:
		return
		
	debug_frame_count += 1
	if debug_frame_count % 60 == 0:
		print("MAGUS KING: Frame ", debug_frame_count, ", AI active=", ai_active, ", dead=", dead, ", platforms_set=", platforms_set)
		print("  Position: ", global_position, ", Velocity: ", velocity)
		print("  State: casting=", is_casting, ", teleporting=", is_teleporting, ", attack_running=", attack_running)
		print("  Cooldowns: summon=", can_summon, ", laser=", can_laser, ", teleport=", can_teleport, ", melee=", can_melee)
		
	if anim:
		anim.speed_scale = Global.global_time_scale

	if not is_on_floor():
		velocity.y += gravity * delta

	if taking_damage:
		print("MAGUS KING: In taking_damage state, health=", health)
		was_taking_damage = true
		velocity.x = 0.0
		
		if laser_active:
			_stop_laser()
			
		if anim.has_animation("hurt"):
			anim.play("hurt")
			print("MAGUS KING: Playing hurt animation")
			await anim.animation_finished
			print("MAGUS KING: Hurt animation finished")
		else:
			anim.play("idle")
			print("MAGUS KING: No hurt animation, playing idle")
			await get_tree().create_timer(0.3).timeout

		move_and_slide()
		
		taking_damage = false
		print("MAGUS KING: taking_damage reset to false")
		return

	if was_taking_damage:
		print("MAGUS KING: was_taking_damage cleanup")
		was_taking_damage = false
		velocity = Vector2.ZERO
		anim.play("idle")

	move_and_slide()

func take_damage(amount: int) -> void:
	print("MAGUS KING: take_damage called with amount=", amount)
	
	if dead or invulnerable_during_attack:
		print("MAGUS KING: Ignoring damage - dead:", dead, " invulnerable:", invulnerable_during_attack)
		return
	
	if taking_damage:
		print("MAGUS KING: Already taking damage, ignoring additional damage")
		return
	
	if laser_active:
		_stop_laser()
	
	
	health -= amount
	print("MAGUS KING: Health reduced to ", health)
	
	taking_damage = true
	print("MAGUS KING: taking_damage set to true")
	
	attack_running = false
	is_casting = false
	is_teleporting = false
	invulnerable_during_attack = false  # Reset invulnerability if hit
	
	velocity = Vector2.ZERO
	
	if health <= 0:
		print("MAGUS KING: Health <= 0, calling _die()")
		_die()

# =====================================================
# MAIN AI LOOP - UPDATED WITH MELEE CONDITION
# =====================================================
func _start_ai() -> void:
	print("MAGUS KING: _start_ai() called")
	
	if not platforms_set:
		print("MAGUS KING: ERROR - Platforms not set!")
		return
	
	if dead:
		print("MAGUS KING: Already dead, not starting AI")
		return
	
	ai_active = true
	print("MAGUS KING: AI activated, starting attack decision timer")
	
	attack_decision_timer.start()
	_run_ai()

func _run_ai() -> void:
	print("MAGUS KING: _run_ai() started")
	
	while not dead and ai_active:
		await get_tree().process_frame
		
		if debug_frame_count % 120 == 0:
			print("MAGUS KING: AI Loop - State check")
			print("  taking_damage: ", taking_damage)
			print("  attack_running: ", attack_running)
			print("  is_casting: ", is_casting)
			print("  is_teleporting: ", is_teleporting)
		
		if taking_damage or attack_running or is_casting or is_teleporting:
			if debug_frame_count % 180 == 0:
				print("MAGUS KING: AI Loop - Skipping due to active state")
			continue
		
		if not player or not is_instance_valid(player):
			player = Global.playerBody
			if not player:
				print("MAGUS KING: No player found, waiting...")
				await get_tree().create_timer(0.1).timeout
				continue
		
		# 1. FIRST: Check if we should teleport to player's platform
		_update_target_platform()
		
		if _should_teleport():
			print("MAGUS KING: _should_teleport returned true - Player is on different platform!")
			await _teleport_to_player_platform()
			continue
		
		# 2. SECOND: If on same platform, decide what to do
		var dist_to_player = global_position.distance_to(player.global_position)
		var same_platform = _on_same_platform()
		
		if debug_frame_count % 90 == 0:
			print("MAGUS KING: dist_to_player=", dist_to_player, ", same_platform=", same_platform, ", melee_range=", melee_range)
		
		if same_platform:
			if dist_to_player > melee_range:
				print("MAGUS KING: Same platform, chasing player")
				_chase_player()
				await get_tree().create_timer(0.1).timeout
			else:
				# In melee range, check if we should melee attack
				if can_melee and randf() < 0.3:  # 30% chance to melee when in range
					print("MAGUS KING: In melee range, attempting melee attack")
					await _attack_melee()
				else:
					print("MAGUS KING: In melee range, stopping")
					velocity.x = 0
					if anim.has_animation("idle"):
						anim.play("idle")
					await get_tree().create_timer(0.1).timeout
		else:
			print("MAGUS KING: Not on same platform, idling")
			velocity.x = 0
			if anim.has_animation("idle"):
				anim.play("idle")
			await get_tree().create_timer(0.1).timeout
	
	print("MAGUS KING: _run_ai() stopped - dead=", dead, " ai_active=", ai_active)

# =====================================================
# ATTACK DECISION TIMER - UPDATED FOR MELEE
# =====================================================
func _on_attack_decision_timeout() -> void:
	print("MAGUS KING: _on_attack_decision_timeout triggered")
	
	if dead or taking_damage or attack_running or is_casting or is_teleporting or not player:
		return
	
	var dist_to_player = global_position.distance_to(player.global_position)
	var same_platform = _on_same_platform()
	
	print("MAGUS KING: Attack Decision - dist=", dist_to_player, ", same_platform=", same_platform, ", chase_range=", chase_range)
	
	if same_platform and dist_to_player < chase_range:
		print("MAGUS KING: Conditions met, calling _choose_attack")
		_choose_attack(dist_to_player)
	else:
		print("MAGUS KING: Conditions NOT met")

# =====================================================
# ATTACK DECISION - UPDATED WITH MELEE OPTION
# =====================================================
func _choose_attack(dist_to_player: float) -> void:
	print("MAGUS KING: _choose_attack called with dist=", dist_to_player)
	
	attack_running = true
	velocity = Vector2.ZERO
	
	print("MAGUS KING: Cooldown status - can_summon=", can_summon, " can_laser=", can_laser, " can_melee=", can_melee)
	
	# Create a list of available attacks
	var available_attacks = []
	
	if can_summon and summon_scene:
		available_attacks.append("summon")
	
	if can_laser and laser_area:
		available_attacks.append("laser")
	
	if can_melee and dist_to_player <= melee_range * 1.5:  # Melee only if close
		available_attacks.append("melee")
	
	print("MAGUS KING: Available attacks: ", available_attacks)
	_attack_laser()
	"""
	if available_attacks.size() > 0:
		# Weighted selection based on distance and cooldowns
		var selected_attack = ""
		
		if dist_to_player <= melee_range and "melee" in available_attacks and randf() < melee_chance:
			selected_attack = "melee"
		elif "laser" in available_attacks and randf() < laser_chance:
			selected_attack = "laser"
		elif "summon" in available_attacks:
			selected_attack = "summon"
		else:
			# Fallback to first available
			selected_attack = available_attacks[0]
		
		print("MAGUS KING: Selected ", selected_attack, " attack")
		
		match selected_attack:
			"summon":
				await _attack_summon()
			"laser":
				await _attack_laser()
			"melee":
				await _attack_melee()
	else:
		print("MAGUS KING: All attacks unavailable or on cooldown, waiting")
		await get_tree().create_timer(1.0).timeout
	"""
	attack_running = false
	print("MAGUS KING: _choose_attack completed")

# =====================================================
# MELEE ATTACK - SIMILAR TO STERLING
# =====================================================
func _attack_melee() -> void:
	print("MAGUS KING: _attack_melee started")
	
	if not can_melee:
		print("MAGUS KING: Melee on cooldown, aborting")
		return
	
	invulnerable_during_attack = true
	attack_running = true
	can_melee = false
	velocity = Vector2.ZERO
	
	print("MAGUS KING: Starting melee attack sequence")
	
	# Face player
	if player:
		var dx = player.global_position.x - global_position.x
		sprite.flip_h = dx < 0
		print("MAGUS KING: Facing player for melee, dx=", dx)
	
	# Play melee animation
	if anim.has_animation("melee"):
		anim.play("melee")
	else:
		# Fallback to attack animation if melee doesn't exist
		if anim.has_animation("attack"):
			anim.play("attack")
		else:
			anim.play("idle")
	
	# Enable melee hitbox after a brief delay (when the attack would connect)
	await get_tree().create_timer(0.2).timeout
	
	if melee_hitbox and not dead:
		await get_tree().create_timer(0.2).timeout
		if not dead:
			melee_hitbox.monitoring = true
			print("MAGUS KING: Melee hitbox activated (backup)")
			await get_tree().create_timer(0.2).timeout
			melee_hitbox.monitoring = false
			print("MAGUS KING: Melee hitbox deactivated")
	# Wait for animation to finish
	await anim.animation_finished
	
	# Start cooldown
	melee_timer.start(melee_cooldown)
	
	invulnerable_during_attack = false
	attack_running = false
	print("MAGUS KING: _attack_melee completed")

func _on_melee_hit(area: Area2D) -> void:
	if area.is_in_group("player") or area.is_in_group("player_hurtbox"):
		print("MAGUS KING: Melee hit player!")
		# Damage the player
		if player and player.has_method("take_damage"):
			player.take_damage(melee_damage)

func _on_melee_cooldown_timeout() -> void:
	can_melee = true
	print("MAGUS KING: Melee cooldown ready")

# =====================================================
# LASER ATTACK - IMPROVED LIKE STERLING
# =====================================================
func _attack_laser() -> void:
	print("MAGUS KING: _attack_laser started")
	
	if not can_laser:
		print("MAGUS KING: Laser on cooldown, aborting")
		return
	
	invulnerable_during_attack = true
	is_casting = true
	can_laser = false
	velocity = Vector2.ZERO
	
	print("MAGUS KING: Starting laser attack sequence")
	
	# Face player
	if player:
		var dx = player.global_position.x - global_position.x
		sprite.flip_h = dx < 0
		print("MAGUS KING: Facing player for laser, dx=", dx)
	
	# Windup animation
	if anim.has_animation("cast"):
		anim.play("cast")
		# Wait for windup part of animation
		await get_tree().create_timer(laser_windup / Global.global_time_scale).timeout
	else:
		anim.play("idle")
		await get_tree().create_timer(laser_windup / Global.global_time_scale).timeout
	
	if taking_damage or dead:
		_stop_laser()
		invulnerable_during_attack = false
		is_casting = false
		return
	
	# START LASER HERE (NOT in animation callback)
	print("MAGUS KING: Starting laser visuals")
	_start_laser()
	
	# Wait for laser duration
	print("MAGUS KING: Laser active for ", laser_duration, " seconds")
	await get_tree().create_timer(laser_duration / Global.global_time_scale).timeout
	
	# Stop laser
	print("MAGUS KING: Stopping laser")
	_stop_laser()
	
	# Recovery time
	await get_tree().create_timer(laser_recovery / Global.global_time_scale).timeout
	
	laser_timer.start(laser_cooldown)
	
	invulnerable_during_attack = false
	is_casting = false
	print("MAGUS KING: _attack_laser completed")

func _do_laser_attack() -> void:
	print("MAGUS KING: _do_laser_attack called")
	
	if dead:
		return
	
	# FIXED: Set laser_active to true
	laser_active = true
	
	# Show laser beam sprite
	if laser_beam:
		laser_beam.visible = true
		# Adjust laser direction based on sprite flip
		if sprite.flip_h:
			laser_beam.scale.x = -abs(laser_beam.scale.x)
		else:
			laser_beam.scale.x = abs(laser_beam.scale.x)
	
	# Enable collisions
	if laser_collision:
		laser_collision.disabled = false
	
	# Legacy laser area support
	if laser_area:
		laser_area.monitoring = true
		if laser_area.has_node("CollisionShape2D"):
			laser_area.get_node("CollisionShape2D").disabled = false
			
func _stop_laser() -> void:
	if not laser_active:
		return
	
	print("MAGUS KING: Stopping laser attack")
	laser_active = false
	
	if laser_beam:
		laser_beam.visible = false
	
	if laser_collision:
		laser_collision.disabled = true
	
	if laser_area:
		laser_area.monitoring = false
		if laser_area.has_node("CollisionShape2D"):
			laser_area.get_node("CollisionShape2D").disabled = true

# =====================================================
# SUMMON ATTACK - UNCHANGED
# =====================================================
func _attack_summon() -> void:
	print("MAGUS KING: _attack_summon started")
	
	if not can_summon:
		print("MAGUS KING: Summon on cooldown, aborting")
		return
	
	if not summon_scene:
		print("MAGUS KING: ERROR - No summon_scene assigned in Inspector!")
		return
	
	is_casting = true
	can_summon = false
	
	print("MAGUS KING: Starting summon attack sequence")
	
	if player:
		var dx = player.global_position.x - global_position.x
		sprite.flip_h = dx < 0
		print("MAGUS KING: Facing player, dx=", dx)
	
	if anim.has_animation("summon"):
		anim.play("summon")
		await anim.animation_finished
	else:
		await get_tree().create_timer(1.0).timeout
	
	_do_summon()
	
	summon_timer.start(summon_cooldown)
	
	is_casting = false
	print("MAGUS KING: _attack_summon completed")

func _do_summon() -> void:
	print("MAGUS KING: _do_summon called")
	
	if not summon_scene or dead:
		return
	
	print("MAGUS KING: Instantiating minions")
	
	for i in range(1):
		var mob = summon_scene.instantiate()
		get_parent().add_child(mob)
		
		var offset = Vector2((i - 0.5) * 40, 0)
		mob.global_position = summon_marker.global_position + offset
		print("MAGUS KING: Summoned minion ", i, " at ", mob.global_position)

func _on_summon_cooldown_timeout() -> void:
	can_summon = true
	print("MAGUS KING: Summon cooldown ready")

func _on_laser_cooldown_timeout() -> void:
	can_laser = true
	print("MAGUS KING: Laser cooldown ready")

# =====================================================
# TELEPORT SYSTEM - UNCHANGED
# =====================================================
func _update_target_platform() -> void:
	if not player or not platform_low:
		return
	
	var player_y = player.global_position.y
	var low_y = platform_low.global_position.y
	var mid_y = platform_mid.global_position.y
	var high_y = platform_high.global_position.y
	
	var low_dist = abs(player_y - low_y)
	var mid_dist = abs(player_y - mid_y)
	var high_dist = abs(player_y - high_y)
	
	if high_dist < mid_dist and high_dist < low_dist:
		target_platform = platform_high
	elif mid_dist < low_dist:
		target_platform = platform_mid
	else:
		target_platform = platform_low
	
	if debug_frame_count % 150 == 0:
		print("MAGUS KING: Player closest to ", target_platform.name, " (Y=", target_platform.global_position.y, ")")
		print("MAGUS KING: Boss currently at ", current_platform.name, " (Y=", current_platform.global_position.y, ")")

func _should_teleport() -> bool:
	if not can_teleport:
		return false
	
	if not current_platform or not target_platform or not player:
		return false
	
	var player_on_different_platform = (target_platform != current_platform)
	
	if debug_frame_count % 120 == 0:
		print("MAGUS KING: _should_teleport check")
		print("  Boss platform: ", current_platform.name, " at Y=", current_platform.global_position.y)
		print("  Player platform: ", target_platform.name, " at Y=", target_platform.global_position.y)
		print("  Player Y: ", player.global_position.y)
		print("  Different platform? ", player_on_different_platform)
	
	return player_on_different_platform

func _teleport_to_player_platform() -> void:
	print("MAGUS KING: _teleport_to_player_platform started")
	
	if not can_teleport or not target_platform or is_teleporting:
		return
	
	is_teleporting = true
	can_teleport = false
	velocity = Vector2.ZERO
	
	print("MAGUS KING: Teleporting from ", current_platform.name, " to ", target_platform.name)
	
	if anim.has_animation("teleport"):
		anim.play("teleport")
		await anim.animation_finished
	else:
		sprite.modulate = Color(0.5, 0.5, 1.0, 0.5)
		await get_tree().create_timer(0.3).timeout
	
	var old_position = global_position
	current_platform = target_platform
	global_position = target_platform.global_position
	
	print("MAGUS KING: Teleported from ", old_position, " to ", global_position)
	print("MAGUS KING: Now at platform: ", current_platform.name)
	
	sprite.modulate = Color.WHITE
	
	teleport_timer.start(teleport_cooldown)
	
	is_teleporting = false
	print("MAGUS KING: _teleport_to_player_platform completed")

func _on_teleport_cooldown_timeout() -> void:
	can_teleport = true
	print("MAGUS KING: Teleport cooldown ready")

# =====================================================
# UTILITY FUNCTIONS
# =====================================================
func _on_same_platform() -> bool:
	if not current_platform or not player:
		return false
	
	var boss_y = global_position.y
	var player_y = player.global_position.y
	var y_diff = abs(player_y - boss_y)
	var is_same = y_diff < 100
	
	if debug_frame_count % 180 == 0:
		print("MAGUS KING: _on_same_platform")
		print("  Boss Y: ", boss_y, ", Player Y: ", player_y, ", Diff: ", y_diff)
		print("  Same platform (diff < 100)? ", is_same)
	
	return is_same

func _chase_player() -> void:
	if not player:
		return
	
	var dx := player.global_position.x - global_position.x
	var dist = abs(dx)
	
	if dist > melee_range:
		var chase_dir = sign(dx) if dx != 0 else dir.x
		dir.x = chase_dir
		
		if chase_dir != 0:
			sprite.flip_h = chase_dir < 0
		
		velocity.x = dir.x * move_speed
		
		if debug_frame_count % 120 == 0:
			print("MAGUS KING: Chasing - dir.x=", dir.x, ", velocity.x=", velocity.x)
		
		if anim.has_animation("walk"):
			anim.play("walk")
		elif anim.has_animation("run"):
			anim.play("run")
	else:
		velocity.x = 0
		if debug_frame_count % 120 == 0:
			print("MAGUS KING: In melee range, stopping")
		if anim.has_animation("idle"):
			anim.play("idle")

# =====================================================
# DAMAGE HANDLING
# =====================================================
func _on_hurtbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("player_attack") or area == Global.playerDamageZone:
		var damage = Global.playerDamageAmount
		print("MAGUS KING: Player attack detected, damage=", damage)
		take_damage(damage)

func _on_hurtbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("player_attack"):
		var damage = Global.playerDamageAmount
		print("MAGUS KING: Player body attack detected, damage=", damage)
		take_damage(damage)

# =====================================================
# DEATH
# =====================================================
func _die() -> void:
	dead = true
	ai_active = false
	velocity = Vector2.ZERO
	
	print("MAGUS KING: Died!")
	
	if attack_decision_timer:
		attack_decision_timer.stop()
	
	# Stop any active attacks
	_stop_laser()
	if melee_hitbox:
		melee_hitbox.monitoring = false
	
	if anim.has_animation("die"):
		anim.play("die")
		await anim.animation_finished
	
	emit_signal("boss_died")
	queue_free()

# =====================================================
# CLEANUP
# =====================================================
func _exit_tree() -> void:
	print("MAGUS KING: _exit_tree called")
	ai_active = false
	if attack_decision_timer:
		attack_decision_timer.stop()

func _on_melee_attack_frame() -> void:
	print("MAGUS KING: Melee attack frame triggered")  # CHANGED from "Sterling:"
	
	if not player or not is_instance_valid(player):
		print("MAGUS KING: No valid player for melee attack")  # CHANGED from "Sterling:"
		return
	
	# Check if player is in range
	if _in_melee_range():
		print("MAGUS KING: Player in range, dealing melee damage")  # CHANGED from "Sterling:"
		#emit_signal("melee_attack_triggered", melee_damage)
		
		# Also apply damage directly (backup)
		if player.has_method("take_damage"):
			player.take_damage(melee_damage)
			print("MAGUS KING: Direct damage applied: ", melee_damage)  # CHANGED from "Sterling:"
	else:
		print("MAGUS KING: Player not in range for melee")  # CHANGED from "Sterling:"

func _in_melee_range() -> bool:
	if not player or not is_instance_valid(player):
		return false
	
	var dist = global_position.distance_to(player.global_position)
	var in_range = dist <= melee_range
	
	# Debug info
	if debug_frame_count % 60 == 0 and in_range:
		print("MAGUS KING: _in_melee_range check - dist:", dist, " melee_range:", melee_range, " result:", in_range)
	
	return in_range
	
func _on_laser_start_frame() -> void:
	print("MAGUS KING: Laser start frame triggered from animation")
	#_start_laser()

func _on_laser_end_frame() -> void:
	print("MAGUS KING: Laser end frame triggered from animation")
	#_stop_laser()

func _start_laser() -> void:
	print("MAGUS KING: Starting laser visuals and damage")
	
	if laser_active:  # Don't start if already active
		return
	
	laser_active = true
	
	# Show laser beam sprite
	if laser_beam:
		laser_beam.visible = true
		# Adjust laser direction based on sprite flip
		if sprite.flip_h:
			laser_beam.scale.x = -abs(laser_beam.scale.x)
		else:
			laser_beam.scale.x = abs(laser_beam.scale.x)
		print("MAGUS KING: Laser beam visible: ", laser_beam.visible)
	
	# Enable collisions
	if laser_collision:
		laser_collision.disabled = false
		print("MAGUS KING: Laser collision enabled")
	
	# Legacy laser area support
	if laser_area:
		laser_area.monitoring = true
		if laser_area.has_node("CollisionShape2D"):
			laser_area.get_node("CollisionShape2D").disabled = false
		print("MAGUS KING: Laser area monitoring enabled")
		
func _on_laser_duration_timeout() -> void:
	print("MAGUS KING: Laser duration ended")
	_stop_laser()

