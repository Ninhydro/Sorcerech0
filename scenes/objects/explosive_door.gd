# res://scripts/objects/ExplosiveDoor.gd
extends StaticBody2D
class_name ExplosiveDoor

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer if has_node("AnimationPlayer") else null

# Scene used for respawning base objects when resetting
@export var base_color_object_scene: PackedScene = preload("res://scenes/objects/color_object.tscn")

var destroyed: bool = false

func _ready():
	add_to_group("ExplosiveDoor")
	
	# If the flag was set previously, door should already be gone
	if Global.explode_door:
		print("ExplosiveDoor: Global.explode_door is TRUE → applying destroyed state")
		_apply_destroyed_state()
		destroyed = true
	else:
		print("ExplosiveDoor: Global.explode_door is FALSE → door active")


# Called by ExplosiveColorObject when its explosion hits the door
func on_explosive_hit():
	if destroyed:
		return
	
	destroyed = true
	print("ExplosiveDoor: Hit by explosion → destroy door")
	
	# Set persistent flag
	Global.explode_door = true
	
	# Optional: play explode animation
	if animation_player and animation_player.has_animation("explode"):
		animation_player.play("explode")
		await animation_player.animation_finished
	
	_apply_destroyed_state()


func _apply_destroyed_state():
	destroyed = true
	
	# Disable collision so player can pass
	if collision_shape:
		collision_shape.disabled = true
	
	# Hide door visually
	if sprite:
		sprite.visible = false
	
	# Optionally you could also disable this node entirely:
	# set_process(false)
	# set_physics_process(false)


# PUBLIC – called by reset sign(s)
func reset_puzzle():
	if destroyed:
		print("ExplosiveDoor: puzzle already solved (door destroyed). Reset ignored.")
		return
	
	print("ExplosiveDoor: Resetting puzzle under this door node")
	
	# 1) Reset any ColorMixers under this door
	_reset_mixers_recursive(self)
	
	# 2) Remove all ColorObjects under this door
	var to_remove: Array[ColorObject] = []
	_collect_color_objects_recursive(self, to_remove)
	for obj in to_remove:
		if is_instance_valid(obj):
			obj.queue_free()
	
	await get_tree().process_frame
	
	# 3) Respawn starting objects from Marker_Ball* nodes under this door
	var markers: Array[Marker2D] = []
	_collect_markers_recursive(self, markers)
	
	for marker in markers:
		var color_type: ColorObject.ColorType = _get_color_type_from_marker(marker.name)
		
		if base_color_object_scene:
			var new_obj: ColorObject = base_color_object_scene.instantiate()
			add_child(new_obj)
			
			new_obj.global_position = marker.global_position
			new_obj.original_position = marker.global_position
			new_obj.set_color_type(color_type)
			new_obj.set_is_in_mixer(false)
			new_obj.freeze = false
			
			print("ExplosiveDoor: respawned object at ", marker.name, " with color ", ColorObject.ColorType.keys()[color_type])
	
	print("ExplosiveDoor: Puzzle reset complete.")


# ===== Recursive helpers =====

func _reset_mixers_recursive(node: Node) -> void:
	for child in node.get_children():
		if child is ColorMixer:
			child.reset_mixer()
		_reset_mixers_recursive(child)


func _collect_color_objects_recursive(node: Node, out: Array[ColorObject]) -> void:
	for child in node.get_children():
		if child is ColorObject:
			out.append(child)
		_collect_color_objects_recursive(child, out)


func _collect_markers_recursive(node: Node, out: Array[Marker2D]) -> void:
	for child in node.get_children():
		if child is Marker2D and child.name.begins_with("Marker_Ball"):
			out.append(child)
		_collect_markers_recursive(child, out)


# Marker → color mapping (4 balls)
func _get_color_type_from_marker(marker_name: String) -> ColorObject.ColorType:
	match marker_name:
		"Marker_Ball1":
			return ColorObject.ColorType.RED
		"Marker_Ball2":
			return ColorObject.ColorType.YELLOW
		"Marker_Ball3":
			return ColorObject.ColorType.BLUE
		"Marker_Ball4":
			return ColorObject.ColorType.BLUE
		_:
			print("ExplosiveDoor: Unknown marker name ", marker_name, " → defaulting to RED")
			return ColorObject.ColorType.RED
