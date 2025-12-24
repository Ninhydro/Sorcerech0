extends CharacterBody2D
class_name FallingPlatform

@export var gravity: float = 1000.0
@export var max_fall_speed: float = 50.0
@export var spike_damage: int = 15
@export var lifetime: float = 15.0
@export var knockback_force: float = 300.0
@export var horizontal_speed: float = 0.0
@export var horizontal_range: float = 0.0
@export var start_active: bool = false  # NEW: Start falling immediately for testing

@onready var platform_collision: CollisionShape2D = $PlatformCollision
@onready var spike_hitbox: Area2D = $SpikeHitbox
@onready var platform_sprite: Sprite2D = $Sprite2D

var life_left: float = 0.0
var is_active: bool = false
var start_x: float = 0.0
var time_alive: float = 0.0
var initial_position: Vector2

# -------------------------------------------------
# READY
# -------------------------------------------------
func _ready() -> void:
	if spike_hitbox:
		spike_hitbox.body_entered.connect(_on_spike_hitbox_body_entered)
	
	# Store initial position
	initial_position = global_position
	start_x = global_position.x
	
	# Set up collision layers immediately
	_setup_collision_layers()
	
	# Start active if configured
	if start_active:
		activate_at(global_position)
	else:
		_deactivate()

# -------------------------------------------------
# PHYSICS PROCESS - FIXED
# -------------------------------------------------
func _physics_process(delta: float) -> void:
	if not is_active:
		return
	
	var ts: float = max(0.0, float(Global.global_time_scale))
	var scaled_delta: float = delta * ts
	
	time_alive += scaled_delta
	
	# Apply gravity - FIXED: Add gravity, don't set to min
	velocity.y += gravity * scaled_delta
	velocity.y = min(velocity.y, max_fall_speed)
	
	# Earthquake side-to-side movement - SIMPLIFIED
	if horizontal_speed > 0:
		# Simple sine wave movement
		velocity.x = sin(time_alive * 2.0) * horizontal_speed
	
	# Move
	var was_on_floor = is_on_floor()
	move_and_slide()
	
	# DEBUG: Print position and velocity
	if Engine.get_process_frames() % 60 == 0:  # Every second
		print("FallingPlatform: Pos=", global_position, " Vel=", velocity, " Active=", is_active)
	
	# Check if hit floor
	if is_on_floor() and not was_on_floor:
		print("FallingPlatform: Hit floor at ", global_position)
		_deactivate()
		return
	
	# Lifetime timeout
	life_left -= scaled_delta
	if life_left <= 0.0:
		print("FallingPlatform: Lifetime expired")
		_deactivate()

# -------------------------------------------------
# ACTIVATION/DEACTIVATION - FIXED
# -------------------------------------------------
func activate_at(world_position: Vector2) -> void:
	print("FallingPlatform.activate_at called with: ", world_position)
	print("=== FallingPlatform.activate_at ===")
	print("Position: ", world_position)
	print("Platform scene: ", get_scene_file_path())
	print("Is inside tree: ", is_inside_tree())
	
	global_position = world_position
	initial_position = world_position
	velocity = Vector2.ZERO
	life_left = lifetime
	time_alive = 0.0
	start_x = world_position.x
	is_active = true
	
	show()
	
	# Enable collisions IMMEDIATELY (not deferred for testing)
	if platform_collision:
		platform_collision.disabled = false
	if spike_hitbox:
		spike_hitbox.monitoring = true

	
	# Enable physics
	set_physics_process(true)
	
	print("Platform should now be visible at: ", global_position)
	print("=== activate_at FINISHED ===")
	print("FallingPlatform: Activated! Position: ", global_position, " Lifetime: ", lifetime)

func _deactivate() -> void:
	print("FallingPlatform._deactivate called")
	
	is_active = false
	velocity = Vector2.ZERO
	
	# For testing, just hide instead of disabling
	hide()
	
	# Disable collisions
	if platform_collision:
		platform_collision.disabled = true
	if spike_hitbox:
		spike_hitbox.monitoring = false
	
	print("FallingPlatform: Deactivated")

# -------------------------------------------------
# COLLISION LAYER SETUP - FIXED
# -------------------------------------------------
func _setup_collision_layers():
	print("FallingPlatform._setup_collision_layers")
	
	# Platform body: Layer 1 (platform top)
	collision_layer = 1  # Layer 1 - platform top
	collision_mask = 0   # Don't collide with anything by default
	
	# Spike hitbox: Layer 2 (damages player)
	if spike_hitbox:
		spike_hitbox.collision_layer = 2  # Layer 2 - spike damage
		spike_hitbox.collision_mask = 1   # Only interact with layer 1 (player)
		print("Spike hitbox layers: layer=", spike_hitbox.collision_layer, " mask=", spike_hitbox.collision_mask)

# -------------------------------------------------
# DAMAGE HANDLING
# -------------------------------------------------
func _on_spike_hitbox_body_entered(body: Node2D) -> void:
	print("FallingPlatform: Spike hitbox entered by: ", body.name)
	
	if not is_active:
		print("  -> Platform not active, ignoring")
		return
	
	#if body is Player and not body.dead:
	#	print("FallingPlatform: Spike hit player!")
	#	
	#	# Calculate knockback direction
	#	var dir: Vector2 = (body.global_position - global_position).normalized()
	#	if dir == Vector2.ZERO:
	#		dir = Vector2.DOWN
		
	#	Global.enemyAknockback = dir * knockback_force
	#	body.take_damage(spike_damage)

# -------------------------------------------------
# TEST FUNCTION (Call from Inspector or another script)
# -------------------------------------------------
func test_fall() -> void:
	print("=== TEST FALLING PLATFORM ===")
	print("Current position: ", global_position)
	print("Is active: ", is_active)
	print("Velocity: ", velocity)
	
	if not is_active:
		activate_at(global_position + Vector2(0, -100))  # Start 100 pixels above current position
	else:
		print("Already active!")
