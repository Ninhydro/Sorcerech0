extends Area2D
class_name LaserTrap

@export var max_length: float = 2000.0          # Max beam distance
@export var instant_kill: bool = true          # One-shot kill
@export var require_player_near: bool = true   # Only work when player nearby

# ON/OFF cycle (seconds at normal time scale)
@export var on_time: float = 1.0               # How long beam stays ON
@export var off_time: float = 1.0              # How long beam stays OFF

# Direction control
@export var use_global_rotation: bool = false  # If true, use node rotation
@export var local_direction: Vector2 = Vector2.RIGHT   # Used if not using rotation

@onready var origin: Marker2D = $LaserOrigin
@onready var sprite: Sprite2D = $Sprite2D
@onready var shape_node: CollisionShape2D = $CollisionShape2D
@onready var detection_area: Area2D = $DetectionArea if has_node("DetectionArea") else null

var player_nearby: bool = false
var beam_on: bool = false
var cycle_timer: float = 0.0


func _ready() -> void:
	# Damage callback
	body_entered.connect(_on_body_entered)
	
	# Detection area (for "player nearby")
	if detection_area:
		detection_area.body_entered.connect(_on_detection_body_entered)
		detection_area.body_exited.connect(_on_detection_body_exited)
	
	# Start in OFF state
	beam_on = false
	cycle_timer = off_time
	sprite.visible = false
	if shape_node:
		shape_node.disabled = true


func _physics_process(delta: float) -> void:
	var ts: float = max(0.0, float(Global.global_time_scale/2))
	var scaled_delta: float = delta * ts
	
	# If we require player near and none is around → always OFF
	if require_player_near and not player_nearby:
		beam_on = false
		sprite.visible = false
		if shape_node:
			shape_node.disabled = true
		return
	
	# --- ON/OFF CYCLE ---
	cycle_timer -= scaled_delta
	if cycle_timer <= 0.0:
		beam_on = not beam_on
		cycle_timer = on_time if beam_on else off_time
	
	# If OFF: hide and disable hitbox
	if not beam_on:
		sprite.visible = false
		if shape_node:
			shape_node.disabled = true
		return
	
	# If ON: show and update beam
	sprite.visible = true
	if shape_node:
		shape_node.disabled = false
	
	_update_beam()


func _update_beam() -> void:
	if origin == null or shape_node == null:
		return
	
	# 1) Direction
	var dir: Vector2
	if use_global_rotation:
		dir = Vector2.RIGHT.rotated(global_rotation).normalized()
	else:
		dir = local_direction.normalized()
	
	# 2) Ray from origin to max_length
	var from: Vector2 = origin.global_position
	var to: Vector2 = from + dir * max_length
	
	var space_state := get_world_2d().direct_space_state
	var params := PhysicsRayQueryParameters2D.create(from, to)
	params.exclude = [self]
	
	var result := space_state.intersect_ray(params)
	
	var hit_distance: float
	if result:
		hit_distance = from.distance_to(result.position)
	else:
		hit_distance = max_length
	
	# 3) CollisionShape2D stretch
	var rect_shape := shape_node.shape as RectangleShape2D
	if rect_shape:
		rect_shape.extents.x = hit_distance * 0.5
		shape_node.position = dir * hit_distance * 0.5
		shape_node.rotation = dir.angle()
	
	# 4) Sprite stretch
	if sprite.texture:
		var tex := sprite.texture
		var tex_width: float = float(max(1, tex.get_width()))
		var scale_x: float = hit_distance / tex_width
		
		sprite.scale.x = scale_x
		sprite.position = dir * hit_distance * 0.5
	else:
		sprite.position = dir * hit_distance * 0.5
	
	sprite.rotation = dir.angle()


func _on_body_entered(body: Node2D) -> void:
	if not beam_on:
		return
	
	if body is Player and body.can_take_damage and not body.dead:
		print("LaserTrap: Player hit by beam!")
		
		if instant_kill:
			Global.health = 0
			body.handle_death()
		else:
			var damage := int(max(1.0, Global.health_max * 0.25))
			body.take_damage(damage)


func _on_detection_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_nearby = true


func _on_detection_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_nearby = false
