extends Area2D
class_name PuzzleButton

@export var door_target: NodePath
@export var stay_pressed: bool = true              # If true, object can leave and it stays pressed
@export var allow_player: bool = true
@export var allow_telekinesis_object: bool = true  # TelekinesisObject can press it

@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer if has_node("AnimationPlayer") else null

var is_pressed: bool = false
var bodies_on_button: Array = []


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if not _is_valid_press_body(body):
		return
	
	bodies_on_button.append(body)
	_update_button_state()


func _on_body_exited(body: Node2D) -> void:
	if not _is_valid_press_body(body):
		return
	
	bodies_on_button.erase(body)
	if not stay_pressed:
		_update_button_state()


func _is_valid_press_body(body: Node2D) -> bool:
	if allow_player and body is Player:
		return true
	# Adjust the class name if your telekinesis object script is different
	if allow_telekinesis_object and body is TelekinesisObject:
		return true
	return false


func _update_button_state() -> void:
	var should_be_pressed: bool = bodies_on_button.size() > 0 or (stay_pressed and is_pressed)
	
	if should_be_pressed and not is_pressed:
		_press_button()
	elif not should_be_pressed and is_pressed:
		_release_button()


func _press_button() -> void:
	is_pressed = true
	
	if animation_player:
		animation_player.play("press")
	else:
		modulate = Color(0.7, 0.7, 0.7)
	
	var door: PuzzleDoor = get_node_or_null(door_target)
	if door:
		door.register_button_pressed()
	
	print("PuzzleButton: pressed")


func _release_button() -> void:
	is_pressed = false
	
	if animation_player:
		animation_player.play("release")
	else:
		modulate = Color(1, 1, 1)
	
	var door: PuzzleDoor = get_node_or_null(door_target)
	if door:
		door.register_button_released()
	
	print("PuzzleButton: released")
