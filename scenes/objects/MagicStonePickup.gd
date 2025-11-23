# res://scripts/items/MagicStonePickup.gd
extends RigidBody2D

@export var bounce_force := 100.0
@export var inventory_id := "MagicStone"
@export var float_height := 5.0
@export var float_speed := 0.5

@export var stone_texture: Texture2D = preload("res://assets_image/Objects/collect_objects6.png")

var initial_y: float
var has_settled := false

func _ready():
	gravity_scale = 1.0
	linear_damp = 0.5
	can_sleep = true

	apply_central_impulse(Vector2(randf_range(-50, 50), -bounce_force))

	if has_node("CollectionArea"):
		$CollectionArea.body_entered.connect(_on_body_entered)
	else:
		push_error("MagicStonePickup: Missing CollectionArea child!")

	if has_node("Sprite2D") and stone_texture:
		$Sprite2D.texture = stone_texture

	initial_y = global_position.y

func _integrate_forces(state):
	if state.linear_velocity.length() < 5.0 and not has_settled:
		has_settled = true
		initial_y = global_position.y
		start_floating_animation()

func start_floating_animation():
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(self, "position:y", position.y - float_height, float_speed)
	tween.tween_property(self, "position:y", position.y, float_speed)

func _on_body_entered(body):
	if not body.is_in_group("player"):
		return

	Global.persistent_magic_stones += 1
	Global.check_collection_achievements()
	Global.check_100_percent_completion()
	Global.save_persistent_data()

	if "inventory" in body:
		body.inventory.append(inventory_id)

	print("Player collected magic stone! Total:", Global.persistent_magic_stones)
	queue_free()
