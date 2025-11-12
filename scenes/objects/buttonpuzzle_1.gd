extends Area2D
class_name Button1

@export var door_target: NodePath  # Path to the door this button controls
@export var required_color: ColorObject.ColorType = ColorObject.ColorType.RED
@export var stay_pressed: bool = true  # If false, button resets when object leaves

@onready var sprite = $Sprite2D
@onready var animation_player = $AnimationPlayer if has_node("AnimationPlayer") else null

var is_pressed: bool = false
var objects_on_button: Array = []

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body is ColorObject:
		objects_on_button.append(body)
		check_button_state()

func _on_body_exited(body):
	if body is ColorObject:
		objects_on_button.erase(body)
		if not stay_pressed:
			check_button_state()

func check_button_state():
	var should_be_pressed = false
	
	for obj in objects_on_button:
		#if obj.get_color_type() == required_color:
			should_be_pressed = true
			break
	
	if should_be_pressed and not is_pressed:
		press_button()
	elif not should_be_pressed and is_pressed:
		release_button()

func press_button():
	is_pressed = true
	
	# Visual feedback
	if animation_player:
		animation_player.play("press")
	else:
		# Simple visual change
		modulate = Color(0.7, 0.7, 0.7)  # Darken slightly
	
	# Trigger door opening
	var door = get_node_or_null(door_target)
	if door and door.has_method("open_door"):
		door.open_door()
	
	print("Button pressed with correct color: ", ColorObject.ColorType.keys()[required_color])

func release_button():
	is_pressed = false
	
	# Visual feedback
	if animation_player:
		animation_player.play("release")
	else:
		modulate = Color(1, 1, 1)  # Back to normal
	
	# Trigger door closing
	var door = get_node_or_null(door_target)
	if door and door.has_method("close_door"):
		door.close_door()
	
	print("Button released")
