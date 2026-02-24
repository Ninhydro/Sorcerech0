extends CharacterBody2D

@onready var sprite_2d: Sprite2D = $"Maya kid"
@onready var animation_player: AnimationPlayer =$"Maya kid/AnimationPlayer"
@onready var interaction_area: Area2D = $InteractionArea
@onready var bubble_timer: Timer = $BubbleTimer

# Configuration
@export var dialog_timeline: String = "maya_kid1"
@export var bubble_texts: Array[String] = [
	"Phina you're here!",
	"Wanna some batteries?",
	"Wanna play with me?",
	
]
@export var bubble_interval_min: float = 5.0
@export var bubble_interval_max: float = 15.0
@export var speech_bubble_scene: PackedScene  # Drag SpeechBubble.tscn here
@export var bubble_y_offset: float = -100  # Adjust this to position bubble higher/lower
@export var bubble_x_offset: float = 0    # Horizontal adjustment

# Dialog state management
var is_dialog_active: bool = false
var can_interact: bool = true
var interaction_cooldown: float = 0.0
var play_once: bool = false
var player_in_range: bool = false 
var current_bubble = null  # Track current bubble instance

func _ready():
	print("NPC _ready called")
	# Initially hide the NPC
	visible = false
	animation_player.play("idle")
	# Start bubble timer
	_reset_bubble_timer()
	
	# Connect signals
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)
	bubble_timer.timeout.connect(_show_random_bubble)

func _process(delta):
	# Only process if timeline condition is met
	
	if not (Global.timeline >= 3.5 and Global.timeline <= 5):
		visible = false
		return
	
	# Make visible when condition is met
	#if not visible:
	#	visible = true
	#	animation_player.play("idle")
	
	# Flip sprite based on player position
	if Global.player:
		sprite_2d.flip_h = Global.player.global_position.x < global_position.x
	
	# Handle cooldown
	if interaction_cooldown > 0:
		interaction_cooldown -= delta
		if interaction_cooldown <= 0:
			can_interact = true
	
	# Check for interaction
	if (can_interact and 
		player_in_range and 
		Input.is_action_just_pressed("yes") and 
		not is_dialog_active and
		not play_once):
		
		_start_dialog()

func _start_dialog():
	print("Starting dialog")
	
	# Set flags
	can_interact = false
	is_dialog_active = true
	play_once = true
	
	# Start cooldown
	interaction_cooldown = 1.0
	
	# Start Dialogic
	Dialogic.start(dialog_timeline, false)
	
	# Remove current bubble if exists
	remove_current_bubble()
	
	# Reset after delay
	reset_play_once_after_delay(10.0)
	_reset_dialog_state_after_timeout()

func _reset_dialog_state_after_timeout():
	await get_tree().create_timer(0.5).timeout
	var dialogic_nodes = get_tree().get_nodes_in_group("dialogic_main_node")
	if dialogic_nodes.size() == 0:
		is_dialog_active = false
		print("Dialog ended")
	else:
		_reset_dialog_state_after_timeout()

func _show_random_bubble():
	print("_show_random_bubble called - player_in_range:", player_in_range)
	
	if (bubble_texts.size() > 0 and 
		Global.player and 
		visible and 
		not is_dialog_active and
		player_in_range):  # Only show when player is nearby
		
		var random_text = bubble_texts[randi() % bubble_texts.size()]
		print("Selected text: ", random_text)
		
		# Use the SpeechBubble scene instead of creating from code
		create_speech_bubble_scene(random_text)
	
	_reset_bubble_timer()

func remove_current_bubble():
	# Safely remove current bubble without causing errors
	if current_bubble and is_instance_valid(current_bubble):
		current_bubble.queue_free()
		current_bubble = null

func create_speech_bubble_scene(text: String):
	print("Creating bubble from SpeechBubble scene: ", text)
	
	# Remove any existing bubble first
	remove_current_bubble()
	
	# Check if we have a speech bubble scene assigned
	if not speech_bubble_scene:
		print("ERROR: No speech_bubble_scene assigned! Falling back to simple bubble.")
		create_simple_world_bubble(text)
		return
	
	# Create instance from the scene
	var bubble = speech_bubble_scene.instantiate()
	
	# Add as child of NPC (so it moves with NPC)
	add_child(bubble)
	current_bubble = bubble
	
	# Wait a frame for the bubble to be ready
	await get_tree().process_frame
	
	# Check if bubble has the set_text method
	if bubble.has_method("set_text"):
		# Call set_text method on the bubble
		bubble.set_text(text, 3.0)
		
		# Adjust bubble position using our offset variables
		# The bubble already positions itself, but we can adjust further
		bubble.position += Vector2(bubble_x_offset, bubble_y_offset)
		
		print("SpeechBubble scene created at position: {bubble.position}")
	else:
		print("ERROR: Bubble scene doesn't have set_text method!")
		# Fallback to simple bubble
		bubble.queue_free()
		create_simple_world_bubble(text)

