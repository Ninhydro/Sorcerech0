extends RigidBody2D  # Changed from Area2D to RigidBody2D

@export var health_amount := 20
@export var bounce_force := 100.0
@export var float_height := 10.0
@export var float_speed := 3.0

var initial_y: float
var time := 0.0
var has_settled := false

func _ready():
	# RigidBody2D settings
	gravity_scale = 1.0  # Enable gravity
	linear_damp = 0.5    # Air resistance
	can_sleep = true     # Allow to sleep when settled
	
	# Apply upward force to bounce out of ground
	apply_central_impulse(Vector2(randf_range(-50, 50), -bounce_force))
	
	# Connect collection signal
	$CollectionArea.body_entered.connect(_on_body_entered)
	
	# Store initial Y for floating animation
	initial_y = global_position.y

func _process(delta):
	# Only start floating after the RigidBody has settled
	if has_settled:
		time += delta
		global_position.y = initial_y + sin(time * float_speed) * float_height

func _integrate_forces(state):
	# Check if the RigidBody has settled (stopped moving)
	if state.linear_velocity.length() < 5.0 and not has_settled:
		has_settled = true
		initial_y = global_position.y  # Update initial_y to settled position
		start_floating_animation()

func start_floating_animation():
	# Optional: Add a gentle floating animation
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(self, "position:y", position.y - 5, 0.5)
	tween.tween_property(self, "position:y", position.y, 0.5)

func _on_body_entered(body):
	if body.is_in_group("player") and body.has_method("heal"):
		body.heal(health_amount)
		play_collection_effect()
		queue_free()

func play_collection_effect():
	print("Player collected health! +", health_amount, " HP")
