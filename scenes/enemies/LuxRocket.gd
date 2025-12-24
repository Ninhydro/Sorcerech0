extends Area2D
class_name LuxRocket

@export var speed := 160.0
@export var turn_rate := 2.5
@export var damage := 20
@export var lifetime := 3.5

var target: Node2D
var dir := Vector2.RIGHT

func set_target(t: Node2D):
	target = t
	# Calculate initial direction based on target position
	if target and is_instance_valid(target):
		var to_target = target.global_position - global_position
		dir = to_target.normalized()
		rotation = dir.angle()

func set_initial_direction(v: Vector2):
	dir = v.normalized()
	rotation = dir.angle()

func _ready():
	# IMPORTANT: Connect the signal so the rocket detects collisions
	body_entered.connect(_on_body_entered)

	# Start lifetime timer
	if has_node("Timer"):
		$Timer.wait_time = lifetime
		$Timer.one_shot = true
		$Timer.start()
		$Timer.timeout.connect(queue_free)
	else:
		# Fallback if no Timer node exists
		get_tree().create_timer(lifetime).timeout.connect(queue_free)

func _physics_process(delta):
	# Using your Global time scale logic
	var t = delta * Global.global_time_scale

	if target and is_instance_valid(target):
		var desired = (target.global_position - global_position).normalized()
		# Smoothly rotate towards target
		dir = dir.lerp(desired, turn_rate * t).normalized()
		rotation = dir.angle()

	global_position += dir * speed * t

func _on_body_entered(body: Node2D):
	# Debug print to confirm collision is happening
	print("LuxRocket collided with: ", body.name)

	if body is Player and body.can_take_damage and not body.get("dead"):
		body.take_damage(damage)
		explode()
	elif body is TileMap:
		explode()

func explode():
	# You can add explosion particles or sounds here
	queue_free()
