extends Node2D


@onready var player = get_node("/root/World/Player")
@onready var blocker = $StaticBody2D/CollisionShape2D
@onready var blocker2 = $StaticBody2D2/CollisionShape2D

@onready var door = $Doors/Door_Nora/Label
#@onready var door2 = $cutscene21_5B2/Label2

func _ready() -> void:
	#print("World ready. Initializing sandbox...")
	#Dialogic.start("timeline1", false)
	#add_child(new_dialog)
	 # Safely enable Camera2D if it exists under the player
	
	pass
	#if player.has_node("Camera2D"):
	#	var cam = $Player.get_node("Camera2D")
	#	if cam is Camera2D:
	#		cam.make_current()
	
	# Optional: Display sandbox label
	#if has_node("Label"):
	#	$Label.text = "Welcome to the Platformer Sandbox!"

	# Enable some test abilities for sandbox
	# Toggle player abilities for testing

	#if has_node("Player"):
	#	$Player.allow_double_jump = true
	#	$Player.allow_dash = true
	#	$Player.allow_wall_climb = true

	# Add a static floor platform if not already present
	
func _process(delta):
	#print(Global.timeline)
	if Global.magus_form or Global.cyber_form:
		
		blocker.disabled = true
	else:
		blocker.disabled = false
		
	if Global.timeline != 8:
		blocker2.disabled = true
	else:
		blocker2.disabled = false
	






func _on_door_nora_body_entered(body):
	if body.name == "Player":
		door.visible = true


func _on_door_nora_body_exited(body):
	door.visible = false
