extends CharacterBody2D



@onready var sprite_2d: Sprite2D = $NPC
@onready var animation_player: AnimationPlayer = $NPC/AnimationPlayer


func _ready():
	
	if Global.timeline >= 6:
		visible = true
		animation_player.play("walk")
	else:
		visible = false
func _process(delta):
	if Global.route_status == "Cyber":
		visible = false
