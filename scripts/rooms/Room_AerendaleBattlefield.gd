# NEW FILE: scripts/room_aerendale_junkyard.gd
extends Node2D

# NEW: Reference to the Test_dialog cutscene within this room

@onready var blocker1 = $StaticBody2D/CollisionShape2D
@onready var blocker2 = $StaticBody2D2/CollisionShape2D




func _ready():
	pass
		# Alternatively, if you want to ensure it's set for *all* purposes of test_dialog_cutscene.gd:
		# Callable(self, "_deferred_set_player_ref").call_deferred()
		
# NEW: Function to receive player reference from World.gd and pass it down

func _process(delta):
	if Global.timeline >= 5 and Global.timeline <= 6:
		blocker1.disabled = false
		blocker2.disabled = false
	else:
		blocker1.disabled = true
		blocker2.disabled = true
		
	


