extends Node2D
class_name BaseNPC

@onready var anim: AnimationPlayer = $AnimationPlayer

func cutscene_play(anim_name: String):
	anim.play(anim_name)
