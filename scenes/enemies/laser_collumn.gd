extends Area2D
class_name LaserColumn

@export var damage := 999
@export var max_length := 3000.0

@onready var sprite := $Sprite2D
@onready var shape := $CollisionShape2D

var active := false

func _ready() -> void:
	_disable()

func activate() -> void:
	active = true
	sprite.visible = true
	shape.disabled = false

func deactivate() -> void:
	_disable()

func _disable() -> void:
	active = false
	sprite.visible = false
	shape.disabled = true

func _on_body_entered(body: Node) -> void:
	if not active:
		return
	if body is Player and body.can_take_damage and not body.dead:
		body.handle_death()
