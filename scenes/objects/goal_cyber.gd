# GoalCyberArea.gd
extends Area2D

@export var required_passes: int = 2
@export var target_room: String = ""  # Set this in the inspector
@export var target_spawn: String = ""  # Set this in the inspector
var player_in_range: Player = null
var goal_completed: bool = false
@onready var transition_manager = get_node("/root/TransitionManager")

func _ready():
	connect("body_entered", Callable(self, "_on_body_entered"))
	connect("body_exited", Callable(self, "_on_body_exited"))
	
	# Check if goal was already completed
	if Global.minigame_valentina_completed:
		goal_completed = true
		disable_goal_area()
		print("DEBUG: GoalArea - Already completed, disabled")
	else:
		print("DEBUG: GoalArea ready - required_passes:", required_passes)


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
	print("Goal completed! Starting dialog...")
	Global.is_cutscene_active = true
	if Dialogic.timeline_ended.is_connected(_on_dialogic_finished):
		Dialogic.timeline_ended.disconnect(_on_dialogic_finished)
	Dialogic.timeline_ended.connect(_on_dialogic_finished)
	# Start the dialog from the goal area
	transition_manager.travel_to(player_in_range, target_room, target_spawn)
	Dialogic.start("timeline7C", false)
	
	# Optional: Disconnect the signal to prevent multiple triggers
	if player_in_range and player_in_range.area_goal_completed.is_connected(_on_player_goal_completed):
		player_in_range.area_goal_completed.disconnect(_on_player_goal_completed)

func disable_goal_area():
	# Disable collision and hide the area
	monitoring = false
	monitorable = false
	
	# Optional: Hide visual elements
	if has_node("AreaSprite"):
		$AreaSprite.visible = false
	if has_node("CollisionShape2D"):
		$CollisionShape2D.disabled = true
	
	print("DEBUG: Goal area disabled")

	
func _on_dialogic_finished(_timeline_name = ""):
	print("CutsceneManager: Dialogic timeline finished. Initiating fade out.")
	# Dialog is done. Now, fade out the black screen.

	Global.is_cutscene_active = false
	
	Dialogic.clear(Dialogic.ClearFlags.FULL_CLEAR)
	
	# Disconnect the signal to prevent unintended calls.
	if Dialogic.timeline_ended.is_connected(_on_dialogic_finished):
		Dialogic.timeline_ended.disconnect(_on_dialogic_finished)


	#player_in_range.canon_enabled = false # Exit cannon mode
	Global.timeline = 4
	Global.cyber_form = true
	#player_in_range.unlock_state("Cyber")
	await get_tree().create_timer(0.1).timeout
	player_in_range.unlock_and_force_form("Cyber")
	#Global.selected_form_index = 3
	#player_in_range.switch_state("Cyber")
	#player_in_range.current_state_index = Global.selected_form_index
	#player_in_range.combat_fsm.change_state(IdleState.new(player_in_range))
	print("Global.cyber_form ", Global.cyber_form )
	Global.remove_quest_marker("Explore Exactlyion")
	Global.minigame_valentina_completed = true
	print("Global.minigame_valentina_completed ", Global.minigame_valentina_completed)
	get_tree().get_first_node_in_group("valentina").show_instantly_at_minigame_marker()


