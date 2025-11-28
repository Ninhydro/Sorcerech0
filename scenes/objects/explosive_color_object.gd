# res://scripts/objects/ExplosiveColorObject.gd
extends ColorObject
class_name ExplosiveColorObject

@export var fuse_time: float = 3.0  # seconds before explosion

@onready var hitbox: Area2D = $Hitbox
#@onready var countdown_label: Label = $CountdownLabel
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var fuse_time_left: float = 0.0
var is_armed: bool = false
var door_ref: ExplosiveDoor = null

func _ready():
	# Call ColorObject._ready()
	super._ready()
	
	# Just in case, make sure it can fall normally
	freeze = false
	
	if hitbox and not hitbox.area_entered.is_connected(_on_hitbox_area_entered):
		hitbox.area_entered.connect(_on_hitbox_area_entered)
	
	if countdown_label:
		countdown_label.visible = false
	
	# Try to find the ExplosiveDoor up the tree automatically
	_find_explosive_door()

	set_process(false)  # we only process when armed


func _find_explosive_door():
	var node: Node = get_parent()
	while node:
		if node is ExplosiveDoor:
			door_ref = node
			print("ExplosiveObject: Found door ref: ", door_ref.name)
			return
		node = node.get_parent()
	print("ExplosiveObject: No ExplosiveDoor found in parents!")


func _on_hitbox_area_entered(area: Area2D) -> void:
	# Player attack area
	if area == Global.playerDamageZone and not is_armed:
		arm_bomb()


func arm_bomb():
	is_armed = true
	fuse_time_left = fuse_time
	set_process(true)
	
	if countdown_label:
		countdown_label.visible = true
		countdown_label.text = str(int(ceil(fuse_time_left)))
	
	if animation_player and animation_player.has_animation("activate"):
		animation_player.play("activate")
	
	print("ExplosiveObject: Bomb armed, fuse_time = ", fuse_time)


func _process(delta: float) -> void:
	if not is_armed:
		return
	
	# Respect global time scale (slow time skill)
	var scaled_delta := delta * Global.global_time_scale
	fuse_time_left -= scaled_delta
	
	if countdown_label:
		var display_time: int = max(0, int(ceil(fuse_time_left)))
		countdown_label.text = str(display_time)
	
	if fuse_time_left <= 0.0:
		explode()


func explode():
	if not is_armed:
		return
	is_armed = false
	set_process(false)
	
	print("ExplosiveObject: BOOM!")
	
	# Optional explosion animation
	if animation_player and animation_player.has_animation("explode"):
		animation_player.play("explode")
		await animation_player.animation_finished
	
	# Tell the door it was hit
	if door_ref:
		door_ref.on_explosive_hit()
	else:
		print("ExplosiveObject: No door_ref to notify – check parent hierarchy.")
	
	queue_free()
