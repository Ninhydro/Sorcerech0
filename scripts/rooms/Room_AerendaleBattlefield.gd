
extends Node2D



@onready var blocker1 = $StaticBody2D/CollisionShape2D
@onready var blocker2 = $StaticBody2D2/CollisionShape2D




func _ready():
	pass


func _process(delta):
	if Global.timeline >= 5 and Global.timeline <= 6:
		blocker1.disabled = false
		blocker2.disabled = false
	else:
		blocker1.disabled = true
		blocker2.disabled = true
		
	


