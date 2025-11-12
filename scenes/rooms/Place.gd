# AreaDetector.gd - Attach to World scene or individual Area2D nodes
extends Area2D

@export var area_name: String = ""
@export var chunk_name: String = ""
@export var pause_player_tracking: bool = false  # Control player tracking in this area

#Global.timeline >= 5 and Global.timeline <= 6

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D):
	if body == Global.player:
		Global.set_current_area(area_name)
		print("Player entered: ", area_name)
		Cartographer.reveal_chunk(chunk_name)
		if pause_player_tracking:
			Global.tracking_paused = true
			print("Player tracking PAUSED in area: ", area_name)

func _on_body_exited(body: Node2D):
	if body == Global.player:
		print("Player exited: ", area_name)
		#Cartographer.reveal_chunk(chunk_name)
		if pause_player_tracking:
			Global.tracking_paused = false
			print("Player tracking RESUMED after leaving: ", area_name)

