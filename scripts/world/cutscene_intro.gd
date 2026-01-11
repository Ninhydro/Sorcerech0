extends Node2D

signal cutscene_finished

@onready var cam: Camera2D = $Camera2D
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var black_overlay: ColorRect = $BlackOverlay_code
@onready var black_overlay2: ColorRect = $BlackOverlay

# Markers for different positions
var marker_a: Marker2D
var marker_b: Marker2D
var marker_c: Marker2D

# Animation and dialog sequence data
var animation_sequence := [
	{
		"position": "a",  # Use marker_a
		"setup_anim": "",  # No setup animation for first
		"loop_anim": "anime1", 
		"dialog_timeline": "timeline1_1"
	},
	{
		"position": "b",  # Move to marker_b
		"setup_anim": "anime2_1",  # Play once first
		"loop_anim": "anime2_2",  # Then loop this
		"dialog_timeline": "timeline1_2"
	},
	{
		"position": "c",  # Move to marker_c
		"setup_anim": "anime3_1",  # Play once first
		"loop_anim": "anime3_2",  # Then loop this
		"dialog_timeline": "timeline1_3"
	},
	{
		"position": "c",  # Move to marker_c
		"setup_anim": "anime3_3",  # Play once first
		"loop_anim": "anime3_4",  # Then loop this
		"dialog_timeline": "timeline1_4"
	},
	{
		"position": "c",  # Move to marker_c
		"setup_anim": "anime3_5",  # Play once first
		"loop_anim": "",  # Then loop this
		"dialog_timeline": ""
	},
]
var current_step := 0
var is_playing_animation := false
var current_loop_anim_name := ""


func _ready():
	cam.enabled = false
	black_overlay.visible = false
	black_overlay.modulate.a = 1.0
	
	black_overlay2.visible = false

func start_cutscene():
	print("CutsceneIntro: start_cutscene")
	
	# Clear any existing dialog before starting
	Dialogic.clear(Dialogic.ClearFlags.FULL_CLEAR)
	
	# Get all marker references
	marker_a = get_parent().get_node("Marker2D_Cutscene_A")
	marker_b = get_parent().get_node("Marker2D_Cutscene_B")
	marker_c = get_parent().get_node("Marker2D_Cutscene_C")

	# Start with black screen
	black_overlay.visible = true
	black_overlay.modulate.a = 1.0
	
	# Move to initial position (marker A) while screen is black
	global_position = marker_a.global_position
	print("Moved to initial position at marker A")
	
	# Activate cutscene camera
	cam.enabled = true
	cam.make_current()
	
	await get_tree().create_timer(0.5).timeout
	
	# Start with first dialog BEFORE any animation
	_start_first_dialog()

func _start_first_dialog():
	print("Starting initial dialog: timeline1")
	
	# Hold black for 1 second before showing dialog
	#await get_tree().create_timer(1.0).timeout
	
	# Fade out to show dialog while playing
	#var tween = create_tween()
	#tween.tween_property(black_overlay, "modulate:a", 0.0, 0.5)
	
	# Connect to dialog finished signal and start dialog IMMEDIATELY
	if Dialogic.timeline_ended.is_connected(_on_first_dialog_finished):
		Dialogic.timeline_ended.disconnect(_on_first_dialog_finished)
	
	Dialogic.timeline_ended.connect(_on_first_dialog_finished)
	
	print("Starting dialog: timeline1")
	Dialogic.start("timeline1", false)

func _on_first_dialog_finished(_t = ""):
	print("First dialog finished, starting animation sequence")
	
	# Disconnect the signal
	if Dialogic.timeline_ended.is_connected(_on_first_dialog_finished):
		Dialogic.timeline_ended.disconnect(_on_first_dialog_finished)
	
	Dialogic.clear(Dialogic.ClearFlags.FULL_CLEAR)
	
	# Fade to black before starting animations
	await _fade_to_black()
	
	# Start the animation sequence
	_start_sequence()

func _fade_to_black():
	# Fade to black
	print("Fading to black")
	black_overlay.visible = true
	var tween = create_tween()
	tween.tween_property(black_overlay, "modulate:a", 1.0, 0.5)
	await tween.finished
	
	# Hold black for 1 second
	await get_tree().create_timer(0.5).timeout

func _fade_to_black_with_animation():
	# Fade to black WHILE animation keeps playing
	print("Fading to black (animation continues)")
	black_overlay.visible = true
	var tween = create_tween()
	tween.tween_property(black_overlay, "modulate:a", 1.0, 0.5)
	await tween.finished
	
	# NOW stop the animation after screen is completely black
	if anim.is_playing() and current_loop_anim_name != "":
		print("Stopping animation now that screen is black")
		anim.stop()
	
	# Hold black for 1 second
	await get_tree().create_timer(0.5).timeout
	
func _start_sequence():
	# Reset sequence
	current_step = 0
	_play_next_step()

