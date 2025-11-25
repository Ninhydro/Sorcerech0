extends Area2D

var _has_been_triggered: bool = false
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@export var play_only_once: bool = true

var player_in_range: Node = null

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var cutscene_camera: Camera2D = $CutsceneCamera2D

# Travel data
@export var target_room: String = "Room_AerendaleJunkyard"
@export var target_spawn: String = "Spawn_ToMaya"

@onready var transition_manager: Node = get_node("/root/TransitionManager")


func _ready() -> void:
	pass


func _process(delta: float) -> void:
	# Only active when timeline == 5.3
	if Global.timeline == 5.3:
		collision_shape.disabled = false
	else:
		collision_shape.disabled = true


func _mark_triggered() -> void:
	# Helper so both body_entered & manual start behave the same
	if _has_been_triggered:
		return
	
	_has_been_triggered = true
	
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	else:
		set_deferred("monitorable", false)
		set_deferred("monitoring", false)


func _on_body_entered(body: Node) -> void:
#	if body.is_in_group("player") and not _has_been_triggered:
#		player_in_range = body
#		print("Player entered FINAL cutscene trigger area.")
	pass		
#		_mark_triggered()
#		start_cutscene()


# You can call this directly from Boss2 cutscene:
#   final_cutscene_node.start_cutscene()
func start_cutscene() -> void:
	# Ensure we don't start twice
	var tree := get_tree()
	if tree == null:
		print("FinalCutscene: start_cutscene() called but node not in scene tree, ignoring.")
		return

	if _has_been_triggered == false:
		_mark_triggered()

	if player_in_range == null:
		var players := tree.get_nodes_in_group("player")
		if players.size() > 0:
			player_in_range = players[0]
	
	Global.is_cutscene_active = true

	# Switch to cutscene camera if present
	if cutscene_camera:
		cutscene_camera.make_current()

	# Connect Dialogic finished
	if Dialogic.timeline_ended.is_connected(_on_dialogic_finished):
		Dialogic.timeline_ended.disconnect(_on_dialogic_finished)
	Dialogic.timeline_ended.connect(_on_dialogic_finished)

	# Choose dialog branch + persistent flags based on Alyra
	if Global.alyra_dead == false:
		Dialogic.start("timeline11V2", false)  # Alyra alive route
		Global.persistent_saved_alyra = true
		Global.check_100_percent_completion()
		Global.save_persistent_data()
	else:
		Dialogic.start("timeline11", false)    # Alyra dead route
		Global.persistent_alyra_dead = true
		Global.check_100_percent_completion()
		Global.save_persistent_data()

	# Optional animation branching
	# if anim_player:
	# 	if Global.alyra_dead == false and anim_player.has_animation("final_alyra_saved"):
	# 		anim_player.play("final_alyra_saved")
	# 	elif Global.alyra_dead == true and anim_player.has_animation("final_alyra_dead"):
	# 		anim_player.play("final_alyra_dead")


func _restore_player_camera() -> void:
	# Try local reference first
	var player := player_in_range
	
	# Fallback to Global.playerBody if set
	if player == null and Global.playerBody:
		player = Global.playerBody
	
	if player:
		var cam: Camera2D = player.get_node_or_null("Camera2D")
		if cam:
			cam.make_current()


func _on_dialogic_finished(_timeline_name: String = "") -> void:
	print("FinalCutscene: Dialogic finished. Wrapping up and returning to world.")
	
	Global.is_cutscene_active = false

	Dialogic.clear(Dialogic.ClearFlags.FULL_CLEAR)
	
	if Dialogic.timeline_ended.is_connected(_on_dialogic_finished):
		Dialogic.timeline_ended.disconnect(_on_dialogic_finished)

	# Always restore the player camera BEFORE traveling
	_restore_player_camera()

	# Set timeline and original logic
	Global.timeline = 6

	if player_in_range:
		transition_manager.travel_to(player_in_range, target_room, target_spawn)

	Global.remove_quest_marker("Go back to New Aerendale!")
	Global.persistent_cleared_part_1 = true
	Global.check_100_percent_completion()
	Global.save_persistent_data()

	# Make absolutely sure this cutscene can NEVER trigger again
	queue_free()


func _on_body_exited(body: Node) -> void:
	pass
