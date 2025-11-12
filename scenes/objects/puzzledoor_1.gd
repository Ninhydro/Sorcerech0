extends StaticBody2D
class_name ColorDoor

@export var move_distance: float = 64.0  # How far to move up
@export var move_speed: float = 100.0    # Pixels per second
@export var auto_close: bool = false     # If true, closes when button is released

@onready var start_position: Vector2 = position
@onready var target_position: Vector2 = position + Vector2(0, -move_distance)
@onready var sprite = $Door
@onready var collision_shape = $CollisionShape2D

var is_moving: bool = false
var is_open: bool = false

func _ready():
	# Initial state - closed
	close_door_instantly()

func _process(delta):
	if is_moving:
		move_door(delta)

func open_door():
	"""Called by button to open the door"""
	if is_open or is_moving:
		return
	
	print("Door opening!")
	is_moving = true
	is_open = true

func close_door():
	"""Called by button to close the door"""
	if not is_open or is_moving or not auto_close:
		return
	
	print("Door closing!")
	is_moving = true
	is_open = false

func open_door_instantly():
	"""Open immediately without animation"""
	is_open = true
	position = target_position
	collision_shape.set_deferred("disabled", true)
	print("Door opened instantly")

func close_door_instantly():
	"""Close immediately without animation"""
	is_open = false
	position = start_position
	collision_shape.set_deferred("disabled", false)
	print("Door closed instantly")

func move_door(delta):
	"""Handle door movement animation"""
	var target_pos = target_position if is_open else start_position
	var direction = (target_pos - position).normalized()
	var distance = position.distance_to(target_pos)
	
	if distance > 2.0:
		# Move towards target
		position += direction * move_speed * delta
	else:
		# Reached target
		position = target_pos
		is_moving = false
		
		# Update collision based on final state
		if is_open:
			collision_shape.set_deferred("disabled", true)
		else:
			collision_shape.set_deferred("disabled", false)
		
		print("Door fully ", "open" if is_open else "closed")
