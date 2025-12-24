extends Node2D
class_name FallingPlatformSpawner

@export var platform_scene: PackedScene
@export var max_platforms: int = 8
@export var auto_start: bool = false

# SPAWN POINT - use a Marker2D child node
@export var spawn_point_node: NodePath
@onready var spawn_point: Marker2D = get_node_or_null(spawn_point_node)

# INDIVIDUAL SPAWNER TIMING - each spawner can have its own rate
@export var spawn_interval: float = 10.0  # Default spawn interval (seconds)
@export var interval_variation: float = 3.0  # Random variation (+/- seconds)
@export var start_delay: float = 0.0  # Initial delay before first spawn

# SPAWNER ID FOR DEBUGGING
@export var spawner_id: String = ""

# INTENSITY PHASES (OPTIONAL - kept for backward compatibility)
@export var intensity_phases: Array[Dictionary] = [
	{
		"name": "Phase 1 - Slow",
		"spawn_interval": 5.0,
		"max_platforms": 6,
		"duration": 30.0
	}
]

var spawn_timer: Timer
var intensity_timer: Timer

var platforms: Array = []
var is_active: bool = false
var spawn_count: int = 0
var current_intensity_phase: int = 0

# -------------------------------------------------
# READY
# -------------------------------------------------
func _ready() -> void:
	# Add to group so ALL spawners can be found
	add_to_group("falling_platform_spawner")
	
	# Setup timers
	_setup_timers()
	
	# Auto-find SpawnPoint if not specified
	if not spawn_point and has_node("SpawnPoint"):
		spawn_point = $SpawnPoint
		print("Spawner ", spawner_id, ": Auto-found SpawnPoint at: ", spawn_point.global_position)
	elif not spawn_point:
		# Create a default spawn point at spawner position
		spawn_point = Marker2D.new()
		spawn_point.name = "SpawnPoint"
		add_child(spawn_point)
		print("Spawner ", spawner_id, ": Created default SpawnPoint")
	
	# Set initial intensity phase if using phases
	if intensity_phases.size() > 0:
		_set_intensity_phase(0)
	
	# Start automatically if configured
	if auto_start:
		start_spawning()
	
	print("Spawner ", spawner_id, " ready at: ", spawn_point.global_position if spawn_point else "No spawn point")

func _setup_timers() -> void:
	# Create spawn timer
	spawn_timer = Timer.new()
	spawn_timer.one_shot = true  # Use one-shot for variable intervals
	spawn_timer.name = "SpawnTimer"
	add_child(spawn_timer)
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	print("Spawner ", spawner_id, ": Spawn timer created and connected")
	
	# Create intensity timer if needed
	if intensity_phases.size() > 1:
		intensity_timer = Timer.new()
		intensity_timer.one_shot = false
		intensity_timer.name = "IntensityTimer"
		add_child(intensity_timer)
		intensity_timer.timeout.connect(_on_intensity_timer_timeout)
		print("Spawner ", spawner_id, ": Intensity timer created")

# -------------------------------------------------
# INTENSITY PHASE SYSTEM (Optional)
# -------------------------------------------------
func _set_intensity_phase(phase_index: int) -> void:
	if phase_index >= intensity_phases.size():
		return
	
	current_intensity_phase = phase_index
	var phase = intensity_phases[current_intensity_phase]
	
	# Update spawn interval from phase
	spawn_interval = phase.get("spawn_interval", spawn_interval)
	
	# Update max platforms from phase
	max_platforms = phase.get("max_platforms", max_platforms)
	
	print("Spawner ", spawner_id, ": Intensity Phase - ", phase.get("name", "Unknown"),
		  " | Interval: ", spawn_interval, "s | Max platforms: ", max_platforms)
	
	# Set intensity timer for next phase if using phases
	if intensity_phases.size() > 1 and intensity_timer:
		var phase_duration = phase.get("duration", 30.0)
		intensity_timer.wait_time = phase_duration

func _on_intensity_timer_timeout() -> void:
	if intensity_phases.size() <= 1:
		return
	
	# Move to next intensity phase
	var next_phase = current_intensity_phase + 1
	if next_phase >= intensity_phases.size():
		# Loop back to phase 0
		next_phase = 0
	
	_set_intensity_phase(next_phase)
	
	# Restart intensity timer
	intensity_timer.start()

# -------------------------------------------------
# RANDOM SPAWN INTERVAL
# -------------------------------------------------
func _get_random_spawn_interval() -> float:
	# Base interval with random variation
	var base_interval = spawn_interval
	var variation = randf_range(-interval_variation, interval_variation)
	var final_interval = base_interval + variation
	
	# Clamp to reasonable values
	final_interval = clamp(final_interval, 1.0, 30.0)
	
	return final_interval

func _schedule_next_spawn() -> void:
	if not is_active:
		print("Spawner ", spawner_id, ": Not active, skipping schedule")
		return
	
	if not spawn_timer:
		print("Spawner ", spawner_id, ": ERROR - No spawn timer!")
		return
	
	var next_spawn_delay = _get_random_spawn_interval()
	spawn_timer.wait_time = next_spawn_delay
	spawn_timer.start()
	
	print("Spawner ", spawner_id, ": Scheduled next spawn in ", next_spawn_delay, " seconds")
	print("Spawner ", spawner_id, ": Timer wait_time: ", spawn_timer.wait_time)
	print("Spawner ", spawner_id, ": Timer time_left: ", spawn_timer.time_left)
	print("Spawner ", spawner_id, ": Timer is_stopped: ", spawn_timer.is_stopped())

