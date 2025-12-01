extends Area2D
class_name SaveSpot

const TEX_EXACTLYION := preload("res://assets_image/Objects/save_pole.png")
const TEX_DEFAULT    := preload("res://assets_image/Objects/save_pole2.png")

@onready var interaction_label: Label = $Label
@onready var sprite: Sprite2D = $Sprite2D

var player_in_range := false

# Areas that use the Exactlyion save pole look
const EXACTLYION_AREAS := [
	"Exactlyion Town",
	"Exactlyion Tower Lower Level",
	"Exactlyion Central Room",
	"Exactlyion Tower Upper Level",
	"Exactlyion Mainframe"
]



@export var use_exactlyion_style: bool = false

func _ready():
	add_to_group("save_spots")
	# set correct texture once per instance
	sprite.texture = TEX_EXACTLYION if use_exactlyion_style else TEX_DEFAULT

	interaction_label.visible = false
	set_process(false) # only needed when player is inside

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	print("SaveSpot is ready. Waiting for player interaction.")

func _update_sprite_texture():
	# This is called once per SaveSpot (or when area actually changes)
	if Global.current_area in EXACTLYION_AREAS:
		sprite.texture = TEX_EXACTLYION
	else:
		sprite.texture = TEX_DEFAULT
		
func _process(delta):

	if player_in_range and Input.is_action_just_pressed("yes"):
		handle_interaction()


func handle_interaction():

	var found_node = get_tree().get_first_node_in_group("player")
	var player_node: Player = null # Initialize as null

	if found_node:
		player_node = found_node as Player
		if player_node == null:
			printerr("Error: Found node in 'player' group but it could not be cast to Player type. Is it really your player?")
	else:
		printerr("Error: No node found in 'player' group. Is your Player node added to the 'player' group?")

	if player_node:

		Global.current_scene_path = get_tree().current_scene.scene_file_path
		 

		var manual_save_slot_name = SaveLoadManager.MANUAL_SAVE_SLOT_PREFIX + "1" # Example: Save to slot 1
		Global.health = Global.health_max
		player_node.health_changed.emit(Global.health, Global.health_max) 
		
		if SaveLoadManager.save_game(player_node, manual_save_slot_name): # Pass the player node and slot name
			print("Game saved successfully at SaveSpot to manual slot 1!") # Updated print statement

		else:
			printerr("Failed to save game at SaveSpot (SaveLoadManager returned false).") # Updated print statement
			# Optionally, display an error message

		# --- TELEPORT/LOAD POINT LOGIC (if applicable) ---
		# If this spot also serves as a portal to another level, implement that here.
		# This example assumes for now it's primarily a save point.
		
		# If you set target_scene_path, you could implement a teleport here:
		# if target_scene_path != "":
		#     if ResourceLoader.exists(target_scene_path, "PackedScene"):
		#         var target_scene_packed = load(target_scene_path) as PackedScene
		#         get_tree().change_scene_to_packed(target_scene_packed)
		#         await get_tree().physics_frame # Wait for scene change to complete
		#         await get_tree().physics_frame # Wait another frame for safety
		#         var loaded_player = get_tree().get_first_node_in_group("player")
		#         if loaded_player:
		#             loaded_player.global_position = target_position_in_scene
		#             print("Teleported player to new scene at: ", target_position_in_scene)
		#         else:
		#             printerr("Error: Player not found in new scene after teleport.")
		#     else:
		#         printerr("Error: Target scene path for teleport is invalid: ", target_scene_path)
	else:
		# This message will now be more specific about why player_node is null
		printerr("Player node (or valid Player instance) not found for interaction. Check group and class_name.")


# Called when a body (e.g., player) enters the Area2D
func _on_body_entered(body: Node2D):
	# Check if the entering body is the player by checking its group
	if body.is_in_group("player"):
		player_in_range = true
		interaction_label.visible = true
		Global.near_save = true
		set_process(true)  # start listening for "yes" only while player is here

		print("Player entered SaveSpot area.")

# Called when a body (e.g., player) exits the Area2D
func _on_body_exited(body: Node2D):
	# Check if the exiting body is the player
	if body.is_in_group("player"):
		player_in_range = false
		interaction_label.visible = false
		Global.near_save = false
		set_process(false)  # stop processing when player leaves

		print("Player exited SaveSpot area.")
