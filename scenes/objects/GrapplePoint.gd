extends Area2D

const EXACTLYION_AREAS := [
	"Exactlyion Town",
	"Exactlyion Tower Lower Level",
	"Exactlyion Central Room",
	"Exactlyion Tower Upper Level",
	"Exactlyion Mainframe"
]

const TEX_EXACTLYION := preload("res://assets_image/Objects/grappling_point3.png")
const TEX_DEFAULT    := preload("res://assets_image/Objects/grappling_point2.png")

@onready var sprite: Sprite2D = $Sprite2D
@export var use_exactlyion_style: bool = false

func _ready():
	add_to_group("grapple_targets")
	#_update_texture()
	sprite.texture = TEX_EXACTLYION if use_exactlyion_style else TEX_DEFAULT
	# We don't need _process at all now
	#set_process(false)
	
func _process(delta):
	if Global.cyber_form == true:
		sprite.visible = true
	elif Global.cyber_form == false:
		sprite.visible = false

func _update_texture():
	if Global.current_area in EXACTLYION_AREAS:
		sprite.texture = TEX_EXACTLYION
	else:
		sprite.texture = TEX_DEFAULT
		
		