func create_simple_world_bubble(text: String):
	print("Creating simple world bubble (fallback): ", text)
	
	# Remove any existing bubble first
	remove_current_bubble()
	
	# Create a Node2D-based bubble (works in world space)
	var bubble = Node2D.new()
	var bg = ColorRect.new()
	var label = Label.new()
	var bubble_timer = Timer.new()
	
	# Configure background (rounded corners with shader)
	var material = ShaderMaterial.new()
	var shader = Shader.new()
	shader.code = """
	shader_type canvas_item;
	
	void fragment() {
		COLOR = vec4(0.1, 0.1, 0.1, 0.95);
		// Rounded corners
		vec2 uv = UV * 2.0 - 1.0;
		float radius = 0.3;
		float dist = length(max(abs(uv) - vec2(1.0 - radius), 0.0)) - radius;
		float alpha = smoothstep(0.0, 0.01, -dist);
		COLOR.a *= alpha;
		
		// Simple border
		if (dist > -0.02 && dist < 0.0) {
			COLOR.rgb = vec3(0.3, 0.3, 0.3);
		}
	}
	"""
	material.shader = shader
	bg.material = material
	bg.color = Color(0.1, 0.1, 0.1, 0.95)
	
	# Configure label
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_font_size_override("font_size", 12)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	
	# Configure timer
	bubble_timer.one_shot = true
	bubble_timer.wait_time = 3.0
	bubble_timer.timeout.connect(func(): 
		if is_instance_valid(bubble):
			bubble.queue_free()
			current_bubble = null
	)
	
	# Build hierarchy
	bubble.add_child(bg)
	bg.add_child(label)
	bubble.add_child(bubble_timer)
	
	# Add to scene as child of NPC (so it moves with NPC)
	add_child(bubble)
	current_bubble = bubble
	
	# Wait for layout then calculate size
	await get_tree().process_frame
	
	var text_size = label.size
	var padding = Vector2(20, 10)
	var max_bubble_width = 250.0
	
	var bubble_width = min(text_size.x + padding.x * 2, max_bubble_width)
	var bubble_height = text_size.y + padding.y * 2
	
	# Set sizes
	bg.size = Vector2(bubble_width, bubble_height)
	label.size = Vector2(bubble_width - padding.x * 2, bubble_height - padding.y * 2)
	label.position = Vector2(padding.x, padding.y)
	
	# Position the bubble with offsets
	bubble.position = Vector2(-bubble_width / 2 + bubble_x_offset, bubble_y_offset)
	
	print("Simple bubble positioned at: {bubble.position}")
	print("Bubble Y offset: {bubble_y_offset}, X offset: {bubble_x_offset}")
	
	# Start timer
	bubble_timer.start()
	
	print("Simple world bubble created and positioned")

func _reset_bubble_timer():
	var interval = randf_range(bubble_interval_min, bubble_interval_max)
	print("Setting next bubble timer: ", interval, " seconds")
	bubble_timer.start(interval)

func _on_body_entered(body):
	if body == Global.player:
		player_in_range = true
		print("Player entered interaction area")

func _on_body_exited(body):
	if body == Global.player:
		player_in_range = false
		print("Player exited interaction area")

func reset_play_once_after_delay(seconds: float = 10.0):
	await get_tree().create_timer(seconds).timeout
	play_once = false
	print("play_once reset to false")

# Manual test function
func _input(event):
	# Press B key to manually test bubble
	if event.is_action_pressed("ui_text_backspace"):  # Backspace key
		print("=== MANUAL BUBBLE TEST ===")
		print("Player position: ", Global.player.global_position if Global.player else "No player")
		print("NPC position: ", global_position)
		print("Global.timeline: ", Global.timeline)
		
		if Global.timeline >= 3:
			create_speech_bubble_scene("MANUAL TEST BUBBLE!")
		else:
			print("Cannot test: Global.timeline < 3")
