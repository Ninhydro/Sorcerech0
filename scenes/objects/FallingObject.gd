# FallingObject.gd
extends RigidBody2D

@export var object_type: String = ""  # "metal" or "glass"
@export var object_value: int = 1

@onready var sprite: Sprite2D = $Sprite2D

var can_be_pushed: bool = true
var spawn_time: float = 0.0
var min_movement_time: float = 1.0  # Don't freeze for at least 1 second
var last_push_time: float = 0.0
var has_landed_on_player: bool = false  # Track if we've landed on player

var cyber_texture_paths: Array[String] = [
	"res://assets_image/Objects/minigame1_objects1.png",
	"res://assets_image/Objects/minigame1_objects2.png", 
	"res://assets_image/Objects/minigame1_objects3.png",
	"res://assets_image/Objects/minigame1_objects4.png",
]

var magus_texture_paths: Array[String] = [
	"res://assets_image/Objects/minigame1_objects7.png",
	"res://assets_image/Objects/minigame1_objects8.png",
	"res://assets_image/Objects/minigame1_objects9.png",
	"res://assets_image/Objects/minigame1_objects10.png"
]

func check_texture_paths():
	print("=== CHECKING TEXTURE PATHS ===")
	
	for path in cyber_texture_paths:
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			print("✓ Cyber texture exists: ", path.get_file())
			file.close()
		else:
			print("✗ Cyber texture missing: ", path.get_file())
	
	for path in magus_texture_paths:
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			print("✓ Magus texture exists: ", path.get_file())
			file.close()
		else:
			print("✗ Magus texture missing: ", path.get_file())
	print("=== END TEXTURE CHECK ===")
	
func _ready():
	add_to_group("FallingObjects")
	gravity_scale = 2.0
	linear_damp = 0.5
	angular_damp = 0.5
	freeze = false  # Ensure it's not frozen initially
	
	collision_layer = 6  # Objects layer
	collision_mask =  2 | 7 # Collide with player (layer 1) and bins (layer 4)
	
	spawn_time = Time.get_time_dict_from_system()["second"]

func setup_object(type: String):
	object_type = type
	setup_random_texture()
	
func setup_random_texture():
	var texture_paths: Array[String] = []

	match object_type:
		"cyber":
			texture_paths = cyber_texture_paths
		"magus":
			texture_paths = magus_texture_paths
	
	if texture_paths.size() > 0:
		var random_path = texture_paths[randi() % texture_paths.size()]
		var texture = load(random_path)
		if texture:
			sprite.texture = texture
		else:
			print("ERROR: Failed to load texture: ", random_path)
	else:
		print("ERROR: No texture paths for type: ", object_type)

func _physics_process(_delta):
	pass

var MAX_PUSH_SPEED := 200.0 * Global.global_time_scale # tune this
const PUSH_FORCE := 50.0       # lower than before

func push(direction: Vector2, force: float = 200.0):
	# Wake it up
	sleeping = false
	freeze = false  # Ensure it's not frozen
	can_be_pushed = true
	last_push_time = Time.get_time_dict_from_system()["second"]
	
	var dir := direction.normalized()
	
	# If pushing upward, give a stronger vertical boost
	if dir.y < 0:
		dir.y *= 10.0  # Boost upward pushes
	
	apply_impulse(dir * force)
	apply_torque_impulse(randf_range(-50, 50))
	
	# Cap the speed
	if linear_velocity.length() > MAX_PUSH_SPEED:
		linear_velocity = linear_velocity.normalized() * MAX_PUSH_SPEED
	
	# Reset freeze cooldown
	spawn_time = Time.get_time_dict_from_system()["second"]
	has_landed_on_player = false  # Reset when pushed

func _on_body_entered(body):
	# Check if the object landed on the player
	if body is CharacterBody2D and body.name == "Player":
		if not has_landed_on_player:
			has_landed_on_player = true
			
			# Add a small upward impulse to prevent sticking
			var jump_impulse = Vector2(0, -50) * Global.global_time_scale
			apply_impulse(jump_impulse)
			
			# Also add a small random horizontal impulse to separate
			var random_horizontal = randf_range(-30, 30) * Global.global_time_scale
			apply_impulse(Vector2(random_horizontal, 0))
			
			print("FallingObject: Applied small jump impulse to prevent sticking with player")

# You'll need to add this method to your existing code
func _integrate_forces(state):
	# This runs during physics integration and can help with collision response
	pass
