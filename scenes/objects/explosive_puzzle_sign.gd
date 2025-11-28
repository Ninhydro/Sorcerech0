# res://scripts/objects/ExplosivePuzzleSign.gd
extends Area2D
class_name ExplosivePuzzleSign

@export var door_path: NodePath  # link to the ExplosiveDoor node in this room

@onready var hitbox: Area2D = $Hitbox if has_node("Hitbox") else null

var player_near: bool = false

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	if hitbox:
		hitbox.area_entered.connect(_on_hitbox_area_entered)
	
	if door_path != NodePath(""):
		var door = get_node_or_null(door_path)
		if door and door is ExplosiveDoor:
			door.reset_puzzle()
		else:
			print("Sign: door_path is set, but node is missing or not ExplosiveDoor.")

func _on_body_entered(body: Node2D) -> void:
	if body == Global.playerBody:
		player_near = true
		print("Sign: Player near.")


func _on_body_exited(body: Node2D) -> void:
	if body == Global.playerBody:
		player_near = false
		print("Sign: Player left.")


# Option 1: hitting sign with attack area
func _on_hitbox_area_entered(area: Area2D) -> void:
	if area == Global.playerDamageZone:
		print("Sign: Hit by player attack → reset + heal")
		_trigger_reset_and_heal()


# Option 2: pressing "yes" while standing near sign
func _input(event):
	if Input.is_action_just_pressed("yes") and player_near:
		print("Sign: 'yes' pressed near sign → reset + heal")
		_trigger_reset_and_heal()


func _trigger_reset_and_heal():
	# 1) Heal player
	var player_node: Player = Global.playerBody
	if player_node and is_instance_valid(player_node):
		Global.health = Global.health_max
		player_node.health_changed.emit(Global.health, Global.health_max)
		print("Sign: Player healed to max (", Global.health, "/", Global.health_max, ")")
	else:
		print("Sign: Player node not found, cannot heal!")
	
	# 2) Reset puzzle via ExplosiveDoor
	if door_path != NodePath(""):
		var door = get_node_or_null(door_path)
		if door and door is ExplosiveDoor:
			door.reset_puzzle()
		else:
			print("Sign: door_path is set, but node is missing or not ExplosiveDoor.")
	else:
		print("Sign: door_path not assigned in Inspector, cannot reset puzzle.")