func _play_next_step():
	if current_step >= animation_sequence.size():
		# All steps completed, return to world
		_return_to_world()
		return
	
	var step = animation_sequence[current_step]
	
	# Move to the correct position for this step
	_move_to_position(step.position)
	
	# Hold black for 1 second at new position
	await get_tree().create_timer(0.5).timeout
	
	# Now start fading in WHILE starting the animation
	_start_step_with_fade(step)

func _move_to_position(position_name: String):
	var target_position: Vector2
	
	match position_name:
		"a":
			target_position = marker_a.global_position
			print("Moving to position A")
		"b":
			target_position = marker_b.global_position
			print("Moving to position B")
		"c":
			target_position = marker_c.global_position
			print("Moving to position C")
		_:
			target_position = marker_a.global_position
	
	# Move instantly while screen is black
	global_position = target_position
	print("Arrived at position: ", position_name)

func _start_step_with_fade(step: Dictionary):
	print("Starting step ", current_step + 1, " with fade")
	
	# Start the fade out (black to clear)
	if current_step > 2:
		_play_animation_sequence(step)
	else:
		var tween = create_tween()
		tween.tween_property(black_overlay, "modulate:a", 0.0, 0.5)
	
		# Start the animation sequence IMMEDIATELY (not waiting for fade)
		_play_animation_sequence(step)
		
		# Wait for fade to complete
		await tween.finished

func _play_animation_sequence(step: Dictionary):
	print("Starting animation sequence for step ", current_step + 1)
	print("Position: ", step.position, ", Setup anim: ", step.setup_anim, ", Loop anim: ", step.loop_anim)
	
	current_loop_anim_name = ""
	
	# If there's a setup animation (plays once), play it first
	if step.setup_anim and step.setup_anim != "":
		print("Playing setup animation: ", step.setup_anim)
		anim.play(step.setup_anim)
		
		await anim.animation_finished
		print("Setup animation finished")
		if  current_step > 3:
			is_playing_animation = false
			current_step += 1
			_play_next_step()
		# Don't wait for setup animation to finish before starting loop
		# The setup animation will play, then automatically transition to loop
	
	# Start the loop animation (if no setup, this plays immediately)
	if step.loop_anim and step.loop_anim != "":
		print("Playing loop animation: ", step.loop_anim)
		# If there's a setup animation, queue the loop to play after
		#if step.setup_anim and step.setup_anim != "":
		#	anim.queue(step.loop_anim)  # Queue to play after setup
		#else:
		current_loop_anim_name = step.loop_anim
		anim.play(step.loop_anim)  # Play immediately
	
	# Start dialog while animation is playing
	if step.dialog_timeline:
		if  current_step > 3:
			is_playing_animation = false
			current_step += 1
			_play_next_step()
		else: 
			# Connect to dialog finished signal
			if Dialogic.timeline_ended.is_connected(_on_step_dialog_finished):
				Dialogic.timeline_ended.disconnect(_on_step_dialog_finished)
			
			Dialogic.timeline_ended.connect(_on_step_dialog_finished)
			
			# Start dialog IMMEDIATELY (don't wait for fade)
			print("Starting dialog: ", step.dialog_timeline)
			Dialogic.start(step.dialog_timeline, false)
	
	is_playing_animation = true

func _on_step_dialog_finished(_t = ""):
	print("Dialog finished for step: ", current_step + 1)
	
	# Disconnect the signal
	if Dialogic.timeline_ended.is_connected(_on_step_dialog_finished):
		Dialogic.timeline_ended.disconnect(_on_step_dialog_finished)
	
	Dialogic.clear(Dialogic.ClearFlags.FULL_CLEAR)
	
	# Stop the current animation
	#anim.stop()
	is_playing_animation = false
	
	# Move to next step
	current_step += 1
	print("current_step", current_step)
	if current_step > 2:
		pass
	elif current_step ==  2:
		black_overlay.visible = true
		black_overlay.modulate.a = 1.0
	else:	
		await _fade_to_black_with_animation()
	
	# Fade to black before next step
	#await _fade_to_black()
	
	# Play next step
	_play_next_step()

func _return_to_world():
	print("All animations completed, returning to world")
	
	# Fade to black (should already be black from last step)
	black_overlay.visible = true
	black_overlay.modulate.a = 1.0
	
	# Hold black for 1 second
	await get_tree().create_timer(0.5).timeout
	
	# End cutscene
	_end_cutscene()

func _end_cutscene():
	print("CutsceneIntro: _end_cutscene called")
	
	# Clean up
	cam.enabled = false
	_cleanup_dialogic_connections()
	LoadingScreen.show_and_load("")
	await get_tree().create_timer(0.5).timeout
	# Hide black overlay for smooth transition
	black_overlay.visible = false
	
	emit_signal("cutscene_finished")
	queue_free()

func _cleanup_dialogic_connections():
	# Clean up any remaining Dialogic signal connections
	if Dialogic.timeline_ended.is_connected(_on_first_dialog_finished):
		Dialogic.timeline_ended.disconnect(_on_first_dialog_finished)
	
	if Dialogic.timeline_ended.is_connected(_on_step_dialog_finished):
		Dialogic.timeline_ended.disconnect(_on_step_dialog_finished)

func _exit_tree():
	_cleanup_dialogic_connections()
