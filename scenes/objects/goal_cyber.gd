# GoalCyberArea.gd
extends MasterCutscene 

@export var required_passes: int = 2
@export var target_room: String = ""  # Set this in the inspector
@export var target_spawn: String = ""  # Set this in the inspector
var player_in_range: Player = null
var goal_completed: bool = false
@onready var transition_manager = get_node("/root/TransitionManager")

@onready var marker1: Marker2D = $Marker2D
@onready var marker2: Marker2D = $Marker2D

func _ready():
	super._ready()
	connect("body_entered", Callable(self, "_on_body_entered"))
	connect("body_exited", Callable(self, "_on_body_exited"))
	
	# Check if goal was already completed
	if Global.minigame_valentina_completed:
		goal_completed = true
		disable_goal_area()
		print("DEBUG: GoalArea - Already completed, disabled")
	else:
		print("DEBUG: GoalArea ready - required_passes:", required_passes)

func _setup_cutscene():
	cutscene_name = "GoalCyberCutscene"
	play_only_once = true
	area_activation_flag = ""  # No flag required
	global_flag_to_set = "minigame_valentina_completed"  # Set this global flag when finished
	
	player_markers = {
		# Example positions - adjust to match your scene
		"marker1": marker1.global_position,
		"marker2": marker2.global_position,
		#"marker2": marker2.global_position,
		#"marker3": marker3.global_position,
		#"marker4": marker4.global_position,
		#"marker5": marker5.global_position,
		#"marker6": marker6.global_position
		
	}
	
	# Setup sequence for the goal completion cutscene
	sequence = [
		{"type": "move_player", "name": "marker1", "duration": 0.5, "animation": "run", "wait": true},
		{"type": "wait", "duration": 0.5},
		{"type": "fade_out", "wait": false},
		{"type": "player_face", "direction": 1}, #1 is right, -1 is left
		{"type": "player_animation", "name": "idle", "wait": false},
		{"type": "animation", "name": "anim1", "wait": true, "loop": false},
		{"type": "animation", "name": "anim1_idle", "wait": false, "loop": true},
		{"type": "dialog", "name": "timeline7C", "wait": true},
		{"type": "move_player", "name": "marker2", "duration": 1, "animation": "shine", "wait": false},
		{"type": "animation", "name": "anim2", "wait": true, "loop": false},
		#{"type": "fade_in"},
		{"type": "animation", "name": "anim3_idle", "wait": false, "loop": true},
		{"type": "dialog", "name": "timeline7C_1", "wait": true},
		{"type": "move_player", "name": "marker1", "duration": 0.5, "animation": "jump", "wait": true},
		{"type": "fade_out", "wait": false},
		#{"type": "animation", "name": "anim3_idle", "wait": false, "loop": true},
		{"type": "player_form", "name": "Cyber", "wait": true},
		{"type": "player_animation", "name": "save",  "wait": true},
		#{"type": "wait", "duration": 0.5},
		{"type": "player_animation", "name": "load",  "wait": true},
		{"type": "wait", "duration": 0.5},
		{"type": "player_animation", "name": "idle", "wait": false},
		{"type": "dialog", "name": "timeline7C_2", "wait": true},
		
		#{"type": "animation", "name": "anim2_idle", "wait": false, "loop": true},
		#{"type": "move_player", "name": "marker1", "duration": 2, "animation": "run", "wait": true},
		#{"type": "player_animation", "name": "idle", "wait": false},
		#{"type": "dialog", "name": "timeline6M_1", "wait": true},
		{"type": "fade_in"},
		{"type": "animation", "name": "anim4", "wait": false, "loop": false},
		
	]


func _on_body_entered(body):
	if goal_completed or Global.minigame_valentina_completed:
		return
		
	if body.name == "Player" and body.has_method("track_area_pass"):
		player_in_range = body
		player_in_range.track_area_pass()
		
		# Connect to the player's goal completed signal
		if not player_in_range.area_goal_completed.is_connected(_on_player_goal_completed):
			player_in_range.area_goal_completed.connect(_on_player_goal_completed)
		
		print("Player passed through goal area at high speed!")
		
		# Visual feedback on the area itself
		if has_node("AreaSprite"):
			$AreaSprite.modulate = Color(0, 1, 0)  # Green flash
			await get_tree().create_timer(0.2).timeout
			$AreaSprite.modulate = Color(1, 1, 1)

