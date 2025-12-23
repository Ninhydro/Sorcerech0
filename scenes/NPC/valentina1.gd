# ValentinaNPC.gd
extends CharacterBody2D

@onready var sprite = $Sprite2D
@onready var animation_player = $AnimationPlayer

var is_visible: bool = false
var current_timeline: String = ""

@export var marker_minigame: Marker2D
@export var marker_timeline_5: Marker2D
var is_moving: bool = false

@export var walk_speed: float = 60.0 * Global.global_time_scale # Pixels per second
@export var use_speed_based_movement: bool = true  # Toggle between speed-based and d
@export var show_instantly_flag: bool = false

func _ready():
	# Start invisible
	visible = false
	#collision_layer = 0
	#collision_mask = 0
	
	# DEBUG
	#print("Valentina DEBUG: minigame_valentina_completed = ", Global.minigame_valentina_completed)
	#print("Valentina DEBUG: timeline = ", Global.timeline)
	#print("Valentina DEBUG: show_instantly_flag = ", show_instantly_flag)
	
	# INSTANT SHOW IF FLAG IS SET
	if show_instantly_flag:
		show_instantly_at_minigame_marker()
		return
	
	# Normal behavior
	setup_global_connections()
	check_visibility_conditions()



		
func setup_global_connections():

	check_globals_periodically()
func show_instantly():
	"""Show Valentina immediately without movement"""
	#print("Valentina: Showing instantly!")
	is_visible = true
	visible = true
	#collision_layer = 1
	#collision_mask = 1
	sprite.modulate.a = 1.0
	
	# Stop any ongoing movement
	is_moving = false
	animation_player.stop()
	play_idle_animation()

func show_instantly_at_marker(marker: Marker2D):
	"""Show Valentina instantly at a specific marker position"""
	if marker:
		global_position = marker.global_position
		#print("Valentina: Teleported to marker at ", marker.global_position)
	show_instantly()

func show_instantly_at_minigame_marker():
	"""Show Valentina instantly at the minigame marker"""
	if marker_minigame:
		show_instantly_at_marker(marker_minigame)
	else:
		show_instantly()

func show_instantly_at_timeline5_marker():
	"""Show Valentina instantly at the timeline 5 marker"""
	if marker_timeline_5:
		show_instantly_at_marker(marker_timeline_5)
	else:
		show_instantly()
		
func check_globals_periodically():
	# Create a timer to check global values every second
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = 1.0
	timer.timeout.connect(_on_global_check_timer_timeout)
	timer.start()

func _on_global_check_timer_timeout():
	# Check if global values have changed
	check_visibility_conditions()

func _process(_delta):
	# Only process if visible
	if not is_visible:
		return
	
	# Handle any ongoing animations or behaviors
	if $AnimationPlayer:
		$AnimationPlayer.speed_scale = Global.global_time_scale

func check_visibility_conditions():

	
	# 1) Later timeline state should override earlier minigame state
	if Global.timeline >= 5:
		show_valentina_at_timeline_5()
	
	# 2) If minigame is done but story not that far yet, use minigame position
	elif Global.minigame_valentina_completed:
		show_valentina()
	else:
		#print("Valentina: No conditions met, hiding")
		hide_valentina()

func show_valentina():
	#if is_visible:
	#	print("Valentina: Already visible, skipping")
	#	return
	
	#print("Valentina: Showing after minigame completion")
	is_visible = true
	visible = true
	#collision_layer = 1
	#collision_mask = 1
	
	# Default behavior if no animation
	sprite.modulate.a = 1.0
	
	# Set initial timeline
	current_timeline = "after_minigame"
	
	# Move to appropriate position
	move_to_appropriate_position()

func show_valentina_at_timeline_5():
	#if is_visible:
	#	print("Valentina: Already visible, skipping")
	#	return
	
	#print("Valentina: Showing at timeline 5")
	is_visible = true
	visible = true
	#collision_layer = 1
	#collision_mask = 1
	
	# Set timeline 5 behavior and move to position
	current_timeline = "timeline_5"
	move_to_appropriate_position()

func move_to_appropriate_position():
	#print("Valentina: Moving to appropriate position for timeline: ", current_timeline)
	
	# Move to appropriate position based on current timeline
	if current_timeline == "after_minigame":
		if marker_minigame:
			#print("Valentina: Using exported marker_minigame")
			move_to_marker(marker_minigame)
		else:
			#print("Valentina: No minigame marker found")
			play_idle_animation()
			
	elif current_timeline == "timeline_5":
		if marker_timeline_5:
			#print("Valentina: Using exported marker_timeline_5")
			move_to_marker(marker_timeline_5)
		else:
			#print("Valentina: No timeline 5 marker found")
			play_idle_animation()

func move_to_marker(marker: Marker2D, duration: float = 2.0):
	if not marker:
		#print("Valentina: No marker found, staying in place")
		play_idle_animation()
		return
	
	#print("Valentina: Moving to marker at position ", marker.global_position)
	is_moving = true
	
	# Play walk animation
	play_walk_animation()
	
	# Calculate direction for sprite flipping
	var direction = marker.global_position.x - global_position.x
	if direction < 0:
		sprite.flip_h = true  # Face left
	else:
		sprite.flip_h = false  # Face right
	
	var distance = global_position.distance_to(marker.global_position)
	var calculated_duration = distance / walk_speed
	
	# Create tween for smooth movement
	var tween = create_tween()
	tween.tween_property(self, "global_position", marker.global_position, calculated_duration)
	tween.tween_callback(_on_movement_finished)
	
func hide_valentina():
	if not is_visible:
		return
	
	#print("Valentina: Hiding")
	is_visible = false
	visible = false
	#collision_layer = 0
	#collision_mask = 0
	is_moving = false

func _on_movement_finished():
	#print("Valentina: Finished moving")
	is_moving = false
	play_idle_animation()

func play_walk_animation():
	if animation_player.has_animation("walk"):
		animation_player.play("walk")
		#print("Valentina: Playing walk animation")
	else:
		#print("Valentina: No walk animation found, playing idle instead")
		play_idle_animation()
		
func play_idle_animation():
	if animation_player.has_animation("idle"):
		animation_player.play("idle")
		#print("Valentina: Playing idle animation")

		#print("Valentina: No idle animation found")

# Manual refresh function - call this if globals change elsewhere
func refresh_visibility():
	#print("Valentina: Manual refresh called")
	check_visibility_conditions()
