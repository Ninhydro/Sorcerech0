extends Area2D

var _has_been_triggered: bool = false
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@export var play_only_once: bool = true





var player_in_range = null

@onready var transition_manager = get_node("/root/TransitionManager")

# --- Optional camera/timer UI ---
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var boss_camera: Camera2D = $BossCamera2D
@onready var boss_spawn_marker: Marker2D = $BossSpawnMarker
@onready var boss_timer: Timer = $BossTimer
@onready var timer_label: Label = $CanvasLayer/TimerLabel
@onready var timer_color: ColorRect = $CanvasLayer/ColorRect

var previous_player_camera: Camera2D = null
var boss_instance: Node = null
var battle_active: bool = false
var battle_cancelled_on_player_death: bool = false

# --- Replica boss scene ---
@export var boss_scene: PackedScene = preload("res://scenes/enemies/ReplicaFini.tscn")

var target_room = "Room_ExactlyionTown"     # Name of the destination room (node or scene)
var target_spawn = "Spawn_FromExactlyionBattlefield2"    # Name of the spawn marker in the target room

var target_room2 = "Room_ExactlyionTown"     # Name of the destination room (node or scene)
var target_spawn2 = "Spawn_FromExactlyionValentina"    # Name of the spawn marker in the target room


# Boss scene to spawn


# Optional: paths to next cutscene nodes (set in Inspector later)

@export var boss_barriers: Array[NodePath] = []



# Called when the node enters the scene tree for the first time.
func _ready():

	_reset_visuals()
	
	if boss_timer:
		boss_timer.one_shot = true
		boss_timer.wait_time = 60.0  # e.g. 60s or 120s
		if not boss_timer.timeout.is_connected(_on_boss_timer_timeout):
			boss_timer.timeout.connect(_on_boss_timer_timeout)


func _reset_visuals() -> void:
	_deactivate_barriers()
	if timer_label:
		timer_label.visible = false
	if timer_color:
		timer_color.visible = false
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if Global.timeline == 6.5 and Global.meet_replica == false: 
		collision_shape.disabled = false
	else:
		collision_shape.disabled = true
		#_deactivate_barriers()
	
	# Update timer label
	if battle_active and boss_timer and timer_label:
		var remaining: int = int(ceil(boss_timer.time_left))
		var minutes: int = remaining / 60
		var seconds: int = remaining % 60
		timer_label.text = "%02d:%02d" % [minutes, seconds]



func _on_body_entered(body):
	#print("Player position: ",player_node_ref.global_position)
	if (body.is_in_group("player") and not _has_been_triggered):  #and Global.cutscene_finished1 == false:
		player_in_range = body
		print("Player entered cutscene trigger area. Starting cutscene.")

		if collision_shape:
			collision_shape.set_deferred("disabled", true)
		else:
			printerr("Cutscene Area2D: WARNING: CollisionShape2D is null, cannot disable it. Using Area2D monitoring instead.")
			set_deferred("monitorable", false)
			set_deferred("monitoring", false)

		#start_cutscene(cutscene_animation_name_to_play, 0.0)

		if play_only_once:
			_has_been_triggered = true
		
		_start_intro_cutscene()

func _start_intro_cutscene() -> void:

	
		Global.is_cutscene_active = true
		if player_in_range:
			var player_cam: Camera2D = player_in_range.get_node_or_null("Camera2D")
			if player_cam:
				previous_player_camera = player_cam
		
		# Switch to boss camera
		if boss_camera:
			boss_camera.make_current()
		
		# Optional intro anim
		if anim_player and anim_player.has_animation("intro"):
			anim_player.play("intro")
		#Global.cutscene_name = cutscene_animation_name
		#Global.cutscene_playback_position = start_position
		#Dialogic.start("timeline1", false)
		if Dialogic.timeline_ended.is_connected(_on_intro_dialog_finished):
			Dialogic.timeline_ended.disconnect(_on_intro_dialog_finished)
		Dialogic.timeline_ended.connect(_on_intro_dialog_finished)


		Dialogic.start("timeline15C", false)
		#if Global.alyra_dead == false:
		#	Dialogic.start("timeline13V2", false) #alive alive

		#elif Global.alyra_dead == true:
		#	Dialogic.start("timeline13", false) #alive dead



func _on_intro_dialog_finished(_timeline_name = ""):
	print("CutsceneManager: Dialogic timeline finished. Initiating fade out.")
	# Dialog is done. Now, fade out the black screen.

	Global.is_cutscene_active = false
	
	Dialogic.clear(Dialogic.ClearFlags.FULL_CLEAR)
	
	# Disconnect the signal to prevent unintended calls.
	if Dialogic.timeline_ended.is_connected(_on_intro_dialog_finished):
		Dialogic.timeline_ended.disconnect(_on_intro_dialog_finished)

	_start_boss_battle()

