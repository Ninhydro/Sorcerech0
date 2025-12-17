extends Area2D
class_name LaserColumn

@export var damage := 16  # Changed from 999 to match surround_laser_damage
@export var max_length := 3000.0

@onready var sprite := $Sprite2D
@onready var shape := $CollisionShape2D

var active := false

func _ready() -> void:
	_disable()
	# Make sure sprite is visible when activated
	if sprite:
		sprite.visible = false
		sprite.modulate = Color(1, 0.3, 0.3, 0.9)  # Red laser

func activate() -> void:
	active = true
	if sprite:
		sprite.visible = true
	if shape:
		shape.disabled = false
	print("⚡ LaserColumn ACTIVATED at: ", global_position)

func deactivate() -> void:
	active = false
	if sprite:
		sprite.visible = false
	if shape:
		shape.disabled = true

func _disable() -> void:
	active = false
	if sprite:
		sprite.visible = false
	if shape:
		shape.disabled = true

func _on_body_entered(body: Node) -> void:
	if not active:
		return
	if body.has_method("take_damage"):
		print("⚡ LaserColumn hit player!")
		body.take_damage(damage)
