extends Area2D

@onready var sprite = $Sprite2D
# Called when the node enters the scene tree for the first time.
func _ready():
	add_to_group("grapple_targets")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	var exactlyion_areas = ["Exactlyion Town", "Exactlyion Tower Lower Level", "Exactlyion Central Room", "Exactlyion Tower Upper Level", "Exactlyion Mainframe"]
	
	if Global.current_area in exactlyion_areas:
		sprite.texture = load("res://assets_image/Objects/grappling_point3.png")
	else:
		sprite.texture = load("res://assets_image/Objects/grappling_point2.png")
