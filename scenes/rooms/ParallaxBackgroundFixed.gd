# SceneFixedParallax_Simple.gd
extends ParallaxBackground

@export var parallax_scale: Vector2 = Vector2(0.3, 0.2)

var camera: Camera2D

func _ready():
	print("🎯 Simple Parallax ready")
	
	# Always activate parallax
	for child in get_children():
		if child is ParallaxLayer:
			child.motion_scale = parallax_scale
			print("🎯 Activated parallax for: ", child.name)

func _process(delta):
	if not camera:
		camera = Global.get_player_camera()
		return
	
	# Update parallax scroll
	scroll_offset = -camera.global_position * parallax_scale
