extends CharacterBody2D
class_name CharacterCutscene

# Signals
signal cutscene_started
signal cutscene_finished

# Scene References
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var cutscene_camera: Camera2D = $Camera2D
@onready var black_overlay: ColorRect = $BlackOverlay if has_node("BlackOverlay") else null
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

# Cutscene Configuration (set in child scenes)
var cutscene_name: String = "unnamed_cutscene"
var play_only_once: bool = true
var global_flag_to_set: String = ""  # Global flag name to set when finished
var area_activation_flag: String = ""  # Required global flag to activate (can be empty)

# Sequence Configuration (set in child scenes)
var sequence: Array = []  # [{type: "animation/dialog", name: "name", loop: false, wait: true}]
var player_markers: Dictionary = {}  # {marker_name: Vector2 position}
var cutscene_markers: Dictionary = {}  # {marker_name: Vector2 position} for cutscene movement

# Internal State
var _has_been_triggered: bool = false
var _current_step: int = -1
var _is_cutscene_active: bool = false
var _player_ref: CharacterBody2D = null
var _original_position: Vector2 


var current_sequence_index: int = 0
# Override Functions (for child scenes)
func _setup_cutscene():
	"""Override this in child scenes to setup sequence and markers"""
	pass

func _on_cutscene_start():
	"""Called when cutscene starts"""
	pass

func _on_cutscene_end():
	"""Called when cutscene ends"""
	pass

# Core Functions
func _ready():
	# Disable camera initially
	_original_position = global_position
	
	if cutscene_camera:
		cutscene_camera.enabled = false
	
	# Setup black overlay if exists
	if black_overlay:
		black_overlay.visible = false
	
	# Call child setup
	_setup_cutscene()
	
	print(cutscene_name + ": Ready")

func _on_body_entered(body):
	# Check activation flag
	if area_activation_flag and area_activation_flag != "" and not Global.get(area_activation_flag):
		print(cutscene_name + ": Activation flag not set: " + area_activation_flag)
		return
	
	if body.is_in_group("player") and not _has_been_triggered and sequence.size() > 0:
		print(cutscene_name + ": Triggered by player")
		start_cutscene(body)

func start_cutscene(player: CharacterBody2D = null):
	if _is_cutscene_active:
		return
	
	Global.is_cutscene_active = true
	_is_cutscene_active = true
	
	# Store player reference
	_player_ref = player if player else Global.playerBody
	
	# Disable trigger
	if play_only_once:
		_has_been_triggered = true
	
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	
	# Call start callback
	_on_cutscene_start()
	cutscene_started.emit()
	
	# Start cutscene flow
	await _begin_cutscene_flow()

func _begin_cutscene_flow():
	print(cutscene_name + ": Starting cutscene flow")
	
	# Disable player input
	_disable_player_input()
	
	# Switch to cutscene camera
	await _fade_in()
	await get_tree().create_timer(0.5).timeout
	#await get_tree().create_timer(2).timeout
	_switch_to_cutscene_camera()
	#await _fade_out()
	
	# Execute sequence
	_current_step = 0
	while _current_step < sequence.size() and _is_cutscene_active:
		await _execute_step(_current_step)
		_current_step += 1
	
	# End cutscene
	await end_cutscene()

func _execute_step(step_index: int):
	if step_index >= sequence.size():
		return
	
	var step = sequence[step_index]
	var step_type = step.get("type", "")
	var step_name = step.get("name", "")
	var wait_for_completion = step.get("wait", true)
	var loop_animation = step.get("loop", false)
	
	print(cutscene_name + ": Step " + str(step_index) + ": " + step_type + " - " + step_name + " (wait: " + str(wait_for_completion) + ")")
	
	match step_type:
		"animation":
			if wait_for_completion:
				await _play_animation(step_name, true, loop_animation)
			else:
				_play_animation(step_name, false, loop_animation)  # Start but don't wait
		
		"dialog":
			await _play_dialog(step_name, wait_for_completion)
		
		"wait":
			await _wait(step.get("duration", 1.0))
		
		"move_player":
			if wait_for_completion:
				await _move_player_to_marker_with_animation(
					step.get("name", ""),
					step.get("duration", 1.0),
					step.get("animation", "run"),
					true  # Wait
				)
			else:
				_move_player_to_marker_with_animation(
					step.get("name", ""),
					step.get("duration", 1.0),
					step.get("animation", "run"),
					false  # Don't wait
				)
		
		"move_cutscene":
			# Move entire cutscene to a marker
			if wait_for_completion:
				await _move_cutscene_to_marker(
					step.get("name", ""),
					step.get("duration", 1.0),
					step.get("ease_type", Tween.EASE_IN_OUT),
					step.get("transition_type", Tween.TRANS_LINEAR)
				)
			else:
				_move_cutscene_to_marker(
					step.get("name", ""),
					step.get("duration", 1.0),
					step.get("ease_type", Tween.EASE_IN_OUT),
					step.get("transition_type", Tween.TRANS_LINEAR),
					false
				)
				
		"player_animation":
			_play_player_animation(step_name)  # This doesn't wait anyway
		
		"player_face":
			_set_player_face_direction(step.get("direction", 1))
		
		"player_form":
			await _change_player_form(step_name, step.get("unlock", false))
		
		"unlock_form":
			_unlock_player_form(step_name)
			
		"fade_in":
			if wait_for_completion:
				await _fade_in()
			else:
				# Start fade but don't wait
				_fade_in()  # This will still wait, but we'll ignore it
				# Create a small task that runs the fade
				call_deferred("_fade_in")
	
		"fade_out":
			if wait_for_completion:
				await _fade_out()
			else:
				# Start fade but don't wait
				call_deferred("_fade_out")
			
		_:
			print(cutscene_name + ": Unknown step type: " + step_type)
			
