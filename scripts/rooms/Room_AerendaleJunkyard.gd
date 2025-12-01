
extends Node2D


@onready var test_dialog_cutscene: Area2D = $Test_dialog # Assuming Test_dialog is a direct child of Room_AerendaleJunkyard
@onready var blocker = $StaticBody2D/CollisionShape2D

@onready var door = $Doors/Door_Maya/Door
@onready var door_area = $Doors/Door_Maya

func _ready():
	door.visible = false
	print("Room_AerendaleJunkyard: _ready() called.")
	if not test_dialog_cutscene:
		printerr("Room_AerendaleJunkyard: WARNING: Test_dialog cutscene not found as child!")
		return # Exit if the child cutscene isn't found


	if Global.playerBody and is_instance_valid(Global.playerBody):

		if test_dialog_cutscene.has_method("set_player_reference"):
			test_dialog_cutscene.set_player_reference(Global.playerBody as Player) # <--- ADD 'as Player' HERE
			print("Room_AerendaleJunkyard: Passed player reference from Global to Test_dialog cutscene child.")
		else:
			printerr("Room_AerendaleJunkyard: WARNING: Test_dialog cutscene script missing 'set_player_reference' method.")
	else:

		print("Room_AerendaleJunkyard: Global.playerBody not available yet in _ready. Test_dialog will attempt to get it later.")



func _process(delta):
	if Global.timeline >= 0 and Global.timeline <= 2:
		blocker.disabled = false
	else:
		blocker.disabled = true
		
	


func _on_door_maya_body_entered(body):
	if body.name == "Player":
		door.visible = true


func _on_door_maya_body_exited(body):

		door.visible = false