# -------------------------------------------------
# SPAWNER CONTROL
# -------------------------------------------------
func start_spawning() -> void:
	if is_active:
		print("Spawner ", spawner_id, " already active")
		return
	
	print("=== STARTING SPAWNER ", spawner_id, " ===")
	print("Platform scene assigned: ", platform_scene != null)
	print("Spawn point: ", spawn_point.global_position if spawn_point else "None")
	print("Spawn interval: ", spawn_interval, "s ± ", interval_variation, "s")
	print("Max platforms: ", max_platforms)
	print("Start delay: ", start_delay, "s")
	print("Spawn timer exists: ", spawn_timer != null)
	
	is_active = true
	spawn_count = 0
	
	# Start intensity timer if using phases
	if intensity_phases.size() > 1 and intensity_timer:
		intensity_timer.start()
	
	# Schedule first spawn
	if start_delay > 0:
		# Wait for initial delay
		spawn_timer.wait_time = start_delay
		spawn_timer.start()
		print("Spawner ", spawner_id, ": First spawn in ", start_delay, " seconds")
	else:
		# Spawn immediately
		print("Spawner ", spawner_id, ": Spawning immediately (no start delay)")
		_spawn_platform()  # This will spawn and schedule next
	
	print("Spawner ", spawner_id, ": Started spawning")

func stop_spawning() -> void:
	is_active = false
	if spawn_timer:
		spawn_timer.stop()
	if intensity_timer:
		intensity_timer.stop()
	
	print("Spawner ", spawner_id, ": Stopped spawning")

# -------------------------------------------------
# SPAWNING LOGIC - SPAWNS EXACTLY AT MARKER2D
# -------------------------------------------------
func _spawn_platform() -> void:
	print("=== Spawner ", spawner_id, ": _spawn_platform called ===")
	
	if not is_active:
		print("Spawner ", spawner_id, ": Not active, returning")
		return
	
	if not spawn_timer:
		print("Spawner ", spawner_id, ": ERROR - No spawn timer!")
		return
	
	_cleanup_inactive_platforms()
	
	# Check max platforms
	if platforms.size() >= max_platforms:
		print("Spawner ", spawner_id, ": Max platforms reached (", platforms.size(), "/", max_platforms, ") - waiting for cleanup")
		_schedule_next_spawn()
		return
	
	if not platform_scene:
		print("Spawner ", spawner_id, ": ERROR - No platform scene assigned!")
		_schedule_next_spawn()
		return
	
	if not spawn_point:
		print("Spawner ", spawner_id, ": ERROR - No spawn point!")
		_schedule_next_spawn()
		return
	
	# Instantiate platform
	var platform = platform_scene.instantiate()
	
	# Add to scene
	var parent = get_parent()
	if not parent:
		print("Spawner ", spawner_id, ": ERROR - No parent!")
		return
	
	parent.add_child(platform)
	
	# Spawn EXACTLY at the Marker2D position
	var spawn_position = spawn_point.global_position
	
	# Activate platform
	if platform.has_method("activate_at"):
		print("Spawner ", spawner_id, ": Activating platform at ", spawn_position)
		platform.activate_at(spawn_position)
	else:
		print("Spawner ", spawner_id, ": Platform has no activate_at method, setting position manually")
		platform.global_position = spawn_position
		platform.show()
	
	# Track platform
	platforms.append(platform)
	spawn_count += 1
	
	print("Spawner ", spawner_id, ": Spawned platform #", spawn_count, " at ", spawn_position)
	print("Spawner ", spawner_id, ": Active platforms: ", platforms.size(), "/", max_platforms)
	
	# Schedule next spawn
	_schedule_next_spawn()
	print("=== Spawner ", spawner_id, ": _spawn_platform finished ===")

func _cleanup_inactive_platforms() -> void:
	var valid_platforms = []
	
	for platform in platforms:
		if is_instance_valid(platform) and platform.is_active:
			valid_platforms.append(platform)
		elif is_instance_valid(platform):
			platform.queue_free()
	
	platforms = valid_platforms

# -------------------------------------------------
# TIMER HANDLERS - FIXED
# -------------------------------------------------
func _on_spawn_timer_timeout() -> void:
	print("=== Spawner ", spawner_id, ": Spawn timer timeout! ===")
	print("Spawner ", spawner_id, ": Is active: ", is_active)
	print("Spawner ", spawner_id, ": Current time: ", Time.get_ticks_msec() / 1000.0)
	
	if is_active:
		_spawn_platform()
	else:
		print("Spawner ", spawner_id, ": Not active, ignoring timeout")

# -------------------------------------------------
# DEBUG FUNCTION - TEST TIMER
# -------------------------------------------------
func test_timer() -> void:
	"""Test if timer is working"""
	print("=== Testing timer for ", spawner_id, " ===")
	print("Timer exists: ", spawn_timer != null)
	print("Timer is_stopped: ", spawn_timer.is_stopped() if spawn_timer else "No timer")
	print("Timer wait_time: ", spawn_timer.wait_time if spawn_timer else "No timer")
	print("Timer time_left: ", spawn_timer.time_left if spawn_timer else "No timer")
	
	if spawn_timer:
		# Test with a short timer
		spawn_timer.wait_time = 1.0
		spawn_timer.start()
		print("Test timer started for 1 second")
