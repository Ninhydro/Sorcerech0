extends Area2D

var player_in_range = null
@export var player_path: NodePath
@onready var sprite_2d = $Sprite2D

func _ready() -> void:
	connect("body_entered", Callable(self, "_on_body_entered"))
	connect("body_exited", Callable(self, "_on_body_exited"))

func _on_body_entered(body):
	if body.name == "Player":
		player_in_range = body

func _on_body_exited(body):
	if body == player_in_range:
		player_in_range = null

func _process(delta):
	if player_in_range:
		if Input.is_action_just_pressed("no"):
			print("enter canon1")
			player_in_range.canon_enabled = true
			player_in_range.enter_cannon(self)  # Pass reference to this cannon
	
	# Handle cannon rotation when player is in cannon mode
	#if player_in_range and player_in_range.canon_enabled and player_in_range.is_in_cannon:
	#	handle_cannon_rotation()

func handle_cannon_rotation():
	var input_dir = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	
	if input_dir != 0:
		# Rotate the cannon based on input
		# You can adjust the rotation speed as needed
		var rotation_speed = 2.0  # Degrees per frame
		sprite_2d.rotation_degrees += input_dir * rotation_speed
		
		# Clamp rotation if needed (optional)
		# sprite_2d.rotation_degrees = clamp(sprite_2d.rotation_degrees, -90, 90)
