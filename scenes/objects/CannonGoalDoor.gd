# res://scripts/objects/CannonGoalDoor.gd
extends StaticBody2D
class_name CannonGoalDoor

@export var required_speed: float = 300.0  # Minimum velocity length to count as a cannon hit

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var hit_area: Area2D = $HitArea
@onready var hit_shape: CollisionShape2D = $HitArea/CollisionShape2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer if has_node("AnimationPlayer") else null

var destroyed: bool = false

func _process(delta):
	if $AnimationPlayer:
		$AnimationPlayer.speed_scale = Global.global_time_scale
		
func _ready() -> void:
	# Listen for player hitting the door
	if hit_area:
		hit_area.body_entered.connect(_on_hit_area_body_entered)
	
	# If already destroyed in a previous session, apply destroyed state
	if Global.cannon_goal_door_destroyed:
		destroyed = true
		_apply_destroyed_state()
		print("CannonGoalDoor: Already destroyed (from Global flag), disabling door.")
	else:
		print("CannonGoalDoor: Active, waiting for cannon hit.")


func _on_hit_area_body_entered(body: Node2D) -> void:
	if destroyed:
		return
	
	if body is Player:
		var player := body as Player
		
		# Only react if player is in cannon-flight mode
		if player.is_launched:
			var speed := player.velocity.length()
			print("CannonGoalDoor: Player hit door in cannon mode. Speed = ", speed)
			
			if speed >= required_speed:
				_explode_from_cannon_hit(player)
			else:
				print("CannonGoalDoor: Hit too slow, ignoring.")


func _explode_from_cannon_hit(player: Player) -> void:
	if destroyed:
		return
	
	destroyed = true
	Global.cannon_goal_door_destroyed = true
	print("CannonGoalDoor: Hit by cannon-shot player → exploding door.")

	# Optionally stop cannon mode immediately for the player
	player.is_launched = false
	player.canon_enabled = false
	player.scale = Vector2(1, 1)
	# Use the normal mask again so they behave like normal
	player.collision_mask = player.normal_collision_mask
	
	# Play explode anim if available
	if animation_player and animation_player.has_animation("explode"):
		animation_player.play("explode")
		await animation_player.animation_finished
	
	_apply_destroyed_state()


func _apply_destroyed_state() -> void:
	# Disable physics blocking
	if collision_shape:
		collision_shape.disabled = true
	# Disable hit detection too
	if hit_shape:
		hit_shape.disabled = true
	# Hide the door visually
	if sprite:
		sprite.visible = false
	
	# Optional: stop processing entirely
	# set_physics_process(false)
	# set_process(false)
