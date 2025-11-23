# res://scripts/items/VideoTapePickup.gd
extends RigidBody2D

@export_enum("Tape1", "Tape2", "Tape3") var tape_slot: String = "Tape1"
@export var inventory_id: String = "Tape_A"

@export var bounce_force := 100.0
@export var float_height := 10.0
@export var float_speed := 3.0

@export var tape_texture: Texture2D

var initial_y: float
var time := 0.0
var has_settled := false

func _ready():
	#print("VideoTapePickup _ready():", name, "slot =", tape_slot, "inv_id =", inventory_id, " at ", global_position)
	
	# If this tape was already collected in any previous session, don't spawn it
	match tape_slot:
		"Tape1":
			if Global.persistent_video_tape_1_collected:
				print("VideoTapePickup: Tape1 already collected previously, despawning.")
				queue_free()
				return
		"Tape2":
			if Global.persistent_video_tape_2_collected:
				print("VideoTapePickup: Tape2 already collected previously, despawning.")
				queue_free()
				return
		"Tape3":
			if Global.persistent_video_tape_3_collected:
				print("VideoTapePickup: Tape3 already collected previously, despawning.")
				queue_free()
				return
				
	# Physics setup
	gravity_scale = 1.0
	linear_damp = 0.5
	can_sleep = true

	# Small bounce when spawned
	apply_central_impulse(Vector2(randf_range(-50, 50), -bounce_force))

	# Connect pickup trigger
	if has_node("CollectionArea"):
		var area := $CollectionArea
		area.body_entered.connect(_on_body_entered)
		#print("VideoTapePickup: Connected body_entered on", area.name, 
		#	" | layer =", area.collision_layer, 
		#	" | mask =", area.collision_mask)
	else:
		push_error("VideoTapePickup: Missing CollectionArea child!")

	# Apply the inspector texture to the Sprite2D (if present)
	if has_node("Sprite2D") and tape_texture:
		$Sprite2D.texture = tape_texture

	# Store initial Y for float animation
	initial_y = global_position.y

func _process(delta: float) -> void:
	if has_settled:
		time += delta
		global_position.y = initial_y + sin(time * float_speed) * float_height

func _integrate_forces(state) -> void:
	if state.linear_velocity.length() < 5.0 and not has_settled:
		has_settled = true
		initial_y = global_position.y

func _on_body_entered(body: Node2D) -> void:
	#print("VideoTapePickup: body_entered by:", body.name, 
	#	" class:", body.get_class(), 
	#	" groups:", body.get_groups())

	# Be generous about detecting the player
	if not body.is_in_group("player"):
		#print("VideoTapePickup: Ignored, not player.")
		return
	#var is_player := body is Player or body.is_in_group("player")
	#if not is_player:
	#	print("VideoTapePickup: Ignored, not player.")
	#	return

	# Make sure each tape can only be counted once globally
	match tape_slot:
		"Tape1":
			if Global.persistent_video_tape_1_collected:
				print("VideoTapePickup: Tape1 already collected, ignoring.")
				queue_free()
				return
			Global.persistent_video_tape_1_collected = true
		"Tape2":
			if Global.persistent_video_tape_2_collected:
				print("VideoTapePickup: Tape2 already collected, ignoring.")
				queue_free()
				return
			Global.persistent_video_tape_2_collected = true
		"Tape3":
			if Global.persistent_video_tape_3_collected:
				print("VideoTapePickup: Tape3 already collected, ignoring.")
				queue_free()
				return
			Global.persistent_video_tape_3_collected = true

	# Increase total tape count once per unique tape
	Global.persistent_video_tapes += 1
	Global.check_collection_achievements()
	Global.check_100_percent_completion()
	Global.save_persistent_data()

	# Add to player inventory with the custom ID
	if body is Player:
		if not body.inventory.has(inventory_id):
			body.inventory.append(inventory_id)
			print("Inventory after pickup:", body.inventory)
	else:
		print("Warning: VideoTapePickup hit something in 'player' group that is not Player")

	print("Collected video tape:", inventory_id, "Total:", Global.persistent_video_tapes)
	queue_free()
