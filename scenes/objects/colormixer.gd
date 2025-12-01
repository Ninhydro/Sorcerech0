# res://scripts/objects/ColorMixer.gd
extends Area2D
class_name ColorMixer

@onready var output_spawn_point: Marker2D = $OutputSpawnPoint
@onready var sprite_2d: Sprite2D = $Sprite2D  # Reference to mixer sprite


@export var normal_object_scene: PackedScene = preload("res://scenes/objects/color_object.tscn")
@export var explosive_object_scene: PackedScene = preload("res://scenes/objects/explosive_color_object.tscn")
@export var use_explosive_orange: bool = false
@export var orange_explosion_time: float = 3.0

var color_recipes = {
	[ColorObject.ColorType.RED, ColorObject.ColorType.BLUE]: ColorObject.ColorType.PURPLE,
	[ColorObject.ColorType.RED, ColorObject.ColorType.YELLOW]: ColorObject.ColorType.ORANGE,
	[ColorObject.ColorType.BLUE, ColorObject.ColorType.YELLOW]: ColorObject.ColorType.GREEN,
	[ColorObject.ColorType.RED, ColorObject.ColorType.GREEN]: ColorObject.ColorType.BROWN,
	[ColorObject.ColorType.BLUE, ColorObject.ColorType.ORANGE]: ColorObject.ColorType.BROWN,
	[ColorObject.ColorType.YELLOW, ColorObject.ColorType.PURPLE]: ColorObject.ColorType.BROWN,
	[ColorObject.ColorType.GREEN, ColorObject.ColorType.BLUE]: ColorObject.ColorType.CYAN,
	[ColorObject.ColorType.RED, ColorObject.ColorType.PURPLE]: ColorObject.ColorType.MAGENTA,
	[ColorObject.ColorType.ORANGE, ColorObject.ColorType.YELLOW]: ColorObject.ColorType.GOLD,
	[ColorObject.ColorType.RED, ColorObject.ColorType.RED]: ColorObject.ColorType.RED,
	[ColorObject.ColorType.BLUE, ColorObject.ColorType.BLUE]: ColorObject.ColorType.BLUE,
	[ColorObject.ColorType.YELLOW, ColorObject.ColorType.YELLOW]: ColorObject.ColorType.YELLOW,
}

var current_colors: Array[ColorObject] = []
var is_mixing: bool = false

signal mixing_started
signal mixing_completed(result_color: ColorObject.ColorType)

func _ready():
	add_to_group("ColorMixers")
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node):
	if body is ColorObject and not is_mixing and body.is_available_for_mixing:
		add_color_to_mix(body)


func add_color_to_mix(color_object: ColorObject):
	if current_colors.size() < 2:
		color_object.set_is_in_mixer(true)
		current_colors.append(color_object)
		
		# Visual feedback based on how many objects are in mixer
		if current_colors.size() == 1:
			blink_mixer(Color.CYAN, 0.3, 3)
			print("First object added to mixer")
		else:
			blink_mixer(Color.YELLOW, 0.2, 4)
			print("Second object added - ready to mix!")
		
		if current_colors.size() == 2:
			start_mixing()


func start_mixing():
	is_mixing = true
	mixing_started.emit()
	
	print("Mixing started with colors: ", current_colors[0].get_color_type(), " + ", current_colors[1].get_color_type())
	
	rainbow_mixer_effect(1.0)
	await get_tree().create_timer(1.0 / Global.global_time_scale).timeout
	_on_mixing_complete()


func _on_mixing_complete():
	var result := mix_colors()
	
	print("ColorMixer: result = ", ColorObject.ColorType.keys()[result])
	
	if result == ColorObject.ColorType.BROWN:
		blink_mixer(Color.RED, 0.15, 6)
		print("Mixing failed - created BROWN")
	else:
		sparkle_mixer_effect(Color.GOLD, 0.5)
		print("Mixing successful! Created: ", ColorObject.ColorType.keys()[result])
	
	mixing_completed.emit(result)
	spawn_output_object(result)
	clear_mixed_objects()
	reset_mixer()


func mix_colors() -> ColorObject.ColorType:
	if current_colors.size() != 2:
		return ColorObject.ColorType.RED
	
	var color1 = current_colors[0].get_color_type()
	var color2 = current_colors[1].get_color_type()
	
	print("Attempting to mix: ", ColorObject.ColorType.keys()[color1], " + ", ColorObject.ColorType.keys()[color2])
	
	var combination1 = [color1, color2]
	var combination2 = [color2, color1]
	
	if color_recipes.has(combination1):
		return color_recipes[combination1]
	elif color_recipes.has(combination2):
		return color_recipes[combination2]
	else:
		return ColorObject.ColorType.BROWN


