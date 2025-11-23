# res://scripts/items/MicrochipPickup.gd
extends RigidBody2D

@export var bounce_force := 100.0
@export var inventory_id := "Microchip"
@export var float_height := 5.0
@export var float_speed := 0.5

# Optional: let you override the texture from inspector
@export var chip_texture: Texture2D = preload("res://assets_image/Objects/collect_objects6.png")

var initial_y: float
var has_settled := false

func _ready():
	# Physics
	gravity_scale = 1.0
	linear_damp = 0.5
	can_sleep = true

	# Bounce out of ground
	apply_central_impulse(Vector2(randf_range(-50, 50), -bounce_force))

	# CollectionArea
	if has_node("CollectionArea"):
		$CollectionArea.body_entered.connect(_on_body_entered)
	else:
		push_error("MicrochipPickup: Missing CollectionArea child!")

	# Apply custom sprite texture if set
	if has_node("Sprite2D") and chip_texture:
		$Sprite2D.texture = chip_texture

	initial_y = global_position.y

func _integrate_forces(state):
	# When the body slows down enough, we start the float tween
	if state.linear_velocity.length() < 5.0 and not has_settled:
		has_settled = true
		initial_y = global_position.y
		start_floating_animation()

func start_floating_animation():
	var tween = create_tween()
	tween.set_loops()  # loop forever
	tween.tween_property(self, "position:y", position.y - float_height, float_speed)
	tween.tween_property(self, "position:y", position.y, float_speed)

func _on_body_entered(body):
	if not body.is_in_group("player"):
		return

	# Increase global persistent count
	Global.persistent_microchips += 1
	Global.check_collection_achievements()
	Global.check_100_percent_completion()
	Global.save_persistent_data()

	# Add to player inventory
	if "inventory" in body:
		body.inventory.append(inventory_id)

	print("Player collected microchip! Total:", Global.persistent_microchips)
	queue_free()
