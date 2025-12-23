extends StaticBody2D
class_name PuzzleDoor

@export var move_distance: float = 64.0     # How far to move up
@export var move_speed: float = 100.0       # Pixels per second
@export var required_buttons: int = 2       # How many buttons must be pressed
@export var auto_close_if_buttons_released: bool = false


@onready var start_position: Vector2 = position
@onready var target_position: Vector2 = position + Vector2(0, -move_distance)
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var is_moving: bool = false
var is_open: bool = false
var permanently_open: bool = false
var pressed_buttons: int = 0


func _ready() -> void:
	# If a global flag is set, door starts opened forever
	if Global.final_puzzle_door:
		permanently_open = true
		open_door_instantly()
	else:
		close_door_instantly()


func _process(delta: float) -> void:
	if is_moving:
		_move_door(delta)
	if $AnimationPlayer:
		$AnimationPlayer.speed_scale = Global.global_time_scale

# Called by buttons when they become pressed (first time)
func register_button_pressed() -> void:
	if permanently_open:
		return
	
	pressed_buttons += 1
	pressed_buttons = max(pressed_buttons, 0)
	
	if pressed_buttons >= required_buttons and not is_open:
		open_door()


# Called by buttons when they are released (if not stay_pressed)
func register_button_released() -> void:
	if permanently_open:
		return
	
	pressed_buttons -= 1
	pressed_buttons = max(pressed_buttons, 0)
	
	if auto_close_if_buttons_released and pressed_buttons < required_buttons and is_open:
		close_door()


func open_door() -> void:
	if is_open or is_moving:
		return
	
	print("PuzzleDoor: opening")
	is_open = true
	is_moving = true


func close_door() -> void:
	if not is_open or is_moving:
		return
	
	# If door should never close once opened and flagged → ignore
	if permanently_open:
		return
	
	print("PuzzleDoor: closing")
	is_open = false
	is_moving = true


func open_door_instantly() -> void:
	is_open = true
	is_moving = false
	position = target_position
	collision_shape.set_deferred("disabled", true)
	print("PuzzleDoor: opened instantly")


func close_door_instantly() -> void:
	is_open = false
	is_moving = false
	position = start_position
	collision_shape.set_deferred("disabled", false)
	print("PuzzleDoor: closed instantly")


func _move_door(delta: float) -> void:
	var target_pos: Vector2 = target_position if is_open else start_position
	var to_target: Vector2 = target_pos - position
	var distance: float = to_target.length()
	
	if distance > 1.0:
		var dir: Vector2 = to_target.normalized()
		position += dir * move_speed * delta
	else:
		position = target_pos
		is_moving = false
		
		if is_open:
			collision_shape.set_deferred("disabled", true)

			# Set persistent flag
			Global.final_puzzle_door = true
			permanently_open = true
		else:
			collision_shape.set_deferred("disabled", false)
		
		print("PuzzleDoor: fully ", "open" if is_open else "closed")
