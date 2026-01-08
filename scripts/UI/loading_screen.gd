extends CanvasLayer

@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var color_rect: ColorRect = $Control/ColorRect

var _target_scene := ""
var _is_loading := false
const MIN_LOOP_TIME := 5.0

func _ready():
	visible = false
	if color_rect:
		color_rect.modulate.a = 1.0
	# Force it to be on top
	layer = 100

func show_and_load(scene_path: String):
	if _is_loading or anim == null:
		return

	_is_loading = true
	_target_scene = scene_path
	
	# DEBUG: Add print to confirm function is called
	print("LoadingScreen: show_and_load called for scene: ", scene_path)
	
	# Make it fully opaque IMMEDIATELY
	if color_rect:
		color_rect.modulate.a = 1.0
	
	visible = true
	
	# DEBUG: Check if we're visible
	print("LoadingScreen: visible = ", visible)
	
	# Play fade_in (if it exists, otherwise play loop directly)
	if anim.has_animation("fade_in"):
		anim.play("fade_in")
		await anim.animation_finished
		print("LoadingScreen: fade_in animation finished")
	
	# Play loop animation
	if anim.has_animation("loop"):
		anim.play("loop")
		print("LoadingScreen: loop animation started")
	
	# Wait minimum duration
	await get_tree().create_timer(MIN_LOOP_TIME).timeout
	print("LoadingScreen: Minimum duration passed")
	
	# Change scene if we have a target
	if _target_scene != "":
		print("LoadingScreen: Changing to scene: ", _target_scene)
		get_tree().change_scene_to_file.call_deferred(_target_scene)
	else:
		print("LoadingScreen: No scene to change to, staying in current scene")

func show_instantly_and_load(scene_path: String):
	if _is_loading or anim == null:
		return

	_is_loading = true
	_target_scene = scene_path
	
	print("LoadingScreen: show_instantly_and_load called for scene: ", scene_path)
	
	# Set to fully opaque immediately
	if color_rect:
		color_rect.modulate.a = 1.0
	
	# Make visible WITHOUT any delay
	visible = true
	
	# DEBUG: Force a redraw
	get_tree().root.set_disable_input(true)  # Optional: disable input during load
	
	# Skip animations, just wait
	await get_tree().create_timer(MIN_LOOP_TIME).timeout
	print("LoadingScreen: Minimum duration passed (instant)")
	
	# Change scene
	if _target_scene != "":
		print("LoadingScreen: Changing to scene: ", _target_scene)
		get_tree().change_scene_to_file.call_deferred(_target_scene)
		get_tree().root.set_disable_input(false)  # Re-enable input
	else:
		print("LoadingScreen: No scene to change to")
		get_tree().root.set_disable_input(false)

func hide_after_ready():
	print("LoadingScreen: hide_after_ready called")
	
	if anim == null:
		visible = false
		_is_loading = false
		return

	# Stop any current animation
	anim.stop()
	
	# Play fade_out if it exists
	if anim.has_animation("fade_out"):
		anim.play("fade_out")
		await anim.animation_finished
		print("LoadingScreen: fade_out animation finished")
	
	visible = false
	_is_loading = false
	print("LoadingScreen: Hidden")