func _on_body_exited(body):
	if body.name == "Player":
		print("Player exited goal area")

func _on_player_goal_completed():
	print("Goal completed! Starting cutscene...")
	
	# Disconnect to prevent multiple triggers
	if player_in_range and player_in_range.area_goal_completed.is_connected(_on_player_goal_completed):
		player_in_range.area_goal_completed.disconnect(_on_player_goal_completed)
	
	# Start the MasterCutscene
	start_cutscene(player_in_range)

func _on_cutscene_start():
	print("GoalCyberCutscene: Starting")
	# First, handle the room transition
	if transition_manager and target_room != "" and target_spawn != "":
		transition_manager.travel_to(player_in_range, target_room, target_spawn)
		await get_tree().create_timer(0.5).timeout  # Wait for transition
	
	# Store player reference
	if player_in_range:
		_player_ref = player_in_range
		print("Cutscene1: Player reference stored: ", player_in_range.name)

# Override the end cutscene callback
func _on_cutscene_end():
	print("GoalCyberCutscene: Finished")
	
	# Apply all the rewards and state changes
	Global.timeline = 4
	Global.cyber_form = true
	
	# Health increase
	player_in_range.unlock_and_force_form("Cyber")
	Global.health_max += 10
	Global.health = Global.health_max
	if Global.player and Global.player.has_signal("health_changed"):
		Global.player.health_changed.emit(Global.health, Global.health_max)
	
	# Quest marker
	Global.remove_quest_marker("Explore Exactlyion")
	Global.minigame_valentina_completed = true
	
	# Update Valentina
	var valentina = get_tree().get_first_node_in_group("valentina")
	if valentina and valentina.has_method("show_instantly_at_minigame_marker"):
		valentina.show_instantly_at_minigame_marker()
	
	# Disable the goal area
	disable_goal_area()
	
	print("DEBUG: Global.minigame_valentina_completed = ", Global.minigame_valentina_completed)
	
func disable_goal_area():
	# Disable collision and hide the area
	monitoring = false
	monitorable = false
	
	goal_completed = true
	
	# Disable collision and hide the area
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
		
	
	# Optional: Hide visual elements
	if has_node("AreaSprite"):
		$AreaSprite.visible = false
	if has_node("CollisionShape2D"):
		$CollisionShape2D.disabled = true
	
	print("DEBUG: Goal area disabled")

	
#func _on_dialogic_finished(_timeline_name = ""):
#	print("CutsceneManager: Dialogic timeline finished. Initiating fade out.")
	# Dialog is done. Now, fade out the black screen.

#	Global.is_cutscene_active = false
	
#	Dialogic.clear(Dialogic.ClearFlags.FULL_CLEAR)
	
	# Disconnect the signal to prevent unintended calls.
#	if Dialogic.timeline_ended.is_connected(_on_dialogic_finished):
#		Dialogic.timeline_ended.disconnect(_on_dialogic_finished)


	#player_in_range.canon_enabled = false # Exit cannon mode
#	Global.timeline = 4
#	Global.cyber_form = true
	#player_in_range.unlock_state("Cyber")
#	await get_tree().create_timer(0.1).timeout
#	player_in_range.unlock_and_force_form("Cyber")
	
#	Global.health_max += 10
#	Global.health = Global.health_max
#	Global.player.health_changed.emit(Global.health, Global.health_max)
	
	#Global.selected_form_index = 3
	#player_in_range.switch_state("Cyber")
	#player_in_range.current_state_index = Global.selected_form_index
	#player_in_range.combat_fsm.change_state(IdleState.new(player_in_range))
#	print("Global.cyber_form ", Global.cyber_form )
#	Global.remove_quest_marker("Explore Exactlyion")
#	Global.minigame_valentina_completed = true
#	print("Global.minigame_valentina_completed ", Global.minigame_valentina_completed)
#	get_tree().get_first_node_in_group("valentina").show_instantly_at_minigame_marker()


