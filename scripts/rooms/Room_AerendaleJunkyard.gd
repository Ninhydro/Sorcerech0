# NEW FILE: scripts/room_aerendale_junkyard.gd
extends Node2D

# NEW: Reference to the Test_dialog cutscene within this room
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

	# NEW: Get player directly from Global and pass to Test_dialog when this room is ready
	if Global.playerBody and is_instance_valid(Global.playerBody):
		# Cast Global.playerBody to your custom Player class when passing it
		# This is important if Global.playerBody is only typed as CharacterBody2D
		if test_dialog_cutscene.has_method("set_player_reference"):
			test_dialog_cutscene.set_player_reference(Global.playerBody as Player) # <--- ADD 'as Player' HERE
			print("Room_AerendaleJunkyard: Passed player reference from Global to Test_dialog cutscene child.")
		else:
			printerr("Room_AerendaleJunkyard: WARNING: Test_dialog cutscene script missing 'set_player_reference' method.")
	else:
		# This might happen if Room_AerendaleJunkyard _ready runs before Player's _ready (and Global.playerBody assignment)
		# We can add a deferred call or a signal to handle this.
		# For robustness, Test_dialog.gd's _on_body_entered already attempts to get Global.playerBody
		# if player_node_ref is null, which is a good fallback.
		print("Room_AerendaleJunkyard: Global.playerBody not available yet in _ready. Test_dialog will attempt to get it later.")
		# Alternatively, if you want to ensure it's set for *all* purposes of test_dialog_cutscene.gd:
		# Callable(self, "_deferred_set_player_ref").call_deferred()
		
# NEW: Function to receive player reference from World.gd and pass it down

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