func _start_boss_battle() -> void:
	_activate_barriers()
	battle_cancelled_on_player_death = false
	battle_active = false
	
	#Global.timeline = 6.5
	Global.meet_replica = true
	# Heal player fully for boss
	Global.health = Global.health_max
	if is_instance_valid(Global.player):
		Global.player.health_changed.emit(Global.health, Global.health_max)
	
	if not boss_scene:
		printerr("ReplicaBoss: boss_scene not assigned!")
		return
	
	boss_instance = boss_scene.instantiate()
	if boss_instance == null:
		printerr("ReplicaBoss: Failed to instance boss_scene.")
		return
	
	var parent := get_parent()
	if parent:
		parent.add_child(boss_instance)
	else:
		get_tree().current_scene.add_child(boss_instance)
	
	if boss_spawn_marker:
		boss_instance.global_position = boss_spawn_marker.global_position
	
	# Listen for boss death
	if not boss_instance.tree_exited.is_connected(_on_boss_died):
		boss_instance.tree_exited.connect(_on_boss_died)
	
	battle_active = true
	
	# Start timer + show UI
	if boss_timer:
		boss_timer.start()
	if timer_label:
		timer_label.visible = true
	if timer_color:
		timer_color.visible = true
	
	print("ReplicaBoss: Battle started.")


func _on_boss_timer_timeout() -> void:
	if not battle_active or battle_cancelled_on_player_death or not Global.playerAlive:
		return
	
	battle_active = false
	
	var boss_alive := is_instance_valid(boss_instance)
	if boss_alive:
		print("ReplicaBoss: Timer finished, boss still alive → go Valentina path.")
		
		if boss_instance:
			boss_instance.queue_free()
			boss_instance = null
		
		_handle_battle_fail()
	else:
		print("ReplicaBoss: Timer finished but boss already dead → treat as success.")
		_handle_battle_success()


func _on_boss_died() -> void:
	if not battle_active:
		boss_instance = null
		return
	
	if battle_cancelled_on_player_death or not Global.playerAlive:
		print("ReplicaBoss: Boss died while player dead / battle cancelled, ignoring.")
		boss_instance = null
		return
	
	print("ReplicaBoss: Boss defeated by player!")
	battle_active = false
	
	if boss_timer:
		boss_timer.stop()
	
	boss_instance = null
	_handle_battle_success()


			
func _handle_battle_success() -> void:
	# Branch: player directly killed the Replica Fini
	_reset_visuals()
	
	Global.ult_cyber_form = true
	Global.replica_fini_dead = true
	Global.affinity -= 1
	Global.increment_kills()
	
	# You can adjust timeline if needed, e.g. Global.timeline = 6.6
	# Global.timeline = 6.6
	
	# Return camera to player
	#if previous_player_camera:
	#	previous_player_camera.make_current()
	#elif player_in_range:
	#	var player_cam: Camera2D = player_in_range.get_node_or_null("Camera2D")
	#	if player_cam:
	#		player_cam.make_current()
	
	# Play next dialog: "replica_boss_cutscene2"
	if Dialogic.timeline_ended.is_connected(_on_replica2_dialog_finished):
		Dialogic.timeline_ended.disconnect(_on_replica2_dialog_finished)
	Dialogic.timeline_ended.connect(_on_replica2_dialog_finished)
	
	Dialogic.start("timeline16C", false)


func _on_replica2_dialog_finished(_timeline_name: String = "") -> void:
	print("ReplicaBoss: replica_boss_cutscene2 finished.")
	Dialogic.clear(Dialogic.ClearFlags.FULL_CLEAR)
	if Dialogic.timeline_ended.is_connected(_on_replica2_dialog_finished):
		Dialogic.timeline_ended.disconnect(_on_replica2_dialog_finished)
	player_in_range.unlock_and_force_form("UltimateCyber")
		#player_in_range.unlock_state("UltimateCyber")
		#player_in_range.switch_state("UltimateCyber")
		#Global.selected_form_index = 4
		#player_in_range.current_state_index = Global.selected_form_index
		#player_in_range.combat_fsm.change_state(IdleState.new(player_in_range))
	
	_restore_player_camera()
	if player_in_range:
		transition_manager.travel_to(player_in_range, target_room2, target_spawn2)
	Global.remove_quest_marker("Meet the Cyber Queen")
		
	# After this you can move timeline forward or leave it as is.
	# Global.timeline = 6.7  # example


