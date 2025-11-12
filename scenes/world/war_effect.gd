extends ColorRect

func _ready():
	# Make sure base color is transparent
	color = Color.TRANSPARENT
	
func enable_war_effect():
	var tween = create_tween()
	tween.tween_method(_set_intensity, 0.0, 1.0, 1.0)

func disable_war_effect():
	var tween = create_tween()
	tween.tween_method(_set_intensity, 1.0, 0.0, 1.0)

func _set_intensity(value: float):
	material.set_shader_parameter("intensity", value)

func set_war_effect(intensity: float, transparency: float):
	# Set intensity
	material.set_shader_parameter("intensity", intensity)
	
	# Set transparency (alpha of tint color)
	var tint_color = material.get_shader_parameter("tint_color")
	tint_color.a = transparency
	material.set_shader_parameter("tint_color", tint_color)
