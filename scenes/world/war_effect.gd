extends ColorRect

func _ready():
	color = Color.TRANSPARENT
	if material:
		material.set_shader_parameter("intensity", 0.0)

# Remove enable_war_effect and disable_war_effect methods
# Just keep set_war_effect

func set_war_effect(intensity: float, transparency: float):
	if material:
		material.set_shader_parameter("intensity", intensity)
		var tint_color = Color(1.0, 0.0, 0.0, transparency)
		material.set_shader_parameter("tint_color", tint_color)
	
	# Update visibility
	visible = intensity > 0.01