func _play_animation(anim_name: String, wait: bool, loop: bool):
	if not anim_name or not animation_player:
		return
	
	if animation_player.has_animation(anim_name):
		print(cutscene_name + ": Playing animation: " + anim_name)
		
		if loop:
			animation_player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
		
		animation_player.play(anim_name)
		
		if wait:
			await animation_player.animation_finished
	else:
		print(cutscene_name + ": Animation not found: " + anim_name)

func _play_dialog(timeline_name: String, wait: bool):
	if not timeline_name:
		return
	
	print(cutscene_name + ": Starting Dialogic: " + timeline_name)
	
	# Clear any existing dialog
	Dialogic.clear(Dialogic.ClearFlags.FULL_CLEAR)
	
	# Connect signal if not already connected
	if not Dialogic.timeline_ended.is_connected(_on_dialogic_finished):
		Dialogic.timeline_ended.connect(_on_dialogic_finished)
	
	# Start the timeline
	Dialogic.start(timeline_name, false)
	
	# Wait for completion if requested
	if wait:
		await Dialogic.timeline_ended

func _on_dialogic_finished(_arg = null):
	print(cutscene_name + ": Dialogic timeline ended")

func _wait(duration: float):
	await get_tree().create_timer(duration).timeout

func _move_player_to_marker(marker_name: String):
	#if marker_name in player_markers and _player_ref:
	#	_player_ref.global_position = player_markers[marker_name]
	#	print(cutscene_name + ": Moved player to marker: " + marker_name)
	if marker_name in player_markers and _player_ref:
		var target_position = player_markers[marker_name]
		
		# Check if player has tween movement method
		if _player_ref and _player_ref.has_method("move_player_to_position"):
			# Use tween movement
			print(cutscene_name + ": Moving player to marker: " + marker_name + " with tween")
			_player_ref.move_player_to_position(target_position, 1.0)  # 1 second duration
		else:
			# Fallback: teleport instantly
			_player_ref.global_position = target_position
			print(cutscene_name + ": Teleported player to marker: " + marker_name)

func _move_player_to_marker_tween(marker_name: String, duration: float = 1.0):
	if marker_name in player_markers and _player_ref:
		var target_position = player_markers[marker_name]
		
		print(cutscene_name + ": Moving player to marker: " + marker_name + " with " + str(duration) + "s tween")
		
		# Check if player has tween movement method
		if _player_ref.has_method("move_player_to_position"):
			# Call player's tween method
			_player_ref.move_player_to_position(target_position, duration)
			
			# Wait for tween to complete
			await get_tree().create_timer(duration).timeout
		else:
			# Fallback: instant movement
			_player_ref.global_position = target_position
		
		print(cutscene_name + ": Player reached marker: " + marker_name)

