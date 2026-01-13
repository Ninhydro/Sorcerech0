extends Node2D

@onready var background: ColorRect = $Background
@onready var label: Label = $Background/Label
@onready var timer: Timer = $Timer

@export var max_width: float = 300.0
@export var min_width: float = 50.0  # NEW: Minimum width for rectangle shape
@export var padding: Vector2 = Vector2(10, 5)
@export var font_size: int = 6
@export var background_color: Color = Color(0.1, 0.1, 0.1, 0.95)
@export var text_color: Color = Color.WHITE

func _ready():
	visible = false
	
	# Configure background for rounded corners (using shader)
	var material = ShaderMaterial.new()
	var shader = Shader.new()
	shader.code = """
	shader_type canvas_item;
	
	void fragment() {
		COLOR = vec4(0.1, 0.1, 0.1, 0.95);  // Background color
		// Rounded corners
		vec2 uv = UV * 2.0 - 1.0;
		float radius = 0.3;
		float dist = length(max(abs(uv) - vec2(1.0 - radius), 0.0)) - radius;
		float alpha = smoothstep(0.0, 0.01, -dist);
		COLOR.a *= alpha;
		
		// Border
		float border = 0.02;
		float border_dist = length(max(abs(uv) - vec2(1.0 - radius - border), 0.0)) - radius - border;
		if (border_dist < 0.0 && dist > -border) {
			COLOR.rgb = vec3(0.3, 0.3, 0.3);  // Border color
		}
	}
	"""
	material.shader = shader
	background.material = material
	background.color = background_color
	
	# Configure label
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", text_color)
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	
	# Connect timer
	timer.timeout.connect(_on_timer_timeout)

func set_text(text_content: String, wait_time: float = 3.0):
	label.text = text_content
	visible = true
	
	# Wait for layout
	await get_tree().process_frame
	
	# Get text size
	var text_size = label.size
	
	# Calculate background size
	var target_width = max(min_width, min(text_size.x + padding.x * 2, max_width))
	var target_height = text_size.y + padding.y * 2
	
	# Set sizes
	background.size = Vector2(target_width, target_height)
	label.size = Vector2(target_width - padding.x * 2, target_height - padding.y * 2)
	label.position = Vector2(padding.x, padding.y)
	
	# Center the bubble above the position (called from NPC)
	position = Vector2(-target_width / 2, -target_height - 20)
	
	# Start timer
	timer.wait_time = wait_time
	timer.start()

func _on_timer_timeout():
	queue_free()  # Remove from scene
