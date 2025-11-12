extends TelekinesisObject  # Change this line!
class_name ColorObject


enum ColorType {
	RED, BLUE, YELLOW, 
	GREEN, PURPLE, ORANGE, 
	CYAN, MAGENTA, BROWN, 
	WHITE, BLACK, GOLD
}

@export var color_type: ColorType = ColorType.RED
@export var original_position: Vector2
@onready var collision_shape = $CollisionShape2D

var is_in_mixer: bool = false
var is_available_for_mixing: bool = true

var color_values = {
	ColorType.RED: Color.RED,
	ColorType.BLUE: Color.BLUE,
	ColorType.YELLOW: Color.YELLOW,
	ColorType.GREEN: Color.GREEN,
	ColorType.PURPLE: Color(0.5, 0, 0.5),
	ColorType.ORANGE: Color(1, 0.5, 0),
	ColorType.CYAN: Color(0, 1, 1),
	ColorType.MAGENTA: Color(1, 0, 1),
	ColorType.BROWN: Color(0.6, 0.3, 0),
	ColorType.WHITE: Color.WHITE,
	ColorType.BLACK: Color.BLACK,
	ColorType.GOLD: Color.GOLD
}
#@onready var outline_material = preload("res://shaders/OutlineMaterial.tres")


func _ready():
	add_to_group("TelekinesisObject")
	
	if original_position == Vector2.ZERO:
		original_position = global_position
	update_appearance()


	if has_node("Sprite2D"):
		sprite = $Sprite2D
		if sprite.material != null:
			sprite.material.set_shader(null)
			sprite.material = null
		print("Sprite2D found for object: ", name)

	else:
		print("ERROR: No Sprite2D node found for object: ", name)
	
func _process(delta):
	if global_position.y > 2000:
		reset_to_original()

func start_levitation(player_pos: Vector2):
	is_controlled = true
	offset = position - player_pos

func update_levitation(player_pos: Vector2):
	if Input.is_action_pressed("move_right"):
		linear_velocity.x += 1
	if Input.is_action_pressed("move_left"):
		linear_velocity.x -= 1
	if Input.is_action_pressed("move_up"):
		linear_velocity.y -= 1
	if Input.is_action_pressed("move_down"):
		linear_velocity.y += 1

func stop_levitation():
	is_controlled = false

func update_appearance():
	if sprite:
		if color_type == ColorType.GOLD:
			var gold_texture = preload("res://assets_image/Objects/collect_objects6.png")
			sprite.texture = gold_texture
			sprite.modulate = Color.WHITE  # Use texture's original colors
		else:
			# For all other colors, use color modulation
			sprite.modulate = color_values[color_type]

func get_color_type():
	return color_type

func set_color_type(new_type: ColorType):
	color_type = new_type
	update_appearance()

func set_is_in_mixer(in_mixer: bool):
	is_in_mixer = in_mixer
	is_available_for_mixing = !in_mixer
	if sprite:
		sprite.visible = !in_mixer
	call_deferred("_deferred_set_physics", in_mixer)

func _deferred_set_physics(in_mixer: bool):
	if collision_shape:
		collision_shape.disabled = in_mixer
	freeze = in_mixer

func reset_to_original():
	global_position = original_position
	linear_velocity = Vector2.ZERO
	angular_velocity = 0
	set_is_in_mixer(false)
	freeze = false
	