func _move_player_to_marker_with_animation(marker_name: String, duration: float = 1.0, animation_name: String = "run", wait: bool = true):
	if marker_name in player_markers and _player_ref:
		var target_position = player_markers[marker_name]
		
		print(cutscene_name + ": Moving player to marker: " + marker_name + 
			  " with animation: " + animation_name + " for " + str(duration) + "s (wait: " + str(wait) + ")")
		
		# Start walking animation
		if animation_name != "" and _player_ref.has_method("play_cutscene_animation"):
			_player_ref.play_cutscene_animation(animation_name)
		
		# Calculate direction for facing
		var direction = sign(target_position.x - _player_ref.global_position.x)
		if direction != 0 and _player_ref.has_method("set_player_face_direction"):
			_player_ref.set_player_face_direction(direction)
		
		# Move with tween
		if _player_ref.has_method("move_player_to_position"):
			_player_ref.move_player_to_position(target_position, duration)
			if wait:
				await get_tree().create_timer(duration).timeout
			else:
				# Start the timer but don't wait - create a task that runs in background
				var timer_task = get_tree().create_timer(duration)
				# We'll let it run in background
		else:
			# Instant movement
			_player_ref.global_position = target_position
			if wait:
				await get_tree().create_timer(0.1).timeout  # Small delay for instant move
		
		# Return to idle animation if waiting (or if movement completed)
		if wait and animation_name != "" and _player_ref.has_method("play_cutscene_animation"):
			_player_ref.play_cutscene_animation("idle")
		
		print(cutscene_name + ": Player movement " + ("completed" if wait else "started") + " for marker: " + marker_name)
		
func _play_player_animation(anim_name: String):
	if _player_ref and is_instance_valid(_player_ref):
		# Check if we should use AnimationTree or AnimationPlayer
		if _player_ref.has_method("play_cutscene_animation"):
			_player_ref.play_cutscene_animation(anim_name)
		elif _player_ref.has_method("play_player_visual_animation"):
			_player_ref.play_player_visual_animation(anim_name)
		print(cutscene_name + ": Playing player animation: " + anim_name)

func _set_player_face_direction(direction: int):
	if _player_ref and is_instance_valid(_player_ref):
		if _player_ref.has_method("set_player_face_direction"):
			_player_ref.set_player_face_direction(direction)
		print(cutscene_name + ": Set player face direction: " + ("right" if direction > 0 else "left"))

func _fade_in():
	if black_overlay:
		black_overlay.visible = true
		var tween = create_tween()
		tween.tween_property(black_overlay, "modulate:a", 1.0, 0.5)
		await tween.finished

func _fade_out():
	if black_overlay:
		var tween = create_tween()
		tween.tween_property(black_overlay, "modulate:a", 0.0, 0.5)
		await tween.finished
		black_overlay.visible = false


func _disable_player_input():
	Global.is_cutscene_active = true
	if _player_ref and is_instance_valid(_player_ref):
		_player_ref.disable_player_input_for_cutscene()

func _enable_player_input():
	Global.is_cutscene_active = false
	if _player_ref and is_instance_valid(_player_ref):
		_player_ref.enable_player_input_after_cutscene()

func _switch_to_cutscene_camera():
	if cutscene_camera:
		cutscene_camera.enabled = true
		cutscene_camera.make_current()

func _switch_to_player_camera():
	if cutscene_camera:
		cutscene_camera.enabled = false
		
func _change_player_form(form_name: String, unlock_first: bool = false):
	if _player_ref and is_instance_valid(_player_ref):
		print(cutscene_name + ": Changing player form to " + form_name)
		Global.is_cutscene_active = false
		_player_ref.unlock_and_force_form(form_name)
		#if unlock_first:
			# First unlock the form
		#	_unlock_player_form(form_name)
		
		# Check if player has the function
		#if _player_ref.has_method("change_player_form"):
			#_player_ref.change_player_form(form_name)
		#elif _player_ref.has_method("unlock_and_force_form"):
		#	_player_ref.unlock_and_force_form(form_name)
		#else:
			# Fallback: try to call the form switch directly
		#	if _player_ref.has_method("switch_state"):
		#		_player_ref.switch_state(form_name)
		#		print(cutscene_name + ": Used fallback to switch_state")
		
		# Also update Global
		#Global.set_player_form(form_name)
		
		# Wait a moment for the form change to complete
		await get_tree().create_timer(0.1).timeout
		Global.is_cutscene_active = true
	else:
		print(cutscene_name + ": ERROR - No player reference for form change")

# NEW: Function to just unlock a form without switching
func _unlock_player_form(form_name: String):
	if _player_ref and is_instance_valid(_player_ref):
		print(cutscene_name + ": Unlocking player form " + form_name)
		
		if _player_ref.has_method("unlock_state"):
			_player_ref.unlock_state(form_name)
		
		# Update unlocked states array
		if _player_ref.has("unlocked_states"):
			if not _player_ref.unlocked_states.has(form_name):
				_player_ref.unlocked_states.append(form_name)
				print(cutscene_name + ": Added " + form_name + " to unlocked_states")
	else:
		print(cutscene_name + ": ERROR - No player reference for unlock form")
		