func spawn_output_object(color_type: ColorObject.ColorType):
	# Decide which scene to use
	var scene: PackedScene = normal_object_scene
	var will_be_explosive := false
	
	if use_explosive_orange and color_type == ColorObject.ColorType.ORANGE:
		scene = explosive_object_scene
		will_be_explosive = true
	
	var output_obj: ColorObject = scene.instantiate()
	get_parent().add_child(output_obj)
	output_obj.global_position = output_spawn_point.global_position
	output_obj.original_position = output_obj.global_position
	output_obj.set_color_type(color_type)
	output_obj.set_is_in_mixer(false)
	output_obj.freeze = false
	
	if will_be_explosive and output_obj.has_method("make_explosive"):
		output_obj.make_explosive(orange_explosion_time)
	
	# Small pop-out impulse if it's a RigidBody2D
	if output_obj is RigidBody2D:
		output_obj.apply_impulse(Vector2(randf_range(-50, 50), -100))
		var tween = create_tween()
		output_obj.scale = Vector2(0.5, 0.5)
		tween.tween_property(output_obj, "scale", Vector2(1.0, 1.0), 0.3)
	
	print("Spawned output: ", ColorObject.ColorType.keys()[color_type], " explosive=", will_be_explosive)


func clear_mixed_objects():
	for color_obj in current_colors:
		if is_instance_valid(color_obj):
			color_obj.queue_free()


func reset_mixer():
	current_colors.clear()
	is_mixing = false
	# Reset appearance
	if sprite_2d:
		var tween = create_tween()
		tween.tween_property(sprite_2d, "modulate", Color.WHITE, 0.2)
		tween.tween_property(sprite_2d, "scale", Vector2(1.0, 1.0), 0.2)


# ===== VISUAL EFFECT FUNCTIONS =====

func flash_mixer(color: Color, duration: float):
	if sprite_2d:
		var original_modulate = sprite_2d.modulate
		var tween = create_tween()
		tween.tween_property(sprite_2d, "modulate", color, duration * 0.3)
		tween.tween_property(sprite_2d, "modulate", original_modulate, duration * 0.7)

func blink_mixer(color: Color, blink_duration: float, blink_count: int):
	if not sprite_2d:
		return
	
	var original_modulate = sprite_2d.modulate
	var tween = create_tween()
	
	for i in range(blink_count):
		tween.tween_property(sprite_2d, "modulate", color, blink_duration * 0.3)
		tween.tween_property(sprite_2d, "modulate", original_modulate, blink_duration * 0.3)
	
	tween.tween_property(sprite_2d, "modulate", original_modulate, 0.1)

func rainbow_mixer_effect(duration: float):
	if not sprite_2d:
		return
	
	var colors = [
		Color.RED, Color.ORANGE, Color.YELLOW,
		Color.GREEN, Color.CYAN, Color.BLUE,
		Color.PURPLE, Color.MAGENTA
	]
	
	var tween = create_tween()
	tween.set_parallel(true)
	
	for color in colors:
		tween.tween_property(sprite_2d, "modulate", color, duration / colors.size())
	
	tween.tween_property(sprite_2d, "scale", Vector2(1.1, 1.1), duration * 0.3)
	tween.tween_property(sprite_2d, "scale", Vector2(0.9, 0.9), duration * 0.3)
	tween.tween_property(sprite_2d, "scale", Vector2(1.1, 1.1), duration * 0.3)
	tween.tween_property(sprite_2d, "scale", Vector2(1.0, 1.0), duration * 0.1)

func sparkle_mixer_effect(color: Color, duration: float):
	if not sprite_2d:
		return
	
	var tween = create_tween()
	tween.set_parallel(true)
	
	tween.tween_property(sprite_2d, "modulate", color, duration * 0.1)
	tween.tween_property(sprite_2d, "scale", Vector2(1.3, 1.3), duration * 0.2)
	tween.tween_property(sprite_2d, "scale", Vector2(1.0, 1.0), duration * 0.3)
	tween.tween_property(sprite_2d, "modulate", Color.WHITE, duration * 0.4)
