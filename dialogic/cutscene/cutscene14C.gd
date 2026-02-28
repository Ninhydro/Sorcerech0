extends MasterCutscene

#var _has_been_triggered: bool = false
#@onready var collision_shape: CollisionShape2D = $CollisionShape2D
#@export var play_only_once: bool = true





var player_in_range = null

@onready var transition_manager = get_node("/root/TransitionManager")

# --- Optional camera/timer UI ---
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var boss_camera: Camera2D = $Camera2D
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

@onready var health_spawn_marker: Marker2D = $HealthSpawnMarker
@onready var health_timer: Timer = $HealthTimer

@export var health_pickup_scene: PackedScene = preload("res://scenes/objects/health_pickup.tscn")

var current_health_pickup: Node2D = null

@export var new_cutscene_path: NodePath


@onready var nataly: Sprite2D = $Nataly
@onready var maya: Sprite2D = $Maya
@onready var fini: Sprite2D = $"Replica Fini"

@onready var marker1: Marker2D = $Marker2D

func _ready() -> void:
	# Timer label hidden until battle starts
	cutscene_name = "BossCyber1Cutscene"
	play_only_once = true
	_reset_visuals()
	# Setup battle specific components
	if timer_label:
		timer_label.visible = false
	if timer_color:
		timer_color.visible = false
	
	if boss_timer:
		boss_timer.one_shot = true
		if not boss_timer.timeout.is_connected(_on_boss_timer_timeout):
			boss_timer.timeout.connect(_on_boss_timer_timeout)
		#boss_timer.wait_time = 30.0  # 2 minutes
		#boss_timer.timeout.connect(_on_boss_timer_timeout)
	
	if health_timer:
		health_timer.one_shot = false
		#health_timer.wait_time = 30.0  # drop every 30 seconds
		if not health_timer.timeout.is_connected(_on_health_timer_timeout):
			health_timer.timeout.connect(_on_health_timer_timeout)
			
	#_deactivate_barriers()
	_reset_for_retry()
	
	# Call parent ready
	super._ready()
# Called when the node enters the scene tree for the first time.

func _reset_for_retry() -> void:
	# Only reset if the boss is NOT permanently finished
	# (adjust this condition if you have a different “boss cleared” flag)
	if Global.meet_replica and Global.timeline > 6.5:
		# Boss already truly done → you may even want to queue_free() this trigger
		print("Boss1: already cleared, leaving trigger disabled.")
		collision_shape.disabled = true
		return

	print("Boss1: resetting state for retry")
	_has_been_triggered = false
	battle_active = false
	battle_cancelled_on_player_death = false
	boss_instance = null
	
	if boss_timer:
		boss_timer.stop()
	if health_timer:
		health_timer.stop()
	
	_deactivate_barriers()
	
	if timer_label:
		timer_label.visible = false
	if timer_color:
		timer_color.visible = false
		
			
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

		#if collision_shape:
		#	collision_shape.set_deferred("disabled", true)
		#else:
		#	printerr("Cutscene Area2D: WARNING: CollisionShape2D is null, cannot disable it. Using Area2D monitoring instead.")
		#	set_deferred("monitorable", false)
		#	set_deferred("monitoring", false)

		#start_cutscene(cutscene_animation_name_to_play, 0.0)

		#if play_only_once:
		#	_has_been_triggered = true
		
		#_start_intro_cutscene()
		super._on_body_entered(body)

