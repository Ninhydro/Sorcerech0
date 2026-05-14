extends CharacterBody2D

@onready var sprite_2d: Sprite2D = $NPC
@onready var animation_player: AnimationPlayer = $NPC/AnimationPlayer
@onready var interaction_area: Area2D = $InteractionArea
@onready var bubble_timer: Timer = $BubbleTimer

# Configuration
#@export var dialog_timeline1: String = "betael1"
#@export var dialog_timeline2: String = "alyra2"


@export var bubble_texts: Array[String] = [
	#"Ah You're back",
	#"Need something?",
	#"Old Uncle Betael here to help"
]
@export var bubble_interval_min: float = 5.0
@export var bubble_interval_max: float = 15.0
@export var speech_bubble_scene: PackedScene  # Drag SpeechBubble.tscn here
@export var bubble_y_offset: float = -100  # Adjust this to position bubble higher/lower
@export var bubble_x_offset: float = 0    # Horizontal adjustment

# Dialog state management
var is_dialog_active: bool = false
var can_interact: bool = true
var interaction_cooldown: float = 0.0
var play_once: bool = false
var player_in_range: bool = false 
var current_bubble = null  # Track current bubble instance

#@export var sprites_for_timeline: Array[Texture2D] = [] 



#func update_sprite_by_timeline():
#	if sprites_for_timeline.size() >= Global.timeline and sprites_for_timeline[Global.timeline-1]:
#		sprite_2d.texture = sprites_for_timeline[Global.timeline-1]

#func _on_choice_made(choice_data: Dictionary):
#	var choice_id = choice_data.get("id", "")
#	if choice_id == "":
#		choice_id = choice_data.get("text", "")
	
#	if not Global.npc_choice_memory.has(name):
#		Global.npc_choice_memory[name] = {}
#	Global.npc_choice_memory[name][Global.timeline] = choice_id
#	print("Stored choice ", choice_id, " for ", name, " timeline ", Global.timeline)


#if Global.npc_choice_memory.get("Uncle Betael", {}).get(7, "") == "A":
	#print("Betael was helped on timeline 7")

#if "A" in Global.npc_choice_memory.get("Uncle Betael", {}).values():

func _ready():
	#print("NPC _ready called")
	# Initially hide the NPC
	visible = true
	sprite_2d.flip_h = false
	animation_player.play("idle")
