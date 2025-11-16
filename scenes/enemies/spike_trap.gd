extends Area2D
class_name SpikeTrap

@export var damage_percentage: float = 5.0

const TEX_EXACTLYION := preload("res://assets_image/Objects/SpikeStrip1.png")
const TEX_DEFAULT    := preload("res://assets_image/Objects/SpikeStrip2.png")

@onready var sprite: Sprite2D = $Sprite2D
@export var use_exactlyion_style: bool = false

func _ready():
	add_to_group("spikes")
	sprite.texture = TEX_EXACTLYION if use_exactlyion_style else TEX_DEFAULT
	
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D):
	if body is Player and body.can_take_damage and not body.dead:
		print("Spike: Player hit!")
		body.respawn_nearby_spike()
		
		
