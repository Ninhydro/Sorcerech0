extends Node2D

@onready var maya: Sprite2D = $"Maya kid"
@onready var anim: AnimationPlayer = $"Maya kid/AnimationPlayer"
@onready var marker1: Marker2D = $Marker2D
@onready var marker2: Marker2D = $Marker2D2

var _has_been_triggered: bool = false
var _is_moving: bool = false

func _ready():
	maya.visible = false

func _process(delta):
	if Global.cutscene_finished1 == true and not _has_been_triggered and not _is_moving:
		_is_moving = true
		_start_maya_movement()

func _start_maya_movement():
	# Reset Maya to starting position
	maya.visible = true
	maya.position = marker1.position
	#maya.flip_h = true
	# Play run animation
	anim.play("run2")
	
	# Create a tween to move Maya from marker1 to marker2
	var tween = create_tween()
	tween.tween_property(maya, "position", marker2.position, 5.0) # Adjust duration as needed
	
	# When tween completes, hide Maya
	tween.tween_callback(_on_movement_finished)

func _on_movement_finished():
	maya.visible = false
	_has_been_triggered = true
	_is_moving = false
	Global.cutscene_finished1 = false
	
