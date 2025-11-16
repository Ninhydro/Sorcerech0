extends CharacterBody2D
class_name CanonLaserEnemy

@onready var canon_bot_sprite := $CanonBotSprite
@onready var canon_arm_sprite := $ArmPivot/CanonArmSprite
@onready var laser_sprite := $LaserSprite
@onready var detection_area := $DetectionArea
@onready var bot_animation_player := $BotAnimationPlayer
@onready var arm_animation_player := $ArmAnimationPlayer
@onready var tracking_timer := $TrackingTimer

# Marker2D nodes for precise positioning
@onready var arm_pivot := $ArmPivot  # Where the arm rotates from
@onready var canon_tip := $ArmPivot/CanonArmSprite/CanonTip  # Where laser comes from

@export var tracking_duration := 3.0  # Time to track before shooting
@export var rotation_offset_degrees: float = 40
@export var laser_rotation_offset_degrees: float = -40  # ADD THIS

var player: Node2D = null
var is_tracking := false
var is_shooting := false
var tracking_time := 0.0

func _ready():
	# Connect detection area signals
	detection_area.body_entered.connect(_on_detection_area_body_entered)
	detection_area.body_exited.connect(_on_detection_area_body_exited)
	
	# Set up timer
	tracking_timer.wait_time = tracking_duration
	tracking_timer.one_shot = true
	tracking_timer.timeout.connect(_on_tracking_timeout)
	
	# Start with idle state
	set_idle_state()
	
	# Debug: Print initial positions
	print("=== CANON ENEMY SETUP ===")
	print("Arm Pivot Position: ", arm_pivot.position)
	print("Canon Arm Position: ", canon_arm_sprite.position)
	print("Canon Tip Position: ", canon_tip.position)

func _process(delta):
	# Continuous camouflage check - works even when player is already in area
	if player and Global.playerAlive and not Global.camouflage:
		# Player is visible and in range - should be tracking
		if detection_area.overlaps_body(player) and not is_tracking and not is_shooting:
			start_tracking()
		elif not detection_area.overlaps_body(player) and is_tracking:
			stop_tracking()
	elif is_tracking and Global.camouflage:  # Player became camouflaged while tracking
		stop_tracking()
	
	if is_tracking and not is_shooting and player and Global.playerAlive:
		# Rotate arm to face player using the pivot point
		rotate_arm_towards_player()
		
		# Update tracking time for visual feedback
		tracking_time += delta

func rotate_arm_towards_player():
	if not player:
		return
	
	# Get global positions for debugging
	var pivot_global = arm_pivot.global_position
	var player_global = player.global_position
	var arm_global = canon_arm_sprite.global_position
	
	# Calculate direction from arm pivot to player
	var direction_to_player = (player_global - pivot_global).normalized()
	
	# Calculate target angle
	var target_angle = direction_to_player.angle()
	target_angle += deg_to_rad(rotation_offset_degrees)
	# Debug: Print rotation info
	print("Pivot: ", pivot_global, " Player: ", player_global, " Direction: ", direction_to_player, " Target Angle: ", rad_to_deg(target_angle))
	
	# Smoothly rotate the arm pivot
	arm_pivot.rotation = lerp_angle(arm_pivot.rotation, target_angle, get_process_delta_time() * 5.0)
	
func set_idle_state():
	is_tracking = false
	is_shooting = false
	tracking_time = 0.0
	tracking_timer.stop()
	
	# Play idle animations
	bot_animation_player.play("idle")
	
	# Hide arm and laser in idle state
	arm_pivot.visible = false
	laser_sprite.visible = false

func set_tracking_state():
	is_tracking = true
	is_shooting = false
	
	# Play tracking animations
	bot_animation_player.play("tracking")  # Red eyes animation
	arm_pivot.visible = true               # Show the arm
	arm_animation_player.play("tracking")  # Canon arm tracking animation
	
	# Hide laser during tracking
	laser_sprite.visible = false
	
	# Start tracking timer
	tracking_timer.start(tracking_duration)

func set_shooting_state():
	is_tracking = false
	is_shooting = true
	
	# Keep bot in tracking state (red eyes)
	bot_animation_player.play("tracking")
	arm_pivot.visible = true
	
	# Play shooting animation on canon arm
	arm_animation_player.play("shooting")
	
	# Show and position laser
	show_laser_to_player()
func show_laser_to_player():
	if not player or not canon_tip:
		return
	
	# Make laser visible
	laser_sprite.visible = true
	
	# Get canon tip position
	var canon_tip_pos = canon_tip.global_position
	
	# Calculate laser direction from the arm's current rotation
	var laser_direction = Vector2.RIGHT.rotated(arm_pivot.rotation)
	
	# DEBUG: Print current rotation and direction
	print("Arm rotation: ", rad_to_deg(arm_pivot.rotation), " Laser direction: ", laser_direction)
	
	# Method 1: Simple fixed distance laser
	var laser_distance = 2000.0  # Very long distance
	var laser_end_pos = canon_tip_pos + (laser_direction * laser_distance)
	
	# Position the laser sprite correctly
	laser_sprite.global_position = canon_tip_pos
	
	# APPLY LASER ROTATION OFFSET HERE
	var laser_rotation = arm_pivot.rotation + deg_to_rad(laser_rotation_offset_degrees)
	laser_sprite.rotation = laser_rotation
	
	# Calculate scale based on distance
	var laser_texture = laser_sprite.texture
	if laser_texture:
		var laser_width = laser_texture.get_width()
		if laser_width > 0:
			laser_sprite.scale.x = laser_distance / laser_width
			laser_sprite.scale.y = 1.0
		else:
			laser_sprite.scale.x = laser_distance / 100.0  # Fallback
			laser_sprite.scale.y = 1.0
	else:
		# No texture, use default scaling
		laser_sprite.scale.x = laser_distance / 100.0
		laser_sprite.scale.y = 1.0
	
	# DEBUG: Print laser info
	print("Laser start: ", canon_tip_pos, " Laser rotation: ", rad_to_deg(laser_rotation), " With offset: ", laser_rotation_offset_degrees)
	
func _on_detection_area_body_entered(body):
	if body is Player and Global.playerAlive and not Global.camouflage:
		player = body
		start_tracking()

func _on_detection_area_body_exited(body):
	if body == player:
		stop_tracking()

func start_tracking():
	if is_tracking or Global.camouflage:
		return
	
	print("Canon Laser Enemy: Player detected, starting tracking")
	set_tracking_state()

func stop_tracking():
	if not is_tracking and not is_shooting:
		return
	
	print("Canon Laser Enemy: Stopping tracking")
	set_idle_state()

func _on_tracking_timeout():
	if is_tracking and player and Global.playerAlive and not Global.camouflage:
		print("Canon Laser Enemy: Tracking complete, FIRING LASER!")
		shoot_laser()

func shoot_laser():
	set_shooting_state()
	
	# Instant death for player
	if player and Global.playerAlive:
		Global.health = 0
		player.handle_death()
		print("Canon Laser Enemy: Player eliminated!")
	
	# Wait for shooting animation to complete, then reset
	await get_tree().create_timer(1.5).timeout  # Adjust based on your shooting animation length
	set_idle_state()
