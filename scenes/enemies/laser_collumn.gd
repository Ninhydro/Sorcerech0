extends Area2D
class_name LaserColumn

@export var damage := 16
@export var max_length := 3000.0
@export var extend_duration := 0.5  # Time to fully extend from top to bottom
@export var retract_duration := 0.3  # Time to retract when deactivating

@onready var sprite := $Sprite2D
@onready var shape := $CollisionShape2D
@onready var origin := $LaserOrigin  # Add a Marker2D child node called "LaserOrigin"

var active := false
var current_length := 0.0
var target_length := 0.0
var extend_speed := 0.0
var direction := Vector2.DOWN  # Default: shoots downward

func _ready() -> void:
	_disable()
	body_entered.connect(_on_body_entered)
	if sprite:
		sprite.visible = false
		sprite.modulate = Color(1, 0.3, 0.3, 0.9)
	
	# Make sure we have an origin marker
	if not origin:
		origin = Marker2D.new()
		origin.name = "LaserOrigin"
		origin.position = Vector2.ZERO
		add_child(origin)

func activate() -> void:
	active = true
	target_length = max_length
	extend_speed = max_length / (extend_duration / _get_time_scale())
	current_length = 0.0
	
	if sprite:
		sprite.visible = true
		_update_beam_appearance()
	
	print("⚡ LaserColumn ACTIVATING at: ", global_position)

func deactivate() -> void:
	active = false
	target_length = 0.0
	extend_speed = max_length / (retract_duration / _get_time_scale())
	
	# If we want immediate deactivation instead of retracting:
	# _disable()

func _disable() -> void:
	active = false
	current_length = 0.0
	target_length = 0.0
	if sprite:
		sprite.visible = false
	if shape:
		shape.disabled = true

func _process(delta: float) -> void:
	if not active and current_length <= 0:
		return
	
	# Update length with time scaling
	var ts = _get_time_scale()
	var scaled_delta = delta * ts
	
	# Animate length change
	if active and current_length < target_length:
		current_length = min(target_length, current_length + (extend_speed * scaled_delta))
		_update_beam_appearance()
	elif not active and current_length > target_length:
		current_length = max(target_length, current_length - (extend_speed * scaled_delta))
		_update_beam_appearance()
		
		# Fully retracted
		if current_length <= 0:
			_disable()

func _update_beam_appearance() -> void:
	if not sprite or not shape or not origin:
		return
	
	# Update collision shape
	if shape:
		var rect_shape = shape.shape as RectangleShape2D
		if rect_shape:
			rect_shape.extents.x = current_length * 0.5
			shape.position = direction * current_length * 0.5
			shape.rotation = direction.angle()
			shape.disabled = (current_length <= 0)
	
	# Update sprite
	if sprite.texture:
		var tex_width = float(max(1, sprite.texture.get_width()))
		var scale_x = current_length / tex_width
		sprite.scale.x = scale_x
		sprite.position = direction * current_length * 0.5
		sprite.rotation = direction.angle()
		sprite.visible = (current_length > 0)
	else:
		sprite.position = direction * current_length * 0.5
		sprite.rotation = direction.angle()
		sprite.visible = (current_length > 0)

func _get_time_scale() -> float:
	if Global and has_method("global_time_scale"):
		return max(0.0, float(Global.global_time_scale / 2))
	return 1.0

func _on_body_entered(body: Node) -> void:
	if not active or current_length <= 0:
		return
	if body is Player and body.can_take_damage and not body.dead:
		body.take_damage(damage)