func _move_cutscene_to_marker(marker_name: String, duration: float = 1.0, 
							 ease_type: int = Tween.EASE_IN_OUT, 
							 transition_type: int = Tween.TRANS_LINEAR,
							 wait: bool = true):
	"""
	Move only the cutscene camera to a marker position.
	
	Parameters:
	- marker_name: String name of the marker in cutscene_markers dictionary
	- duration: Float time in seconds for the movement
	- ease_type: Tween easing type (default: EASE_IN_OUT)
	- transition_type: Tween transition type (default: TRANS_LINEAR)
	- wait: Boolean whether to wait for movement completion
	"""
	
	if marker_name in cutscene_markers:
		var target_position = cutscene_markers[marker_name]
		
		print(cutscene_name + ": Moving cutscene camera to marker: " + marker_name + 
			  " over " + str(duration) + " seconds")
		
		# Create tween for smooth movement
		var tween = create_tween()
		tween.set_ease(ease_type)
		tween.set_trans(transition_type)
		
		# Tween only the camera's position
		if cutscene_camera:
			tween.tween_property(cutscene_camera, "global_position", target_position, duration)
		
		if wait:
			await tween.finished
			print(cutscene_name + ": Cutscene camera movement completed to: " + marker_name)
		else:
			print(cutscene_name + ": Cutscene camera movement started to: " + marker_name)
			
	elif marker_name in player_markers:
		# Fallback: use player marker if cutscene marker not found
		var target_position = player_markers[marker_name]
		
		print(cutscene_name + ": Moving cutscene camera to player marker (fallback): " + marker_name + 
			  " over " + str(duration) + " seconds")
		
		var tween = create_tween()
		tween.set_ease(ease_type)
		tween.set_trans(transition_type)
		
		# Tween only the camera's position
		if cutscene_camera:
			tween.tween_property(cutscene_camera, "global_position", target_position, duration)
		
		if wait:
			await tween.finished
	else:
		print(cutscene_name + ": ERROR - Marker not found in cutscene_markers or player_markers: " + marker_name)
		
# Optional: Add a function to instantly jump to a marker (without tween)
func _jump_cutscene_to_marker(marker_name: String):
	"""Instantly move cutscene camera to marker position"""
	if marker_name in cutscene_markers and cutscene_camera:
		cutscene_camera.global_position = cutscene_markers[marker_name]
		print(cutscene_name + ": Jumped cutscene camera to marker: " + marker_name)
	elif marker_name in player_markers and cutscene_camera:
		cutscene_camera.global_position = player_markers[marker_name]
		print(cutscene_name + ": Jumped cutscene camera to player marker: " + marker_name)
	else:
		print(cutscene_name + ": ERROR - Marker not found: " + marker_name)
		
# Optional: Reset cutscene to original position
func _reset_cutscene_position():
	"""Reset cutscene camera to its original position"""
	if cutscene_camera:
		cutscene_camera.global_position = _original_position
		print(cutscene_name + ": Reset cutscene camera to original position")
	
func end_cutscene():
	if not _is_cutscene_active:
		return
	
	print(cutscene_name + ": Ending cutscene")
	
	_is_cutscene_active = false
	Global.is_cutscene_active = false
	
	# Call end callback
	_on_cutscene_end()
	
	# Switch back to player camera
	#await _fade_in()
	_switch_to_player_camera()
	await get_tree().create_timer(0.5).timeout
	#await get_tree().create_timer(1).timeout
	await _fade_out()
	# Enable player input
	_enable_player_input()
	
	# Clean up Dialogic
	Dialogic.clear(Dialogic.ClearFlags.FULL_CLEAR)
	if Dialogic.timeline_ended.is_connected(_on_dialogic_finished):
		Dialogic.timeline_ended.disconnect(_on_dialogic_finished)
	
	# Set global flag if specified
	if global_flag_to_set and global_flag_to_set != "":
		Global.set(global_flag_to_set, true)
		print(cutscene_name + ": Set global flag: " + global_flag_to_set + " = true")
	
	# Reset player animation
	if _player_ref and is_instance_valid(_player_ref):
		_play_player_animation("idle")
	
	# Hide black overlay
	if black_overlay:
		black_overlay.visible = false
	
	# Re-enable collision if not play only once
	if not play_only_once and collision_shape:
		collision_shape.set_deferred("disabled", false)
	
	# Emit finished signal
	cutscene_finished.emit()
	
	print(cutscene_name + ": Cutscene finished")
	#queue_free()

func _exit_tree():
	# Clean up
	if Dialogic.timeline_ended.is_connected(_on_dialogic_finished):
		Dialogic.timeline_ended.disconnect(_on_dialogic_finished)
