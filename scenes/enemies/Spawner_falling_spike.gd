extends Node2D
class_name FallingSpikeTrap

@export var spawn_interval: float = 5.0
@export var only_when_player_near: bool = true

@onready var detection_area: Area2D = $DetectionArea
@onready var spawn_point: Marker2D = $SpawnPoint
@onready var spike: FallingSpike = $FallingSpike

var player_nearby: bool = false
var cooldown_left: float = 0.0


func _ready() -> void:
	if detection_area:
		detection_area.body_entered.connect(_on_detection_body_entered)
		detection_area.body_exited.connect(_on_detection_body_exited)
	
	cooldown_left = 0.0
	
	if spike:
		spike._deactivate()  # or spike.reset_inactive() if you rename it


func _physics_process(delta: float) -> void:
	var ts: float = max(0.0, float(Global.global_time_scale))
	var scaled_delta: float = delta * ts
	
	if only_when_player_near and not player_nearby:
		return
	
	cooldown_left -= scaled_delta
	
	if cooldown_left <= 0.0:
		_spawn_or_reactivate_spike()
		cooldown_left = spawn_interval


func _spawn_or_reactivate_spike() -> void:
	if spike == null:
		print("FallingSpikeTrap: spike node missing")
		return
	
	var world_pos: Vector2 = spawn_point.global_position if spawn_point else global_position
	spike.activate_at(world_pos)
	print("FallingSpikeTrap: spike activated at ", world_pos)


func _on_detection_body_entered(body: Node2D) -> void:
	if body is Player or body.is_in_group("player"):
		player_nearby = true


func _on_detection_body_exited(body: Node2D) -> void:
	if body is Player or body.is_in_group("player"):
		player_nearby = false
