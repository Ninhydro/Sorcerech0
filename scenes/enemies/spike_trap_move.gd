extends Area2D
class_name SpikeTrapMove

@export var damage_percentage: float = 5.0

const TEX_EXACTLYION := preload("res://assets_image/Objects/SpikeStrip1.png")
const TEX_DEFAULT    := preload("res://assets_image/Objects/SpikeStrip2.png")

@onready var sprite: Sprite2D = $Sprite2D
@onready var detection_area: Area2D = $DetectionArea
@onready var animation_player: AnimationPlayer = $AnimationPlayer if has_node("AnimationPlayer") else null

@export var use_exactlyion_style: bool = false

# --- MOVEMENT SETTINGS ---
@export var up_distance: float = 16.0          # How far up the spikes rise (pixels)
@export var move_speed: float = 80.0           # Base speed (pixels/sec)
@export var wait_at_top: float = 0.3           # Base time to stay up (seconds)
@export var wait_at_bottom: float = 0.3        # Base time to stay down (seconds)
@export var require_player_near: bool = true   # Only move when player nearby

# --- INTERNAL STATE ---
var base_position: Vector2
var player_nearby: bool = false
var is_dangerous: bool = false

enum State { IDLE_DOWN, MOVING_UP, WAITING_UP, MOVING_DOWN, WAITING_DOWN, DISABLED }
var current_state: State = State.IDLE_DOWN
var state_timer: float = 0.0


func _ready() -> void:
	#add_to_group("spikes")
	sprite.texture = TEX_EXACTLYION if use_exactlyion_style else TEX_DEFAULT
	
	# Store starting position as the "down" position
	base_position = global_position
	
	# Start fully down & safe
	global_position = base_position
	is_dangerous = false
	monitoring = false  # No damage while down
	
	# Damage trigger
	body_entered.connect(_on_body_entered)
	
	# Player-nearby detection
	if detection_area:
		detection_area.body_entered.connect(_on_detection_body_entered)
		detection_area.body_exited.connect(_on_detection_body_exited)


func _physics_process(delta: float) -> void:
	# --- TIME SCALE SETUP ---
	var ts := Global.global_time_scale
	if ts < 0.0:
		ts = 0.0   # prevent weird negatives
	var scaled_delta := delta * ts
	
	# Optional animation slow-down
	if animation_player:
		animation_player.speed_scale = ts
	
	# --- CAMOUFLAGE OVERRIDE ---
	# When camouflage is active, force trap down and harmless (regardless of time scale).
	if Global.camouflage:
		if current_state != State.DISABLED:
			_force_disable_trap()
		return
	else:
		if current_state == State.DISABLED:
			# Camouflage just turned off, reset to bottom idle
			_enable_trap()
	
	# --- NORMAL BEHAVIOUR ---
	if require_player_near and not player_nearby:
		# No player nearby: stay down and safe
		current_state = State.IDLE_DOWN
		is_dangerous = false
		monitoring = false
		global_position = base_position
		return
	
	match current_state:
		State.IDLE_DOWN:
			is_dangerous = false
			monitoring = false
			global_position = base_position
			# Start cycle if player nearby (or always if not required)
			current_state = State.MOVING_UP
		
		State.MOVING_UP:
			var target_y = base_position.y - up_distance
			# Movement slowed by global time scale
			var new_y = move_toward(global_position.y, target_y, move_speed * scaled_delta)
			global_position.y = new_y
			
			if is_equal_approx(new_y, target_y):
				# Reached top
				is_dangerous = true
				monitoring = true      # Now it can hurt
				current_state = State.WAITING_UP
				state_timer = wait_at_top
		
		State.WAITING_UP:
			# Timer is slowed by global time scale
			state_timer -= scaled_delta
			if state_timer <= 0.0:
				current_state = State.MOVING_DOWN
		
		State.MOVING_DOWN:
			var target_y = base_position.y
			var new_y = move_toward(global_position.y, target_y, move_speed * scaled_delta)
			global_position.y = new_y
			
			if is_equal_approx(new_y, target_y):
				is_dangerous = false
				monitoring = false
				current_state = State.WAITING_DOWN
				state_timer = wait_at_bottom
		
		State.WAITING_DOWN:
			state_timer -= scaled_delta
			if state_timer <= 0.0:
				if require_player_near and not player_nearby:
					current_state = State.IDLE_DOWN
				else:
					current_state = State.MOVING_UP
		
		State.DISABLED:

			pass


func _force_disable_trap() -> void:
	current_state = State.DISABLED
	is_dangerous = false
	monitoring = false            # Area2D won't damage or trigger hitbox
	global_position = base_position
	# Optional: visual feedback
	# sprite.modulate = Color(1, 1, 1, 0.5)


func _enable_trap() -> void:
	# Back to initial state after camouflage ends
	current_state = State.IDLE_DOWN
	is_dangerous = false
	monitoring = false
	global_position = base_position
	# sprite.modulate = Color(1, 1, 1, 1)


func _on_detection_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_nearby = true


func _on_detection_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_nearby = false


func _on_body_entered(body: Node2D) -> void:
	# Only hurt when spikes are actually up and dangerous
	# Only hurt when spikes are actually up and dangerous
	if not is_dangerous:
		return
	
	if body is Player and body.can_take_damage and not body.dead:
		print("MovingSpike: Player hit!")
		
		# % HP damage, same style as old spikes but NO respawn.
		var spike_damage_float := (damage_percentage / 100.0) * Global.health_max
		var spike_damage := int(max(1.0, spike_damage_float))
		
		# Give a knockback direction away from the spike
		var knock_dir = (body.global_position - global_position).normalized()
		if knock_dir == Vector2.ZERO:
			knock_dir = Vector2.UP
		Global.enemyAknockback = knock_dir * 200.0  # tweak force
		
		body.take_damage(spike_damage)
