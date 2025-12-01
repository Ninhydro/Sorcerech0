# FallingObject.gd
extends RigidBody2D

@export var object_type: String = ""  # "metal" or "glass"
@export var object_value: int = 1



@onready var sprite: Sprite2D = $Sprite2D

var can_be_pushed: bool = true
var spawn_time: float = 0.0
var min_movement_time: float = 1.0  # Don't freeze for at least 1 second
var last_push_time: float = 0.0


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
	
	#print("DEBUG: Object type in _ready(): '", object_type, "'")
	#check_texture_paths() 
	#setup_random_texture()
	#add_collision_exception_with(get_tree().get_first_node_in_group("player"))
	spawn_time = Time.get_time_dict_from_system()["second"]
	#print("Spawned ", object_type, " object - Layer: ", collision_layer, " Mask: ", collision_mask)

func setup_object(type: String):
	object_type = type
	#print("DEBUG: Object type set to: '", object_type, "'")
	setup_random_texture()
	
func setup_random_texture():
	var texture_paths: Array[String] = []
	#print("DEBUG: Setting up texture for type: '", object_type, "'")

	match object_type:
		"cyber":
			texture_paths = cyber_texture_paths
		"magus":
			texture_paths = magus_texture_paths
	#print("DEBUG: Object type: ", object_type, " Textures available: ", texture_array.size())
	if texture_paths.size() > 0:
		var random_path = texture_paths[randi() % texture_paths.size()]
		var texture = load(random_path)
		if texture:
			sprite.texture = texture
			#print("DEBUG: Applied texture: ", random_path.get_file(), " for type: ", object_type)
		else:
			print("ERROR: Failed to load texture: ", random_path)
	else:
		print("ERROR: No texture paths for type: ", object_type)
		
func _physics_process(_delta):
	#ar current_time = Time.get_time_dict_from_system()["second"]
	#var time_since_spawn = current_time - spawn_time
	
	# Only consider freezing after minimum time has passed
	#if (can_be_pushed and time_since_spawn > min_movement_time 
	#	and linear_velocity.length() < 0.1 
	#	and (current_time - last_push_time) > 0.5):
	#	can_be_pushed = false
	#	freeze = true
	pass
const MAX_PUSH_SPEED := 200.0  # tune this
const PUSH_FORCE := 50.0       # lower than before

func push(direction: Vector2, force: float = 200.0):
	# Wake it up
	sleeping = false
	can_be_pushed = true

	var dir := direction
	if dir == Vector2.ZERO:
		return

	dir = dir.normalized()
	# Small upward bias so it doesn’t clamp down on the player
	dir.y = -0.2  

	# Apply a modest impulse every frame we “push”
	apply_impulse(dir * force)
	apply_torque_impulse(randf_range(-50, 50))

	# Hard cap the speed so it never rockets off
	if linear_velocity.length() > MAX_PUSH_SPEED:
		linear_velocity = linear_velocity.normalized() * MAX_PUSH_SPEED
