# ColorMixer.gd
extends Area2D
class_name ColorMixer

@onready var output_spawn_point = $OutputSpawnPoint
@onready var sprite_2d = $Sprite2D  # Reference to mixer sprite

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

var current_colors = []
var is_mixing = false
var output_object_scene: PackedScene

signal mixing_started
signal mixing_completed(result_color)

func _ready():
	body_entered.connect(_on_body_entered)
	output_object_scene = preload("res://scenes/objects/color_object.tscn")

func _on_body_entered(body):
	if body is ColorObject and not is_mixing and body.is_available_for_mixing:
		add_color_to_mix(body)

func add_color_to_mix(color_object: ColorObject):
	if current_colors.size() < 2:
		color_object.set_is_in_mixer(true)
		current_colors.append(color_object)
		
		# Visual feedback based on how many objects are in mixer
		if current_colors.size() == 1:
			# First object - blue blinking
			blink_mixer(Color.CYAN, 0.3, 3)  # Cyan, 0.3s duration, 3 blinks
			print("First object added to mixer")
		else:
			# Second object - yellow blinking (ready to mix)
			blink_mixer(Color.YELLOW, 0.2, 4)  # Yellow, 0.2s duration, 4 fast blinks
			print("Second object added - ready to mix!")
		
		if current_colors.size() == 2:
			start_mixing()

func start_mixing():
	is_mixing = true
	mixing_started.emit()
	
	print("Mixing started with colors: ", current_colors[0].get_color_type(), " + ", current_colors[1].get_color_type())
	
	# Visual feedback: rainbow cycling during mixing
	rainbow_mixer_effect(1.0)
	
	# Wait for mixing duration
	await get_tree().create_timer(1.0).timeout
	_on_mixing_complete()

func _on_mixing_complete():
	var result = mix_colors()
	
	print("ColorMixer: Emitting mixing_completed signal with: ", ColorObject.ColorType.keys()[result])
	
	# Visual feedback based on result
	if result == ColorObject.ColorType.BROWN:
		# Failed mix - red blinking
		blink_mixer(Color.RED, 0.15, 6)  # Fast red blinking for failure
		print("Mixing failed - created BROWN")
	else:
		# Successful mix - golden sparkle effect
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
	var output_obj = output_object_scene.instantiate()
	output_obj.set_color_type(color_type)
	
	get_parent().add_child(output_obj)
	output_obj.global_position = output_spawn_point.global_position
	
	# Visual feedback: make output object pop out
	if output_obj is RigidBody2D:
		output_obj.apply_impulse(Vector2(randf_range(-50, 50), -100))
		# Scale effect
		var tween = create_tween()
		output_obj.scale = Vector2(0.5, 0.5)
		tween.tween_property(output_obj, "scale", Vector2(1.0, 1.0), 0.3)
	
	print("Spawned output: ", ColorObject.ColorType.keys()[color_type])

func clear_mixed_objects():
	for color_obj in current_colors:
		if is_instance_valid(color_obj):
			color_obj.queue_free()

func reset_mixer():
	current_colors.clear()
	is_mixing = false
	# Reset mixer appearance
	if sprite_2d:
		var tween = create_tween()
		tween.tween_property(sprite_2d, "modulate", Color.WHITE, 0.2)
		tween.tween_property(sprite_2d, "scale", Vector2(1.0, 1.0), 0.2)

# VISUAL EFFECT FUNCTIONS

func flash_mixer(color: Color, duration: float):
	"""Simple flash effect"""
	if sprite_2d:
		var original_modulate = sprite_2d.modulate
		var tween = create_tween()
		tween.tween_property(sprite_2d, "modulate", color, duration * 0.3)
		tween.tween_property(sprite_2d, "modulate", original_modulate, duration * 0.7)

func blink_mixer(color: Color, blink_duration: float, blink_count: int):
	"""Blinking effect with specified color, duration, and number of blinks"""
	if not sprite_2d:
		return
	
	var original_modulate = sprite_2d.modulate
	var tween = create_tween()
	
	for i in range(blink_count):
		# Flash on
		tween.tween_property(sprite_2d, "modulate", color, blink_duration * 0.3)
		# Flash off (back to original)
		tween.tween_property(sprite_2d, "modulate", original_modulate, blink_duration * 0.3)
	
	# Ensure we end with original color
	tween.tween_property(sprite_2d, "modulate", original_modulate, 0.1)

func rainbow_mixer_effect(duration: float):
	"""Rainbow color cycling during mixing process"""
	if not sprite_2d:
		return
	
	var colors = [
		Color.RED,
		Color.ORANGE,
		Color.YELLOW,
		Color.GREEN,
		Color.CYAN,
		Color.BLUE,
		Color.PURPLE,
		Color.MAGENTA
	]
	
	var tween = create_tween()
	tween.set_parallel(true)  # Allow multiple properties to animate at once
	
	# Color cycling
	for color in colors:
		tween.tween_property(sprite_2d, "modulate", color, duration / colors.size())
	
	# Pulsing scale effect
	tween.tween_property(sprite_2d, "scale", Vector2(1.1, 1.1), duration * 0.3)
	tween.tween_property(sprite_2d, "scale", Vector2(0.9, 0.9), duration * 0.3)
	tween.tween_property(sprite_2d, "scale", Vector2(1.1, 1.1), duration * 0.3)
	tween.tween_property(sprite_2d, "scale", Vector2(1.0, 1.0), duration * 0.1)

func sparkle_mixer_effect(color: Color, duration: float):
	"""Sparkle effect for successful mixes"""
	if not sprite_2d:
		return
	
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Quick bright flash
	tween.tween_property(sprite_2d, "modulate", color, duration * 0.1)
	
	# Scale pulse
	tween.tween_property(sprite_2d, "scale", Vector2(1.3, 1.3), duration * 0.2)
	tween.tween_property(sprite_2d, "scale", Vector2(1.0, 1.0), duration * 0.3)
	
	# Return to normal
	tween.tween_property(sprite_2d, "modulate", Color.WHITE, duration * 0.4)

# Additional effect: Color-based feedback based on input objects
func get_mixer_color_from_inputs() -> Color:
	"""Get a mixed color based on the current input objects"""
	if current_colors.size() == 0:
		return Color.WHITE
	elif current_colors.size() == 1:
		# Show color of the single object
		match current_colors[0].get_color_type():
			ColorObject.ColorType.RED:
				return Color.RED
			ColorObject.ColorType.BLUE:
				return Color.BLUE
			ColorObject.ColorType.YELLOW:
				return Color.YELLOW
			_:
				return Color.WHITE
	else:
		# Show preview of what the mix might create
		var result = mix_colors()
		match result:
			ColorObject.ColorType.GREEN:
				return Color.GREEN
			ColorObject.ColorType.PURPLE:
				return Color.PURPLE
			ColorObject.ColorType.ORANGE:
				return Color.ORANGE
			ColorObject.ColorType.GOLD:
				return Color.GOLD
			_:
				return Color.BROWN

# Call this when you want to show a preview of the mix
func show_mix_preview():
	if current_colors.size() == 2 and not is_mixing:
		var preview_color = get_mixer_color_from_inputs()
		flash_mixer(preview_color, 0.5)
