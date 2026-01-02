extends CharacterBody2D
class_name SimpleMovingPlatform

@export var move_speed: float = 200.0 
@export var wait_time: float = 0.5
@export var auto_start: bool = true
@export var ping_pong: bool = true
@export var is_dangerous: bool = false
@export var damage_percentage: float = 5.0  # Only used if is_dangerous is true

# Use LOCAL positions (relative to platform)
@onready var start_pos: Vector2 = $StartMarker.position
@onready var end_pos: Vector2 = $EndMarker.position
@onready var damage_area: Area2D = $DamageArea if has_node("DamageArea") else null

var current_target: Vector2
var is_moving: bool = false
var wait_timer: float = 0.0
var original_position: Vector2
var riders: Array = []  # Store players on platform
var movement_velocity: Vector2 = Vector2.ZERO  # Track movement separately

func _ready():
	print("=== PLATFORM DEBUG ===")
	print("Original platform position: ", global_position)
	print("Start marker LOCAL position: ", start_pos)
	print("End marker LOCAL position: ", end_pos)
	print("Start world position will be: ", global_position + start_pos)
	print("End world position will be: ", global_position + end_pos)
	print("Is dangerous: ", is_dangerous)
	print("=====================")
	
	# Store original position
	original_position = global_position
	
	# Set current target (relative to our position)
	current_target = end_pos
	
	# Setup damage area if dangerous
	if is_dangerous and damage_area:
		damage_area.body_entered.connect(_on_damage_area_body_entered)
		print("Damage area enabled")
	
	if auto_start:
		is_moving = true

func _physics_process(delta):
	# Store previous position for moving riders
	var previous_position = global_position
	
	if not is_moving:
		# Handle waiting
		if wait_timer > 0:
			wait_timer -= delta
			if wait_timer <= 0:
				is_moving = true
				# Switch target after waiting
				if current_target == end_pos:
					current_target = start_pos if ping_pong else end_pos
				else:
					current_target = end_pos
		
		# Clear velocity when not moving
		movement_velocity = Vector2.ZERO
		_update_riders(Vector2.ZERO)
		return
	
	# Calculate world target position
	var world_target = original_position + current_target
	
	# Calculate movement direction and distance
	var direction = (world_target - global_position).normalized()
	var distance = global_position.distance_to(world_target)
	var move_amount = move_speed * delta * Global.global_time_scale
	
	if move_amount >= distance:
		# Reached target
		global_position = world_target
		movement_velocity = Vector2.ZERO
		
		# Start waiting
		is_moving = false
		wait_timer = wait_time
		
		#print("Platform reached target at: ", global_position)
	else:
		# Calculate movement for this frame
		movement_velocity = direction * move_speed * Global.global_time_scale
		
		# Apply movement WITHOUT move_and_slide
		global_position += movement_velocity * delta
	
	# Move riders with the platform
	var platform_movement = global_position - previous_position
	if platform_movement != Vector2.ZERO:
		_update_riders(platform_movement)

func _update_riders(platform_movement: Vector2):
	# Move riders and clean up invalid ones
	for i in range(riders.size() - 1, -1, -1):
		var rider = riders[i]
		if is_instance_valid(rider):
			# Apply platform movement to rider
			rider.global_position += platform_movement
		else:
			riders.remove_at(i)

func _on_body_entered(body: Node2D):
	# When a player lands on the platform
	if body is CharacterBody2D and body.is_in_group("player"):
		if not riders.has(body):
			riders.append(body)
			print("Player boarded platform")
			# Apply current movement to rider immediately
			if movement_velocity != Vector2.ZERO:
				body.global_position += movement_velocity * get_physics_process_delta_time()

func _on_body_exited(body: Node2D):
	# When a player leaves the platform
	if body is CharacterBody2D and body.is_in_group("player"):
		if riders.has(body):
			riders.erase(body)
			print("Player left platform")

func _on_damage_area_body_entered(body: Node2D):
	# Damage player if platform is dangerous
	if not is_dangerous:
		return
	
	if body is Player and body.can_take_damage and not body.dead:
		print("MovingPlatform: Player hit!")
		
		# % HP damage
		var platform_damage_float := (damage_percentage / 100.0) * Global.health_max
		var platform_damage := int(max(1.0, platform_damage_float))
		
		# Give a knockback direction away from the platform
		var knock_dir = (body.global_position - global_position).normalized()
		if knock_dir == Vector2.ZERO:
			knock_dir = Vector2.UP
		Global.enemyAknockback = knock_dir * 200.0  # tweak force
		
		body.take_damage(platform_damage)

# Control functions
func start_moving():
	is_moving = true
	print("Platform started moving")

func stop_moving():
	is_moving = false
	movement_velocity = Vector2.ZERO
	print("Platform stopped")

func reset_to_start():
	global_position = original_position
	current_target = end_pos
	is_moving = false if wait_time > 0 else true
	riders.clear()
	print("Platform reset to start")

# Toggle dangerous state
func set_dangerous(dangerous: bool):
	is_dangerous = dangerous
	print("Platform dangerous state set to: ", dangerous)
