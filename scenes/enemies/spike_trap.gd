extends Area2D
class_name SpikeTrap

@export var damage_percentage: float = 10.0

const TEX_EXACTLYION := preload("res://assets_image/Objects/SpikeStrip1.png")
const TEX_DEFAULT    := preload("res://assets_image/Objects/SpikeStrip2.png")

@onready var sprite: Sprite2D = $Sprite2D

# OPTIONAL: a custom respawn marker (can be child or external)
@export var respawn_marker: Marker2D

@export var use_exactlyion_style: bool = false

func _ready():
	add_to_group("spikes")
	sprite.texture = TEX_EXACTLYION if use_exactlyion_style else TEX_DEFAULT

	# If not assigned from Inspector, auto-grab a child named "RespawnPoint"
	if respawn_marker == null and has_node("RespawnPoint"):
		respawn_marker = $RespawnPoint
