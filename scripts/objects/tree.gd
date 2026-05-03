extends Sprite2D

@onready var anim: AnimationPlayer = $AnimationPlayer
# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	
	if Global.timeline <6:
		anim.play("idle1")
	elif Global.timeline >= 6 or Global.timeline < 8:
		anim.play("idle2")
	elif Global.timeline >= 8 or Global.timeline < 10:
		anim.play("idle4")
	elif Global.timeline >= 10:
		anim.play("idle3")
		