func _handle_battle_fail() -> void:
	# Branch: player survived timer, didn't kill Replica
	_reset_visuals()
	
	Global.ult_cyber_form = false
	Global.replica_fini_dead = false
	Global.affinity += 1
	
	# Optional: change timeline to reflect "Valentina route"
	# Global.timeline = 6.6
	
	# Return camera to player before next cutscene
	#if previous_player_camera:
	#	previous_player_camera.make_current()
	#elif player_in_range:
	#	var player_cam: Camera2D = player_in_range.get_node_or_null("Camera2D")
	#	if player_cam:
	#		player_cam.make_current()
	
	# Now play "valentina_cutscene2", and AFTER it ends we travel to rocket minigame
	if Dialogic.timeline_ended.is_connected(_on_valentina2_dialog_finished):
		Dialogic.timeline_ended.disconnect(_on_valentina2_dialog_finished)
	Dialogic.timeline_ended.connect(_on_valentina2_dialog_finished)
	
	Dialogic.start("timeline16CV2", false)


func _on_valentina2_dialog_finished(_timeline_name: String = "") -> void:
	print("ReplicaBoss: valentina_cutscene2 finished, travelling to rocket room.")
	Dialogic.clear(Dialogic.ClearFlags.FULL_CLEAR)
	if Dialogic.timeline_ended.is_connected(_on_valentina2_dialog_finished):
		Dialogic.timeline_ended.disconnect(_on_valentina2_dialog_finished)
	
	# Travel to rocket minigame scene
	#if target_room2 != "" and target_spawn2 != "" and player_in_range:
	#	if Engine.has_singleton("transition_manager"):
	#		var tm = Engine.get_singleton("transition_manager")
	#		tm.travel_to(player_in_range, target_room2, target_spawn2)
	#	elif "transition_manager" in ProjectSettings.get_setting("autoload"):
	#		transition_manager.travel_to(player_in_range, target_room2, target_spawn2)
	#	else:
	#		printerr("ReplicaBoss: transition_manager not found, cannot travel.")
	_restore_player_camera()
	if player_in_range:
			transition_manager.travel_to(player_in_range, target_room, target_spawn)
			

			

func cancel_replica_boss_battle_on_player_death() -> void:
	# Called from Player.handle_death() for group "replica_boss_cutscene"
	if not battle_active:
		return
	
	print("ReplicaBoss: Battle cancelled due to player death.")
	battle_active = false
	battle_cancelled_on_player_death = true
	
	if boss_timer:
		boss_timer.stop()
	
	if boss_instance and is_instance_valid(boss_instance):
		if boss_instance.tree_exited.is_connected(_on_boss_died):
			boss_instance.tree_exited.disconnect(_on_boss_died)
		boss_instance.queue_free()
		boss_instance = null
	
	_reset_visuals()
	
	# Give camera back to player
	if previous_player_camera:
		previous_player_camera.make_current()
	elif player_in_range:
		var player_cam: Camera2D = player_in_range.get_node_or_null("Camera2D")
		if player_cam:
			player_cam.make_current()
	#if player_in_range:
	#		transition_manager.travel_to(player_in_range, target_room, target_spawn)
	#End Demo/Part 1
	
	
	#Global.magus_form = true
	#player_in_range.unlock_state("Magus")
	#player_in_range.switch_state("Magus")
	#Global.selected_form_index = 1
	#player_in_range.current_state_index = Global.selected_form_index
	#player_in_range.combat_fsm.change_state(IdleState.new(player_in_range))
	
	#Global.set_player_form(get_current_form_id())
	#Global.current_form = get_current_form_id()
	#Global.first_tromarvelia = true



func _on_body_exited(body):
	pass # Replace with function body.

func _activate_barriers() -> void:
	for path in boss_barriers:
		if has_node(path):
			var b = get_node(path)
			if b is CollisionObject2D:
				b.set_deferred("collision_layer", 1)  # enable collision
				b.set_deferred("collision_mask", 1)
			if b is CanvasItem:
				b.visible = true

func _deactivate_barriers() -> void:
	for path in boss_barriers:
		if has_node(path):
			var b = get_node(path)
			if b is CollisionObject2D:
				b.set_deferred("collision_layer", 0)
				b.set_deferred("collision_mask", 0)
			if b is CanvasItem:
				b.visible = false

func _restore_player_camera() -> void:
	# Disable boss camera so it stops being considered
	if boss_camera:
		boss_camera.enabled = false

	# Try local reference first
	var player: Node = player_in_range
	
	# Fallback to Global.playerBody if set
	if player == null and Global.playerBody:
		player = Global.playerBody
	
	if player:
		var cam: Camera2D = player.get_node_or_null("Camera2D")
		if cam:
			cam.enabled = true
			cam.make_current()
