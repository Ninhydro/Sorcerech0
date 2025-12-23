extends StaticBody2D
class_name PuzzleDoor2

@export var required_station: int = 1
@export var move_distance: float = 64.0  # How far to move up
@export var move_speed: float = 100.0    # Pixels per second

@onready var start_position: Vector2 = position
@onready var target_position: Vector2 = position + Vector2(0, -move_distance)
@onready var sprite = $Door
@onready var collision_shape = $CollisionShape2D

var is_moving: bool = false
var is_open: bool = false
var has_checked_initial_state: bool = false

func _ready():
	check_initial_state()
	
	# Set up periodic checking
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = 0.5
	timer.timeout.connect(update_door_state)
	timer.start()

func _process(delta):
	if is_moving:
		move_door(delta)

	if $AnimationPlayer:
		$AnimationPlayer.speed_scale = Global.global_time_scale

func check_initial_state():
	"""Check the door state immediately when the scene loads"""
	if has_checked_initial_state:
		return
	
	var station_completed = false
	
	match required_station:
		1: station_completed = Global.nora_station_1_completed
		2: station_completed = Global.nora_station_2_completed
		3: station_completed = Global.nora_station_3_completed
	
	if station_completed:
		# Station already completed - open door instantly
		open_door_instantly()
	else:
		# Station not completed - ensure door is closed
		close_door_instantly()
	
	has_checked_initial_state = true
	print("Door initial state checked: ", "OPEN" if station_completed else "CLOSED")
	
func update_door_state():
	var station_completed = false
	
	match required_station:
		1: station_completed = Global.nora_station_1_completed
		2: station_completed = Global.nora_station_2_completed
		3: station_completed = Global.nora_station_3_completed
	
	# Open door if station completed and not already open/moving
	if station_completed and not is_open and not is_moving:
		open_door()

	elif not station_completed and is_open and not is_moving:
		close_door()

func open_door_instantly():
	"""Open the door immediately without animation"""
	is_open = true
	position = target_position
	sprite.visible = false
	collision_shape.set_deferred("disabled", true)
	print("Door opened instantly (from saved state)")

func close_door_instantly():
	"""Close the door immediately without animation"""
	is_open = false
	position = start_position
	sprite.visible = true
	collision_shape.set_deferred("disabled", false)
	print("Door closed instantly")
	
func open_door():
	print("Door opening!")
	is_moving = true
	is_open = true

func close_door():
	print("Door closing!")
	is_moving = true
	is_open = false

func move_door(delta):
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
		print("Door fully ", "open" if is_open else "closed")
		
		# Disable collision when fully open
		if is_open:
			set_collision_layer_value(1, false)  # Disable layer 1 (player collision)
			set_collision_mask_value(1, false)   # Disable mask 1
