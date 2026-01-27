extends "res://addons/dialogic/Modules/Background/dialogic_background.gd"

var shader_material: ShaderMaterial

func _ready() -> void:
	print("=== BACKGROUND LOADED ===")
	
	# Get the shader material
	shader_material = self.material as ShaderMaterial
	
	if shader_material:
		print("Shader material found, setting parameters...")
		
		# ⚠️ CRITICAL: Set ALL shader parameters here
		# These override the editor defaults
		
		# 1. Base color
		shader_material.set_shader_parameter("base_color", Color(0.235, 0.157, 0.059, 1.0))
		
		# 2. EFFECT PARAMETERS - Set these to your desired values
		shader_material.set_shader_parameter("grain_amount", 0.03)      # Increase for more grain
		shader_material.set_shader_parameter("flicker_speed", 0.05)      # Speed of flicker
		shader_material.set_shader_parameter("flicker_amount", 0.1)    # Intensity of flicker
		shader_material.set_shader_parameter("tint_color", Color(0.8, 0.7, 0.6, 0.3))
		
		print("Shader parameters set successfully")
	else:
		print("No shader material found!")
		self.color = Color(0.235, 0.157, 0.059)  # Fallback brown

func _update_background(argument: String, time: float) -> void:
	print("Update with: '", argument, "'")
	
	if not shader_material:
		return
	
	argument = argument.strip_edges()
	
	# Change base color based on argument
	match argument:
		"yellow":
			shader_material.set_shader_parameter("base_color", Color(1.0, 1.0, 0.0, 1.0))
		"black":
			shader_material.set_shader_parameter("base_color", Color(0.0, 0.0, 0.0, 1.0))
		"brown":
			shader_material.set_shader_parameter("base_color", Color(0.235, 0.157, 0.059, 1.0))
		"":
			shader_material.set_shader_parameter("base_color", Color(0.235, 0.157, 0.059, 1.0))
		_:
			if argument.begins_with("#"):
				shader_material.set_shader_parameter("base_color", Color(argument))
	
	# ⚠️ IMPORTANT: You can also change effects dynamically here!
	# Example: Make effects stronger for dramatic moments
	if argument == "intense":
		shader_material.set_shader_parameter("grain_amount", 0.15)    # Very grainy
		shader_material.set_shader_parameter("flicker_amount", 0.12)  # Strong flicker
