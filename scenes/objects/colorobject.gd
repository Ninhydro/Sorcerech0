# res://scripts/objects/ColorObject.gd
extends TelekinesisObject
class_name ColorObject

enum ColorType {
	RED, BLUE, YELLOW, 
	GREEN, PURPLE, ORANGE, 
	CYAN, MAGENTA, BROWN, 
	WHITE, BLACK, GOLD
}

@export var color_type: ColorType = ColorType.RED

# Spawn / reset
@export var original_position: Vector2
@export var spawn_marker_path: NodePath
var spawn_marker: Marker2D = null

@export var fall_reset_enabled: bool = true
@export var fall_reset_distance: float = 800.0  # how far below original before reset

@onready var collision_shape: CollisionShape2D = $CollisionShape2D


# Mixer-related
var is_in_mixer: bool = false
var is_available_for_mixing: bool = true

# EXPLOSIVE BEHAVIOUR
@export var is_explosive: bool = false
@export var explosion_countdown_time: float = 3.0

@onready var hitbox_area: Area2D = $HitboxArea if has_node("HitboxArea") else null
@onready var explosion_area: Area2D = $ExplosionArea if has_node("ExplosionArea") else null
@onready var countdown_label: Label = $CountdownLabel if has_node("CountdownLabel") else null

var countdown_running: bool = false
var countdown_remaining: float = 0.0

var color_values = {
	ColorType.RED: Color.RED,
	ColorType.BLUE: Color.BLUE,
	ColorType.YELLOW: Color.YELLOW,
	ColorType.GREEN: Color.GREEN,
	ColorType.PURPLE: Color(0.5, 0, 0.5),
	ColorType.ORANGE: Color(1, 0.5, 0),
	ColorType.CYAN: Color(0, 1, 1),
	ColorType.MAGENTA: Color(1, 0, 1),
	ColorType.BROWN: Color(0.6, 0.3, 0),
	ColorType.WHITE: Color.WHITE,
	ColorType.BLACK: Color.BLACK,
	ColorType.GOLD: Color.GOLD
}

func _ready():
	add_to_group("TelekinesisObject")
	
	# Resolve spawn marker if set
	if spawn_marker_path != NodePath():
		var node = get_node_or_null(spawn_marker_path)
		if node and node is Marker2D:
			spawn_marker = node
			original_position = spawn_marker.global_position
		else:
			push_warning("ColorObject %s: spawn_marker_path does not point to a Marker2D" % name)
	
	# If no original_position set, use current
	if original_position == Vector2.ZERO:
		original_position = global_position
	
	update_appearance()
	
	if sprite:
		if sprite.material != null:
			sprite.material.set_shader(null)
			sprite.material = null
	else:
		print("ERROR: No Sprite2D node found for object: ", name)
	
	# Explosive hooks
	if hitbox_area:
		hitbox_area.area_entered.connect(_on_hitbox_area_entered)
	
	if countdown_label:
		countdown_label.visible = false

	# Make sure objects spawn unfrozen
	is_in_mixer = false
	is_available_for_mixing = true
	if collision_shape:
		collision_shape.disabled = false
	freeze = false


func _process(delta: float) -> void:
	# Relative fall reset from original_position, not hardcoded y=2000
	if fall_reset_enabled:
		if global_position.y > original_position.y + fall_reset_distance:
			reset_to_original()
	
	# Handle explosive countdown
	if countdown_running:
		countdown_remaining -= delta * Global.global_time_scale
		if countdown_remaining < 0:
			countdown_remaining = 0
		
		if countdown_label:
			countdown_label.visible = true
			countdown_label.text = str(round(countdown_remaining * 10.0) / 10.0)  # 1 decimal
		
		if countdown_remaining <= 0.0:
			countdown_running = false
			_explode()


# ===== Telekinesis basic controls =====

func start_levitation(player_pos: Vector2):
	is_controlled = true
	offset = position - player_pos

func update_levitation(player_pos: Vector2):
	if Input.is_action_pressed("move_right"):
		linear_velocity.x += 1
	if Input.is_action_pressed("move_left"):
		linear_velocity.x -= 1
	if Input.is_action_pressed("move_up"):
		linear_velocity.y -= 1
	if Input.is_action_pressed("move_down"):
		linear_velocity.y += 1

func stop_levitation():
	is_controlled = false


# ===== Visual / color =====

func update_appearance():
	if not sprite:
		return
	
	if is_explosive:

		sprite.modulate = Color.WHITE
		return
	
	if color_type == ColorType.GOLD:
		var gold_texture = preload("res://assets_image/Objects/collect_objects6.png")
		sprite.texture = gold_texture
		sprite.modulate = Color.WHITE
	else:
		sprite.modulate = color_values[color_type]


func get_color_type():
	return color_type

func set_color_type(new_type: ColorType):
	color_type = new_type
	update_appearance()


# ===== Mixer integration =====

func set_is_in_mixer(in_mixer: bool):
	is_in_mixer = in_mixer
	is_available_for_mixing = !in_mixer
	if sprite:
		sprite.visible = !in_mixer
	call_deferred("_deferred_set_physics", in_mixer)

func _deferred_set_physics(in_mixer: bool):
	if collision_shape:
		collision_shape.disabled = in_mixer
	freeze = in_mixer


# ===== Reset position =====

func reset_to_original():
	global_position = original_position
	linear_velocity = Vector2.ZERO
	angular_velocity = 0
	set_is_in_mixer(false)
	freeze = false


# ===== EXPLOSIVE API =====

func make_explosive(time: float = 3.0):
	is_explosive = true
	explosion_countdown_time = time
	update_appearance()


func _on_hitbox_area_entered(area: Area2D) -> void:
	if not is_explosive:
		return
	
	# Attack hitbox starts the countdown
	if area == Global.playerDamageZone and not countdown_running:
		_start_countdown()


func _start_countdown():
	countdown_running = true
	countdown_remaining = explosion_countdown_time
	if countdown_label:
		countdown_label.visible = true


func _explode():
	print("ColorObject: EXPLOSION at ", global_position)
	
	# Hide self visual
	if sprite:
		sprite.visible = false
	
	# Affect everything in explosion_area
	if explosion_area:
		# bodies
		for body in explosion_area.get_overlapping_bodies():
			if body and is_instance_valid(body):
				if body is ExplosiveDoor or body.is_in_group("ExplosiveDoor"):
					body.on_explosive_hit()
		
		# areas if needed (optional)
		for ar in explosion_area.get_overlapping_areas():
			if ar and is_instance_valid(ar):
				if  ar.is_in_group("ExplosiveDoor"):
					ar.on_explosive_hit()
	

	
	# Finally remove the bomb
	queue_free()
