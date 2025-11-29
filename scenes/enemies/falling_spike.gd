extends CharacterBody2D
class_name FallingSpike

@export var gravity: float = 1000.0
@export var max_fall_speed: float = 1500.0
@export var damage: int = 10
@export var lifetime: float = 10.0
@export var knockback_force: float = 200.0

@onready var hitbox_area: Area2D = $Hitbox
@onready var body_collision: CollisionShape2D = $CollisionShape2D

var life_left: float = 0.0
var is_active: bool = false


func _ready() -> void:
	if hitbox_area:
		hitbox_area.body_entered.connect(_on_hitbox_body_entered)
	
	# Start inactive
	_deactivate()


func _physics_process(delta: float) -> void:
	if not is_active:
		return
	
	var ts: float = max(0.0, float(Global.global_time_scale))
	var scaled_delta: float = delta * ts
	
	# Gravity with time-scale
	velocity.y = min(velocity.y + gravity * scaled_delta, max_fall_speed)
	move_and_slide()
	
	# Hit floor → deactivate
	if is_on_floor():
		_deactivate()
		return
	
	# Lifetime timeout
	life_left -= scaled_delta
	if life_left <= 0.0:
		_deactivate()


func activate_at(world_position: Vector2) -> void:
	# Called by the trap to reuse this spike
	global_position = world_position
	velocity = Vector2.ZERO
	life_left = lifetime
	is_active = true
	
	show()
	
	# Enable collisions (deferred to be safe even if called from signals later)
	if body_collision:
		body_collision.set_deferred("disabled", false)
	if hitbox_area:
		hitbox_area.set_deferred("monitoring", true)


func _deactivate() -> void:
	is_active = false
	velocity = Vector2.ZERO
	hide()
	
	# Disable physics + damage (deferred avoids “locked” errors)
	if body_collision:
		body_collision.set_deferred("disabled", true)
	if hitbox_area:
		hitbox_area.set_deferred("monitoring", false)


func _on_hitbox_body_entered(body: Node2D) -> void:
	if not is_active:
		return
	
	if body is Player and body.can_take_damage and not body.dead:
		print("FallingSpike: hit player")
		
		var dir: Vector2 = (body.global_position - global_position).normalized()
		if dir == Vector2.ZERO:
			dir = Vector2.DOWN
		
		Global.enemyAknockback = dir * knockback_force
		body.take_damage(damage)
		
		_deactivate()
