extends CharacterBody2D
class_name GawrFlamethrower

@onready var sprite          = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var flame_sprite: AnimatedSprite2D    = $FlameSprite
@onready var flame_area: Area2D                = $FlameArea
@onready var detection_area: Area2D            = $DetectionArea
@onready var flame_block: CollisionShape2D     = $FlameCollider/CollisionShape2D

@export var alert_delay: float = 3.0           # Time standing in range before prepare
@export var damage_per_second: float = 10.0    # Base DPS when time_scale = 1
@export var flip_h: bool = false              # Controls the direction the enemy faces

# --- Attack timing settings ---
@export var min_attack_interval: float = 5.0   # Minimum seconds between attacks
@export var max_attack_interval: float = 30.0  # Maximum seconds between attacks
@export var forced_idle_time: float = 10.0     # Minimum idle time after attacking

# --- Collider grow / slide settings ---
# full position when firing:  (-40, 70)
# idle position when no fire: (50, 70)
@export var collider_idle_position: Vector2 = Vector2(50, 70)
@export var collider_fire_position: Vector2 = Vector2(-40, 70)

# Scale from "no hitbox" to "full"
@export var collider_idle_scale: Vector2 = Vector2(0.0, 1.0)
@export var collider_fire_scale: Vector2 = Vector2(1.0, 1.0)

# How long it takes (in game-time seconds) to go from idle → full
@export var collider_grow_duration: float = 0.2

var collider_grow_t: float = 0.0
var player: Player = null

enum State { IDLE, ALERT, PREPARE, FIRING, ENDING, COOLDOWN }
var state: State = State.IDLE
var state_time: float = 0.0
var attack_timer: float = 0.0
var can_attack: bool = false

# For damage over time
var player_in_flame: bool = false
var damage_accumulator: float = 0.0
var flame_ready: bool = false   # true after "start" finished and "cycle" is running


func _ready() -> void:
	#Global.gawr_dead = true
	# Apply flip setting
	apply_flip()
	
	# Area signals
	detection_area.body_entered.connect(_on_detection_body_entered)
	detection_area.body_exited.connect(_on_detection_body_exited)
	flame_area.body_entered.connect(_on_flame_body_entered)
	flame_area.body_exited.connect(_on_flame_body_exited)
	
	# Animation finished signals
	if animation_player:
		animation_player.animation_finished.connect(_on_body_animation_finished)
	if flame_sprite:
		flame_sprite.animation_finished.connect(_on_flame_animation_finished)
	
	# Ensure collider starts in idle position/scale and disabled
	_apply_collider_transform(0.0)
	flame_block.disabled = true
	
	_set_state(State.IDLE)
	
	# Start with random attack timer
	reset_attack_timer()


func _process(delta: float) -> void:
	# Check if enemy should be disabled
	if Global.gawr_dead == true:
		set_process(false)
		set_physics_process(false)
		visible = false
		detection_area.monitoring = false
		flame_area.monitoring = false
		flame_block.disabled = true
		queue_free()
		return
	else:
		set_process(true)
		set_physics_process(true)
		visible = true
		detection_area.monitoring = true
	
	var scaled_delta := delta * Global.global_time_scale
	
	# Time-scale animations
	if animation_player:
		animation_player.speed_scale = Global.global_time_scale
	if flame_sprite:
		flame_sprite.speed_scale = Global.global_time_scale
	
	if Global.global_time_scale == 0:
		return
	
	state_time += scaled_delta
	
	# Handle attack timer (only when idle and cooldown)
	if state == State.IDLE || state == State.COOLDOWN:
		if not can_attack:
			attack_timer -= scaled_delta
			if attack_timer <= 0:
				can_attack = true
				if state == State.COOLDOWN:
					_set_state(State.IDLE)
	
	var player_visible := _can_see_player()
	
	# --- Animate collider while firing ---
	if state == State.FIRING:
		if collider_grow_duration > 0.0:
			collider_grow_t = clamp(
				collider_grow_t + (scaled_delta / collider_grow_duration),
				0.0,
				1.0
			)
		else:
			collider_grow_t = 1.0
		_apply_collider_transform(collider_grow_t)
	
	match state:
		State.IDLE:
			if player_visible and can_attack:
				_set_state(State.ALERT)
		
		State.ALERT:
			if not player_visible:
				_set_state(State.IDLE)
			elif state_time >= alert_delay:
				_set_state(State.PREPARE)
		
		State.PREPARE:
			# Only cancel if player disappears
			if not player_visible:
				_set_state(State.IDLE)
		
		State.FIRING:
			if not player_visible:
				_set_state(State.ENDING)
			else:
				_handle_flame_damage(scaled_delta)
		
		State.ENDING:
			# Back to idle when flame "stop" animation finishes
			pass
		
		State.COOLDOWN:
			# Forced idle time after attacking
			if state_time >= forced_idle_time:
				reset_attack_timer()
				_set_state(State.IDLE)


