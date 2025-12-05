extends Area2D
class_name ReplicaFiniLaser

@export var length: float = 1000.0   # how far it stretches
@export var damage: int = 20

@onready var sprite: Sprite2D = $Sprite2D
@onready var shape_node: CollisionShape2D = $CollisionShape2D

var _dir_sign: int = 1
var _active: bool = false


func _ready() -> void:
	visible = false
	monitoring = false
	body_entered.connect(_on_body_entered)


func fire(direction_sign: int = 1) -> void:
	# 1 or -1
	_dir_sign = direction_sign if direction_sign != 0 else 1
	_active = true
	visible = true
	monitoring = true
	_build_beam()


func stop() -> void:
	_active = false
	visible = false
	monitoring = false


func _build_beam() -> void:
	var half_len: float = length * 0.5

	# --- CollisionShape stretch ---
	if shape_node and shape_node.shape is RectangleShape2D:
		var rect_shape: RectangleShape2D = shape_node.shape
		# keep current height (extents.y), only change width (extents.x)
		rect_shape.extents = Vector2(half_len, rect_shape.extents.y)
		shape_node.position = Vector2(half_len * _dir_sign, 0.0)
		shape_node.rotation = 0.0

	# --- Sprite stretch ---
	if sprite and sprite.texture:
		var tex_width = max(1.0, float(sprite.texture.get_width()))
		var sx: float = (length / tex_width) * _dir_sign
		sprite.scale.x = sx
		sprite.position = Vector2(half_len * _dir_sign, 0.0)
		sprite.rotation = 0.0
	elif sprite:
		sprite.position = Vector2(half_len * _dir_sign, 0.0)
		sprite.rotation = 0.0


func _on_body_entered(body: Node2D) -> void:
	if not _active:
		return

	if body is Player and body.can_take_damage and not body.dead:
		body.take_damage(damage)
