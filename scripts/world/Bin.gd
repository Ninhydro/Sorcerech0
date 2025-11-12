# Bin.gd
extends Area2D

@export var bin_name: String = ""

signal object_dropped(bin_name: String, object: RigidBody2D)

func _ready():
	# Make sure the Area2D is set to monitor bodies
	collision_layer = 7  # Or use layer 8 if available
	collision_mask = 6   # Bins detect objects (layer 6)
	
	monitoring = true
	body_entered.connect(_on_body_entered)
	print("Bin '", bin_name, "' initialized - Layer: ", collision_layer, " Mask: ", collision_mask)

func _on_body_entered(body: Node):
	# Check if the entering body is a FallingObject
	if body and body.is_in_group("FallingObjects"):
		print("Bin '", bin_name, "' detected '", body.object_type, "' object - Position: ", body.global_position)
		object_dropped.emit(bin_name, body)
	else:
		print("Bin '", bin_name, "' detected non-FallingObject: ", body.name if body else "null")
