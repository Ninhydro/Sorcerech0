extends Area2D

@export var speed := 200.0
@export var damage := 10
var direction := Vector2.RIGHT

func _ready():
	# Auto-remove after 3 seconds to prevent memory leaks
	await get_tree().create_timer(3.0).timeout
	queue_free()

func _physics_process(delta):
	position += direction * speed * delta

func _on_body_entered(body):
	if body.is_in_group("player"):
		body.take_damage(damage)
		queue_free()
	
	# Also destroy when hitting walls
	if body is TileMap:
		queue_free()