func _setup_cutscene():
	cutscene_name = "finiboss"
	nataly.visible = false
	maya.visible = false
	fini.visible = false
	play_only_once = true
	area_activation_flag = ""  # No flag required
	global_flag_to_set = ""  # We'll handle this manually
	
	# IMPORTANT: Make sure your scene has these Marker2D nodes or set positions manually

	player_markers = {
		# Example positions - adjust to match your scene
		"marker1": marker1.global_position,
		#"marker2": marker2.global_position,
		#"marker3": marker3.global_position,
		#"marker4": marker4.global_position,
		#"marker5": marker5.global_position,
		#"marker6": marker6.global_position
		
	}
	
	# Simple sequence: just play dialog
	sequence = [
		{"type": "wait", "duration": 0.5},
		{"type": "fade_out", "wait": false},
		
		#{"type": "player_face", "direction": -1}, #1 is right, -1 is left
		#{"type": "move_player", "name": "marker1",  "duration": 2, "animation": "run", "wait": false},
		#{"type": "animation", "name": "anim1", "wait": true, "loop": false},
		#{"type": "player_animation", "name": "idle",  "wait": false},
		#{"type": "animation", "name": "anim1_idle", "wait": false, "loop": true},
		#{"type": "dialog", "name": "timeline9", "wait": true},
		#{"type": "animation", "name": "anim2", "wait": true, "loop": false},
		#{"type": "player_animation", "name": "attack",  "wait": false},
		#{"type": "animation", "name": "anim2_idle", "wait": false, "loop": true},
		{"type": "dialog", "name": "timeline15C", "wait": true},
		{"type": "dialog", "name": "timeline15_2C", "wait": true},
		{"type": "wait", "duration": 0.1},		
		{"type": "fade_in"},
		#{"type": "animation", "name": "anim3", "wait": false, "loop": false},
		

	]

func _on_cutscene_start():
	print("Cutscenefiniboss: Starting")
	# Player reference is already stored in _player_ref by parent class
	if _player_ref:
		player_in_range = _player_ref
		print("Cutscenefiniboss: Player reference stored: ", player_in_range.name)

func _on_cutscene_end():
	print("Cutscenefiniboss: Finished")
	nataly.visible = false
	maya.visible = false
	fini.visible = false
	# Set timeline
	_start_boss_battle()


	
#func _start_intro_cutscene() -> void:

	
#		Global.is_cutscene_active = true
#		if player_in_range:
#			var player_cam: Camera2D = player_in_range.get_node_or_null("Camera2D")
#			if player_cam:
#				previous_player_camera = player_cam
		
		# Switch to boss camera
#		if boss_camera:
#			boss_camera.make_current()
		
		# Optional intro anim
#		if anim_player and anim_player.has_animation("intro"):
#			anim_player.play("intro")
		#Global.cutscene_name = cutscene_animation_name
		#Global.cutscene_playback_position = start_position
		#Dialogic.start("timeline1", false)
#		if Dialogic.timeline_ended.is_connected(_on_intro_dialog_finished):
#			Dialogic.timeline_ended.disconnect(_on_intro_dialog_finished)
#		Dialogic.timeline_ended.connect(_on_intro_dialog_finished)


#		Dialogic.start("timeline15C", false)
		#if Global.alyra_dead == false:
		#	Dialogic.start("timeline13V2", false) #alive alive

		#elif Global.alyra_dead == true:
		#	Dialogic.start("timeline13", false) #alive dead



#func _on_intro_dialog_finished(_timeline_name = ""):
#	print("CutsceneManager: Dialogic timeline finished. Initiating fade out.")
	# Dialog is done. Now, fade out the black screen.

#	Global.is_cutscene_active = false
	
#	Dialogic.clear(Dialogic.ClearFlags.FULL_CLEAR)
	
	# Disconnect the signal to prevent unintended calls.
#	if Dialogic.timeline_ended.is_connected(_on_intro_dialog_finished):
#		Dialogic.timeline_ended.disconnect(_on_intro_dialog_finished)

#	_start_boss_battle()

