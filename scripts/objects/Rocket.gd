extends Area2D
class_name Rocket

@export var speed = 150.0 * Global.global_time_scale             # How fast the rocket travels
@export var rotation_speed = 50.0   # How quickly the rocket turns towards its target
@export var damage = 30            # How much damage the rocket deals
@export var lifetime = 2.0         # How long the rocket exists before despawning (seconds)
@export var initial_move_duration = 0.3 # Duration (seconds) for initial broad movement before full homing

var target: Node2D = null          # The enemy the rocket is trying to hit
var initial_direction_vector = Vector2.ZERO # The broad direction given at spawn
var is_homing_active = false       # Flag to control homing behavior
@onready var animation_player: AnimationPlayer = $AnimationPlayer

func _ready():
	print("ROCKET READY layer=", collision_layer, " mask=", collision_mask, " monitoring=", monitoring)

	monitoring = true
	monitorable = true

	# ✅ IMPORTANT: weakspots are Area2D, so we need both
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

	$Timer.wait_time = lifetime
	$Timer.one_shot = true
	$Timer.start()
	$Timer.timeout.connect(_on_lifetime_timeout)

	# Start a separate timer for the initial movement phase
	var initial_move_timer = Timer.new()
	add_child(initial_move_timer)
	initial_move_timer.wait_time = initial_move_duration
	initial_move_timer.one_shot = true
	initial_move_timer.timeout.connect(func(): is_homing_active = true) # Activate homing after duration
	initial_move_timer.start()

	# Immediately set the rocket's rotation to its initial_direction_vector
	#if initial_direction_vector != Vector2.ZERO:
	#	rotation = initial_direction_vector.angle()

	# Optional: Initial target search on ready if not already set by player
	if not is_instance_valid(target):
		target = find_closest_enemy()

func _physics_process(delta):
	# Find target only if needed
	animation_player.play("shooting")
	if not is_instance_valid(target):
		target = find_closest_weakspot()
		if not is_instance_valid(target):
			target = find_closest_enemy() # fallback

	var current_target_angle: float 

	if target and is_homing_active:
		# If homing is active and there's a target, aim towards the target
		var aim_point = target.global_position + Vector2(0, -10) 
		var direction_to_target = (aim_point - global_position).normalized()
		current_target_angle = direction_to_target.angle()
	else: # Homing is not active OR no target found
		# During the initial phase, or if no target ever appears, aim towards the initial_direction_vector
		if initial_direction_vector != Vector2.ZERO:
			current_target_angle = initial_direction_vector.angle()
		else:
			# Fallback: if no initial direction and no target, just keep current rotation
			current_target_angle = rotation

	# Smoothly rotate the rocket towards the determined target angle
	# This ensures the rocket's orientation (and thus its transform.x)
	# always aligns with its current intended direction.
	rotation = lerp_angle(rotation, current_target_angle, delta * rotation_speed)

	# Move the rocket forward in its current rotated direction
	# transform.x is a vector that points in the local X-axis direction of the node,
	# and its direction changes with the node's rotation.
	global_position += transform.x * speed * delta


func find_closest_enemy() -> Node2D:
	var closest: Node2D = null
	var best := INF

	for e in get_tree().get_nodes_in_group("Enemies"):
		if not is_instance_valid(e):
			continue

		# ✅ Never target self
		if e == self:
			continue

		# ✅ Ignore player and anything related to player attack / projectiles
		if e is Player:
			continue
		if e.is_in_group("player_attack"):
			continue
		if e.is_in_group("Projectiles"):
			continue

		# ✅ If this is a weakspot Area2D, only target it when it's enabled
		if e is Area2D:
			var cs := (e as Area2D).get_node_or_null("CollisionShape2D") as CollisionShape2D
			if cs and cs.disabled:
				continue

		# ✅ If you want rockets to ONLY damage Gawr via weakspots, don't target boss body
		#if e is GawrBoss:
		#	continue

		var p := (e as Node2D).global_position
		var d := global_position.distance_squared_to(p)
		if d < best:
			best = d
			closest = e as Node2D

	return closest


func set_initial_properties(initial_dir: Vector2, target_node: Node2D = null):
	initial_direction_vector = initial_dir.normalized()
	if target_node:
		target = target_node
	# Immediately set the rotation to the initial direction upon creation, for visual consistency.
	# This line ensures the rocket points the right way from the very first frame.

	rotation = initial_direction_vector.angle()


func _on_body_entered(body: Node2D):
	if body is Player:
		return # Do nothing if the rocket collides with the player
	#if body is GawrBoss:
	#	print("Rocket hit boss BODY -> ignoring (weakspots only)")
	#	return  
		
	if body.has_method("take_damage"):
		body.take_damage(damage)
		print("Rocket hit enemy and dealt ", damage, " damage.")
	elif body.is_in_group("Platforms"):
		print("Rocket hit a platform.")
	else:
		print("Rocket hit something else: ", body.name)

	queue_free()

func _on_area_entered(a: Area2D) -> void:
	if a == null:
		return
	if a.has_method("take_damage"):
		a.take_damage(damage)
		queue_free()
	print("ROCKET HIT AREA:", a.name, " groups=", a.get_groups())

	#if a.is_in_group("EnemyWeakspot"):
	#	var boss := a
	#	while boss and not boss.has_method("take_damage"):
	#		boss = boss.get_parent()

	#	if boss and boss.has_method("take_damage"):
	#		boss.take_damage(damage)
	#		queue_free()

func _find_damage_receiver(n: Node) -> Node:
	var cur: Node = n
	while cur:
		if cur.has_method("take_damage"):
			return cur
		cur = cur.get_parent()
	return null
	
func _on_lifetime_timeout():
	print("Rocket lifetime expired.")
	queue_free()

func find_closest_weakspot() -> Node2D:
	var closest: Node2D = null
	var best := INF

	for ws in get_tree().get_nodes_in_group("EnemyWeakspot"):
		if not is_instance_valid(ws):
			continue
		if ws is Area2D:
			var cs := (ws as Area2D).get_node_or_null("CollisionShape2D") as CollisionShape2D
			if cs and cs.disabled:
				continue

		var d := global_position.distance_squared_to((ws as Node2D).global_position)
		if d < best:
			best = d
			closest = ws as Node2D

	return closest