func _set_state(new_state: State) -> void:
	state = new_state
	state_time = 0.0
	
	match state:
		State.IDLE:
			if animation_player:
				animation_player.play("idle")
			if flame_sprite:
				flame_sprite.visible = false
			flame_area.set_deferred("monitoring", false)
			flame_block.set_deferred("disabled", true)
			player_in_flame = false
			damage_accumulator = 0.0
			flame_ready = false
			# Reset collider transform
			collider_grow_t = 0.0
			_apply_collider_transform(0.0)
		
		State.ALERT:
			if animation_player:
				animation_player.play("alert")
			flame_area.set_deferred("monitoring", false)
			flame_block.set_deferred("disabled", true)
			collider_grow_t = 0.0
			_apply_collider_transform(0.0)
		
		State.PREPARE:
			if animation_player:
				animation_player.play("prepare")   # body prepare anim
			flame_area.set_deferred("monitoring", false)
			flame_block.set_deferred("disabled", true)
			flame_ready = false
			collider_grow_t = 0.0
			_apply_collider_transform(0.0)
		
		State.FIRING:
			# ENTER FIRING: start the flamethrower "start" animation
			if flame_sprite:
				flame_sprite.visible = true
				flame_sprite.play("start")         # will auto switch to "cycle"
			flame_area.set_deferred("monitoring", true)
			flame_block.set_deferred("disabled", false)         # enable blocking while flame grows
			damage_accumulator = 0.0
			flame_ready = false                  # becomes true when "start" finished
			collider_grow_t = 0.0                # start from idle size/pos
			_apply_collider_transform(0.0)
			can_attack = false                    # Can't attack again immediately
		
		State.ENDING:
			if flame_sprite:
				flame_sprite.play("stop")
			flame_area.set_deferred("monitoring", false)
			flame_block.set_deferred("disabled", true)
			player_in_flame = false
			damage_accumulator = 0.0
			flame_ready = false
			collider_grow_t = 0.0
			_apply_collider_transform(0.0)
		
		State.COOLDOWN:
			# Forced idle time after attacking
			if animation_player:
				animation_player.play("idle")
			if flame_sprite:
				flame_sprite.visible = false
			flame_area.set_deferred("monitoring", false)
			flame_block.set_deferred("disabled", true)
			player_in_flame = false
			damage_accumulator = 0.0
			flame_ready = false
			collider_grow_t = 0.0
			_apply_collider_transform(0.0)


func _apply_collider_transform(t: float) -> void:
	if not flame_block:
		return
	flame_block.position = collider_idle_position.lerp(collider_fire_position, t)
	flame_block.scale    = collider_idle_scale.lerp(collider_fire_scale, t)


func _can_see_player() -> bool:
	if not player or not Global.playerAlive:
		return false
	
	if Global.camouflage:
		return false
	
	return detection_area.overlaps_body(player)


func reset_attack_timer() -> void:
	attack_timer = randf_range(min_attack_interval, max_attack_interval)
	can_attack = false


func apply_flip() -> void:
	# Apply flip to main sprite
	if sprite:
		sprite.flip_h = flip_h
	
	# Apply flip to flame sprite
	if flame_sprite:
		flame_sprite.flip_h = flip_h
	
	# Adjust position offsets based on flip
	if flip_h:
		# Reverse the positions for flipped version
		var temp_idle = collider_idle_position
		var temp_fire = collider_fire_position
		
		# Mirror positions horizontally (assuming 0,0 is center)
		collider_idle_position = Vector2(-temp_idle.x, temp_idle.y)
		collider_fire_position = Vector2(-temp_fire.x, temp_fire.y)


func set_flip_h(value: bool) -> void:
	if flip_h != value:
		flip_h = value
		apply_flip()


# -------------------------------
# Detection area callbacks
# -------------------------------
func _on_detection_body_entered(body: Node) -> void:
	if body is Player and Global.playerAlive:
		player = body


func _on_detection_body_exited(body: Node) -> void:
	if body == player:
		player = null
		if state != State.ENDING:
			call_deferred("_set_state", State.IDLE)


# -------------------------------
# Flame area callbacks
# -------------------------------
func _on_flame_body_entered(body: Node) -> void:
	if body is Player and Global.playerAlive:
		player_in_flame = true


func _on_flame_body_exited(body: Node) -> void:
	if body is Player:
		player_in_flame = false
		damage_accumulator = 0.0


# -------------------------------
# Animation callbacks
# -------------------------------
func _on_body_animation_finished(anim_name: StringName) -> void:
	# When "prepare" body animation finishes, actually start firing
	if anim_name == "prepare" and state == State.PREPARE:
		_set_state(State.FIRING)


func _on_flame_animation_finished() -> void:
	if not flame_sprite:
		return
	
	var anim_name: StringName = flame_sprite.animation
	
	if state == State.FIRING and anim_name == "start":
		# After flame "start" → loop "cycle"
		flame_sprite.play("cycle")
		flame_ready = true
	
	elif state == State.ENDING and anim_name == "stop":
		# After ending anim, go to cooldown state
		flame_sprite.visible = false
		_set_state(State.COOLDOWN)


# -------------------------------
# Damage over time
# -------------------------------
func _handle_flame_damage(scaled_delta: float) -> void:
	if not flame_ready:
		return
	if not player_in_flame or not player or not Global.playerAlive:
		return
	
	damage_accumulator += scaled_delta
	var damage_interval := 1.0  # 10 dmg per 1s game-time
	
	while damage_accumulator >= damage_interval and Global.playerAlive:
		damage_accumulator -= damage_interval
		_apply_damage_to_player(damage_per_second)


func _apply_damage_to_player(amount: float) -> void:
	if not player or not Global.playerAlive:
		return
	
	# Prefer using the player's own damage logic if it exists
	if player.has_method("take_damage"):
		player.take_damage(int(amount))
	else:
		Global.health = max(Global.health - int(amount), 0)
		
		if player.has_signal("health_changed"):
			player.emit_signal("health_changed", Global.health, Global.health_max)
		
		if Global.health <= 0:
			Global.playerAlive = false
			if player.has_method("handle_death"):
				player.handle_death()
