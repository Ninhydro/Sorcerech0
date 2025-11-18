extends Area2D
class_name EnemyProjectile

@export var speed = 150.0
@export var damage = 10
@export var lifetime = 2.0

var direction = Vector2.RIGHT
@onready var timer = $Timer
@onready var sprite = $Sprite2D
@onready var collision_shape = $CollisionShape2D

func _ready():
	# Connect ONLY body_entered signal like the spike trap
	body_entered.connect(_on_body_entered)
	
	# Enable collision after a small delay to avoid self-collision
	await get_tree().create_timer(0.1).timeout
	collision_shape.disabled = false

	# Set up lifetime timer
	timer.wait_time = lifetime
	timer.one_shot = true
	timer.start()
	timer.timeout.connect(_on_lifetime_timeout)

	# Flip sprite based on direction
	update_sprite_direction()

func _physics_process(delta):
	position += direction * speed * delta

func _on_body_entered(body: Node2D):
	# Simple detection like spike trap
	if body is Player and body.can_take_damage and not body.dead:
		print("Projectile hit player!")
		body.take_damage(damage)
		queue_free()
	elif body is TileMap:
		print("Projectile hit wall")
		queue_free()

func _on_lifetime_timeout():
	queue_free()

func set_direction(dir: Vector2):
	direction = dir.normalized()
	update_sprite_direction()

func update_sprite_direction():
	if direction.x < 0:
		sprite.flip_h = true
	else:
		sprite.flip_h = false
