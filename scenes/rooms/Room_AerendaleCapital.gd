extends Node2D

@onready var door = $Doors/Door_Lab/Label
@onready var door_hidden = $Doors/Door_HiddenRuins/Label
@onready var door_hidden_area = $Doors/Door_HiddenRuins/CollisionShape2D
@onready var door_hidden_block = $Doors/Door_HiddenRuins/Sprite2D

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_door_hidden_ruins_body_entered(body):
	if Global.timeline >= 8 and (Global.route_status == "True" or Global.route_status == "Pacifist") :
		door_hidden_area.disabled = false
		door_hidden_block.visible = false
		if body.name == "Player":
			door_hidden.visible = true
	else:
		door_hidden_block.visible = true
		door_hidden_area.disabled = true


func _on_door_hidden_ruins_body_exited(body):

		door_hidden.visible = false


func _on_door_lab_body_entered(body):
	if body.name == "Player":
		door.visible = true



func _on_door_lab_body_exited(body):

		door.visible = false