func _start_boss_battle() -> void:
	_activate_barriers()
	battle_cancelled_on_player_death = false
	battle_active = false

	Global.meet_replica = true
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

	# >>> NEW: pass 6 markers into the boss <<<
	var markers: Array = []
	if parent:
		var marker_names = [
			"ReplicaMarker_LowLeft",
			"ReplicaMarker_MidLeft",
			"ReplicaMarker_HighLeft",
			"ReplicaMarker_LowRight",
			"ReplicaMarker_MidRight",
			"ReplicaMarker_HighRight"
		]
		for name in marker_names:
			if parent.has_node(name):
				var m = parent.get_node(name)
				markers.append(m)

	if boss_instance.has_method("setup_markers"):
		boss_instance.call("setup_markers", markers)
	# <<< END NEW >>>

	# Listen for boss death
	if not boss_instance.tree_exited.is_connected(_on_boss_died):
		boss_instance.tree_exited.connect(_on_boss_died)

	battle_active = true

	if boss_timer:
		boss_timer.start()
	if timer_label:
		timer_label.visible = true
	if timer_color:
		timer_color.visible = true
	if health_timer:
		health_timer.start()

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
	if health_timer:
		health_timer.stop()
	if current_health_pickup and is_instance_valid(current_health_pickup):
		current_health_pickup.queue_free()
		current_health_pickup = null
		
	Global.ult_cyber_form = true
	Global.replica_fini_dead = true
	#Global.affinity -= 1
	Global.increment_kills()
	
	var node_path: NodePath = new_cutscene_path 
	print("finishing battle cutscene1")
	if node_path != NodePath("") and has_node(node_path):
		var cs_node: Node = get_node(node_path)
		print("get nodepath1")
		if cs_node.has_method("start_cutscene2"):
			cs_node.call("start_cutscene2")
			print("get start_cutscene2")
		else:
			if cs_node is CanvasItem:
				cs_node.visible = true
				
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
	#if Dialogic.timeline_ended.is_connected(_on_replica2_dialog_finished):
	#	Dialogic.timeline_ended.disconnect(_on_replica2_dialog_finished)
	#Dialogic.timeline_ended.connect(_on_replica2_dialog_finished)
	
	#Dialogic.start("timeline16C", false)

		
	# After this you can move timeline forward or leave it as is.
	# Global.timeline = 6.7  # example


func _handle_battle_fail() -> void:
	# Branch: player survived timer, didn't kill Replica
	_reset_visuals()
	
	if health_timer:
		health_timer.stop()
	if current_health_pickup and is_instance_valid(current_health_pickup):
		current_health_pickup.queue_free()
		current_health_pickup = null
		
	Global.ult_cyber_form = false
	Global.replica_fini_dead = false
	
	var node_path: NodePath = new_cutscene_path 
	print("finishing battle cutscene1")
	if node_path != NodePath("") and has_node(node_path):
		var cs_node: Node = get_node(node_path)
		print("get nodepath1")
		if cs_node.has_method("start_cutscene2"):
			cs_node.call("start_cutscene2")
			print("get start_cutscene2")
		else:
			if cs_node is CanvasItem:
				cs_node.visible = true
	#else:
	#	var branch_text := "SUCCESS" if success else "FAIL"
	#	print("No next cutscene node assigned for ", branch_text, " branch yet.")
	#Global.affinity += 1
	
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

			

			

func cancel_replica_boss_battle_on_player_death() -> void:
	# Called from Player.handle_death() for group "replica_boss_cutscene"
	if not battle_active:
		return
	
	print("ReplicaBoss: Battle cancelled due to player death.")
	battle_active = false
	battle_cancelled_on_player_death = true
	
	if boss_timer:
		boss_timer.stop()
	if health_timer:
		health_timer.stop()
	if current_health_pickup and is_instance_valid(current_health_pickup):
		current_health_pickup.queue_free()
		current_health_pickup = null
		
	
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
			
func _on_health_timer_timeout() -> void:
	# Only spawn if fight is on and player alive
	if not battle_active or not Global.playerAlive:
		return

	# Don’t spawn a new one if the old one is still sitting there
	if current_health_pickup and is_instance_valid(current_health_pickup):
		return

	if not health_pickup_scene:
		printerr("ReplicaBoss: health_pickup_scene not assigned!")
		return
	if not health_spawn_marker:
		printerr("ReplicaBoss: health_spawn_marker not assigned!")
		return

	var parent := get_parent()
	if parent == null:
		parent = get_tree().current_scene

	current_health_pickup = health_pickup_scene.instantiate()
	parent.add_child(current_health_pickup)
	var spawn_pos := health_spawn_marker.global_position
	spawn_pos.y -= 8   # 4–16 pixels is usually enough depending on your tile size
	current_health_pickup.global_position = spawn_pos
	#current_health_pickup.global_position = health_spawn_marker.global_position

	# When the pickup is collected/removed, clear our reference
	if not current_health_pickup.tree_exited.is_connected(_on_health_pickup_removed):
		current_health_pickup.tree_exited.connect(_on_health_pickup_removed)

	print("ReplicaBoss: spawned health pickup at ", current_health_pickup.global_position)

func _on_health_pickup_removed() -> void:
	current_health_pickup = null
