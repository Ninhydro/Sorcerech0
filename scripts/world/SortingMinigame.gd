# SortingMinigame.gd
extends Node2D

@export var object_scenes: Array[PackedScene] = []
@export var game_time: float = 120.0  # 2 minutes
@export var total_objects: int = 20

@onready var spawn_point: Marker2D = $SpawnPoint
@onready var timer_label: Label = $UI/TimerLabel
@onready var objects_label: Label = $UI/ObjectsSortedLabel
@onready var ColorRect1: ColorRect = $UI/ColorRect
#@onready var game_over_screen: Panel = $UI/GameOverScreen

var current_time: float = 0.0
var objects_sorted: int = 0
var objects_spawned: int = 0
var game_active: bool = false
var correct_bins: Dictionary = {
	"cyber": "CyberBin",
	"magus": "MagusBin"
}

var max_objects_on_screen: int = 3
var objects_to_spawn: int = 40  # Spawn 50 total
var required_to_win: int = 20   # Only need 20 to win


var win = false

func _ready():
	#start_game()
	timer_label.visible = false
	objects_label.visible = false
	ColorRect1.visible = false
	add_to_group("sorting_minigame")

	# Dialogic.start('minigame_start_dialog')
	# await Dialogic.timeline_ended
	setup_bin_connections()

func setup_bin_connections():
	for bin in $Bins.get_children():
		if bin.has_signal("object_dropped"):
			# Disconnect first to avoid duplicates, then connect
			if bin.object_dropped.is_connected(_on_object_dropped):
				bin.object_dropped.disconnect(_on_object_dropped)
			bin.object_dropped.connect(_on_object_dropped)


func start_game():
	timer_label.visible = true
	objects_label.visible = true
	ColorRect1.visible = true
	current_time = game_time
	objects_sorted = 0
	objects_spawned = 0
	game_active = true
	#game_over_screen.visible = false
	update_ui()
	
	# Start spawning objects
	spawn_next_object()

func _process(delta):
	if not game_active:
		return
		
	current_time -= delta
	update_ui()
	
	if current_time <= 0:
		end_game(false)
	elif objects_sorted >= required_to_win:
		end_game(true)

func update_ui():
	var minutes = floor(current_time / 60)
	var seconds = int(current_time) % 60
	timer_label.text = "Time: %02d:%02d" % [minutes, seconds]
	objects_label.text = "        Sorted: %d/%d" % [objects_sorted, required_to_win]

func spawn_next_object():
	if objects_spawned >= objects_to_spawn or not game_active:
		return
	
	var current_objects = get_tree().get_nodes_in_group("FallingObjects")
	if current_objects.size() >= max_objects_on_screen:
		# Wait and try again later
		await get_tree().create_timer(0.5).timeout
		spawn_next_object()
		return
		
	# Random delay between spawns (0.5 to 2 seconds)
	var spawn_delay = randf_range(2.0, 4.0)
	await get_tree().create_timer(spawn_delay).timeout
	
	if not game_active:
		return
	
	var object_scene = preload("res://scenes/objects/Fallingobject.tscn")
	var new_object = object_scene.instantiate()
	add_child(new_object)
	
	# Spawn random object
	var available_types = ["cyber", "magus"]
	var random_type = available_types[randi() % available_types.size()]
	new_object.setup_object(random_type)
	#print("DEBUG: Setting object type to: '", random_type, "'")
	new_object.global_position = spawn_point.global_position
	new_object.contact_monitor = true
	new_object.max_contacts_reported = 10
	
	new_object.apply_impulse(Vector2(0, 50))
	
	objects_spawned += 1
	
	# Setup bin detection
	#for bin in $Bins.get_children():
	#	bin.connect("object_dropped", _on_object_dropped.bind(new_object))
	
	# Spawn next object after a delay
	if objects_spawned < objects_to_spawn :
		spawn_next_object()

func _on_object_dropped(bin_name: String, object: RigidBody2D):
	if not game_active:
		print("DEBUG: Game not active, ignoring drop")
		return
		
	if not is_instance_valid(object):
		print("DEBUG: Object invalid, ignoring drop")
		return
	
	var object_type = object.object_type
	var correct_bin = correct_bins[object_type]
	
	if bin_name == correct_bin:
		objects_sorted += 1
		# Success effects
		object.queue_free()
	else:
		# Wrong bin - maybe penalty or just remove object
		object.queue_free()
	
	update_ui()



func end_game(victory: bool):
	game_active = false
	
	#game_over_screen.visible = true
   # var result_label = game_over_screen.get_node("ResultLabel")
	#var restart_button = game_over_screen.get_node("RestartButton")
	
	for child in get_children():
		if child is RigidBody2D and child.has_method("push"):
			child.queue_free()
	
	print("MINIGAME: Game ended. Victory: ", victory)
	
	if victory:
		show_win_dialog()
		win = true
		print("WIN")

	else:
		print("LOSE, reset minigame")
		show_lose_dialog()
		win = false
		#get_tree().reload_current_scene()
		#result_label.text = "Game Over! Time's up!"
	
	#restart_button.connect("pressed", _on_restart_pressed)

func show_win_dialog():

	print("MINIGAME WIN DIALOG: Time remaining: ", current_time, " seconds")
	timer_label.visible = false
	objects_label.visible = false
	ColorRect1.visible = false
	
	Global.is_cutscene_active = true
		#Global.cutscene_name = cutscene_animation_name
		#Global.cutscene_playback_position = start_position
		#Dialogic.start("timeline1", false)
	if Dialogic.timeline_ended.is_connected(_on_dialogic_finished):
		Dialogic.timeline_ended.disconnect(_on_dialogic_finished)
	Dialogic.timeline_ended.connect(_on_dialogic_finished)


	Dialogic.start("timeline3W", false)


func show_lose_dialog():

	print("MINIGAME LOSE DIALOG: Objects sorted: ", objects_sorted, "/", total_objects)
	print("MINIGAME LOSE DIALOG: Would you like to try again?")
	
	Global.is_cutscene_active = true

	if Dialogic.timeline_ended.is_connected(_on_dialogic_finished):
		Dialogic.timeline_ended.disconnect(_on_dialogic_finished)
	Dialogic.timeline_ended.connect(_on_dialogic_finished)


	Dialogic.start("timeline3L", false)

	



func reset_minigame():
	print("Resetting minigame...")
	
	# Clear all existing objects
	for child in get_children():
		if child is RigidBody2D and child.has_method("push"):
			child.queue_free()
	
	# Reset variables
	game_active = false
	objects_sorted = 0
	objects_spawned = 0
	current_time = game_time
	win = false
	
	# Clear any pending timers or coroutines
	set_process(false)
	
	# Wait a frame for cleanup
	await get_tree().process_frame
	
	# Restart
	print("Restarting minigame...")
	start_game()
	set_process(true)

	


func _on_dialogic_finished(_timeline_name = ""):
	print("CutsceneManager: Dialogic timeline finished. Initiating fade out.")
	# Dialog is done. Now, fade out the black screen.

	Global.is_cutscene_active = false
	
	Dialogic.clear(Dialogic.ClearFlags.FULL_CLEAR)
	
	# Disconnect the signal to prevent unintended calls.
	if Dialogic.timeline_ended.is_connected(_on_dialogic_finished):
		Dialogic.timeline_ended.disconnect(_on_dialogic_finished)

	if win:
		Global.timeline = 3
		#result_label.text = "You Win! Sorted all objects in time!"
	else:
		await get_tree().create_timer(1.0).timeout
		reset_minigame()

	#Global.timeline = 2.5
