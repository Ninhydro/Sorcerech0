extends StaticBody2D

@export var bounce_angle_degrees: float
@export var bounce_power: float = 1.0

func _ready():
	# Always have collision enabled
	collision_layer = 2
	collision_mask = 1

func get_bounce_data() -> Dictionary:
	var calculated_bounce_normal = Vector2.RIGHT.rotated(deg_to_rad(bounce_angle_degrees))
	return {
		"normal": calculated_bounce_normal,
		"power": bounce_power
	}

func can_bounce(player_node) -> bool:
	# Only allow bouncing when player is in cannon mode and launched
	if not player_node.is_launched:
		return false
	
	# ADDED: Check if player's collision mask includes layer 2 (bounce spots)
	# If player's mask doesn't include layer 2, they should pass through
	var player_collision_mask = player_node.collision_mask
	var layer_2_bitmask = 1 << 1  # Layer 2 is bit 1 (value 2)
	var can_collide_with_bounce = (player_collision_mask & layer_2_bitmask) != 0
	
	print("DEBUG: Player can collide with bounce spots: ", can_collide_with_bounce)
	return can_collide_with_bounce
