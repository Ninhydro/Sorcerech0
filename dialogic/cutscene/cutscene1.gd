extends MasterCutscene

var player_in_range = null
@onready var transition_manager = get_node("/root/TransitionManager")
var target_room1 = "Room_AerendaleJunkyard"
var target_spawn1 = "Spawn_Minigame"

#func _ready():
	# Don't call super._ready() - MasterCutscene already handles this
#	pass

func _on_body_entered(body):
	print("Cutscene1: Body entered - ", body.name if body else "null")
	
	# Check if timeline condition is met
	if Global.timeline == 1 and body.is_in_group("player"):
		print("Cutscene1: Conditions met, calling parent method")
		# Store player reference first
		player_in_range = body
		# Call parent's _on_body_entered
		super._on_body_entered(body)
	else:
		print("Cutscene1: Conditions not met. Global.timeline = ", Global.timeline, ", is_player = ", body.is_in_group("player") if body else "false")

func _setup_cutscene():
	cutscene_name = "Cutscene1"
	play_only_once = true
	area_activation_flag = ""  # No flag required
	global_flag_to_set = ""  # We'll handle this manually
	
	# IMPORTANT: Make sure your scene has these Marker2D nodes or set positions manually
	player_markers = {
		# Example positions - adjust to match your scene
		#"start": Vector2(100, 200),
		#"center": Vector2(300, 200),
		#"end": Vector2(500, 200)
	}
	
	# Simple sequence: just play dialog
	sequence = [
		{"type": "dialog", "name": "timeline2", "wait": true},
		#{"type": "fade_in"},
		
		#{"type": "fade_out"}
	]

func _on_cutscene_start():
	print("Cutscene1: Starting")
	# Player reference is already stored in _player_ref by parent class
	if _player_ref:
		player_in_range = _player_ref
		print("Cutscene1: Player reference stored: ", player_in_range.name)

func _on_cutscene_end():
	print("Cutscene1: Finished")
	
	# Set timeline
	Global.timeline = 2
	print("Cutscene1: Set Global.timeline = ", Global.timeline)

	# Travel to minigame room (optional - uncomment if needed)
	#if player_in_range and transition_manager:
	#	print("Cutscene1: Traveling to minigame room")
	#	transition_manager.travel_to(player_in_range, target_room1, target_spawn1)
	
	# Start minigame (optional - uncomment if needed)
	#var minigame = get_tree().get_first_node_in_group("sorting_minigame")
	#if minigame:
	#	print("Cutscene1: Starting minigame")
	#	minigame.start_game()

"""
# Complete sequence example
	sequence = [
		# Start with fade in
		{"type": "fade_in"},
		
		# Move player to start position while screen is black
		{"type": "move_player", "name": "start_pos"},
		
		# Wait a moment
		{"type": "wait", "duration": 0.5},
		
		# Fade out to show scene
		{"type": "fade_out"},
		
		# Player looks around
		{"type": "player_face", "direction": 1},
		{"type": "wait", "duration": 0.5},
		{"type": "player_face", "direction": -1},
		{"type": "wait", "duration": 0.5},
		
		# Play cutscene animation
		{"type": "animation", "name": "intro_anim", "wait": true},
		
		# First dialog
		{"type": "dialog", "name": "greeting_timeline", "wait": true},
		
		# Player walks to middle while animation plays
		{"type": "move_player", "name": "middle_pos"},
		{"type": "player_animation", "name": "run"},
		{"type": "wait", "duration": 1.0},
		
		# Second dialog
		{"type": "dialog", "name": "conversation_timeline", "wait": true},
		
		# Play loop animation with dialog overlay
		{"type": "animation", "name": "idle_loop", "wait": false, "loop": true},
		{"type": "dialog", "name": "action_timeline", "wait": true},
		
		# Final animation
		{"type": "animation", "name": "ending_anim", "wait": true},
		
		# Move to end position
		{"type": "move_player", "name": "end_pos"},
		
		# Final dialog
		{"type": "dialog", "name": "farewell_timeline", "wait": true},
		
		# Fade out and end
		{"type": "fade_in"}
	]
"""
