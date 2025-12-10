extends CharacterBody2D
class_name GawrBoss

signal boss_died

# -------------------------------------------------------------
# CONFIG
# -------------------------------------------------------------
@export var max_health: int = 300
@export var walk_speed: float = 60.0
@export var engage_distance: float = 500.0

@export var slam_damage: int = 10
@export var fire_damage: int = 15

var health: int
var dead: bool = false
var taking_damage: bool = false

var player: Node2D

# -------------------------------------------------------------
# NODES
# -------------------------------------------------------------
@onready var anim: AnimationPlayer = $AnimationPlayer

@onready var sprite_body: Sprite2D = $SpriteBody
@onready var sprite_head: Sprite2D = $Head/HeadSprite

@onready var head: Node2D = $Head
@onready var head_weakspot: Area2D = $Head/HeadWeakspot

@onready var left_hand: Node2D = $LeftArm/LeftHand
@onready var left_hitbox: Area2D = $LeftArm/LeftHand/LeftSlamHitbox
@onready var left_weakspot: Area2D = $LeftArm/LeftHand/LeftWeakspot

@onready var right_hand: Node2D = $RightArm/RightHand
@onready var right_hitbox: Area2D = $RightArm/RightHand/RightSlamHitbox
@onready var right_weakspot: Area2D = $RightArm/RightHand/RightWeakspot

@onready var fire_pivot: Node2D = $FirePivot
@onready var fire_sprite: Sprite2D = $FirePivot/FireSprite
@onready var fire_hitbox: Area2D = $FirePivot/FireHitbox

# -------------------------------------------------------------
# READY
# -------------------------------------------------------------
func _ready():
	health = max_health
	_disable_all_hitboxes()
	_disable_all_weakspots()
	fire_sprite.visible = false

	# Connect weakspot callbacks
	_connect_weakspot(head_weakspot)
	_connect_weakspot(left_weakspot)
	_connect_weakspot(right_weakspot)

	# Connect attack callbacks
	left_hitbox.body_entered.connect(_on_attack_hitbox_body_entered)
	right_hitbox.body_entered.connect(_on_attack_hitbox_body_entered)
	fire_hitbox.body_entered.connect(_on_attack_hitbox_body_entered)

	set_physics_process(false)
	set_process(false)


func reset_for_battle():
	dead = false
	taking_damage = false
	health = max_health
	_disable_all_hitboxes()
	_disable_all_weakspots()

	fire_sprite.visible = false

	set_physics_process(true)
	set_process(true)

	_run_ai_loop()

# -------------------------------------------------------------
# MASTER AI LOOP
# -------------------------------------------------------------
func _run_ai_loop() -> void:
	while not dead:
		await _idle_phase()
		if dead: return

		# Movement toward player if too far
		if player and abs(player.global_position.x - global_position.x) > engage_distance:
			await _move_closer_phase()
			continue  # re-evaluate distance after moving

		# choose slam or fire
		var pick := randi() % 2
		if pick == 0:
			await _slam_phase()
		else:
			await _fire_breath_phase()

		# Loop back to idle


# -------------------------------------------------------------
# PHASES
# -------------------------------------------------------------
func _idle_phase() -> void:
	if anim.has_animation("idle"):
		anim.play("idle")

	await get_tree().create_timer(0.8).timeout


func _move_closer_phase() -> void:
	if not player:
		return

	if anim.has_animation("walk"):
		anim.play("walk")

	var dx := player.global_position.x - global_position.x
	var dir := -1 if dx < 0 else 1

	var duration := 1.0
	var t := 0.0

	while t < duration and not dead:
		global_position.x += dir * walk_speed * get_physics_process_delta_time()
		t += get_physics_process_delta_time()
		await get_tree().process_frame


# -------------------------------------------------------------
# SLAM ATTACK
# -------------------------------------------------------------
func _slam_phase() -> void:
	if dead: return

	var use_left := (randi() % 2 == 0)
	var hand := left_hand if use_left else right_hand
	var hitbox := left_hitbox if use_left else right_hitbox
	var weakspot := left_weakspot if use_left else right_weakspot

	# PREP ANIMATION
	if anim:
		if use_left and anim.has_animation("slam_left"):
			anim.play("slam_left")
		elif not use_left and anim.has_animation("slam_right"):
			anim.play("slam_right")

	await get_tree().create_timer(0.35).timeout
	if dead: return

	# IMPACT
	_enable_hitbox(hitbox)
	_enable_weakspot(weakspot)

	# HAND STAYS ON GROUND VULNERABLE
	await get_tree().create_timer(1.8).timeout

	_disable_hitbox(hitbox)
	_disable_weakspot(weakspot)

	# RETURN ANIMATION
	if anim.has_animation("slam_return"):
		anim.play("slam_return")

	await get_tree().create_timer(0.6).timeout


# -------------------------------------------------------------
# FIRE BREATH
# -------------------------------------------------------------
func _fire_breath_phase() -> void:
	if dead: return

	# LOWER HEAD
	if anim.has_animation("breath_lower"):
		anim.play("breath_lower")
	await get_tree().create_timer(0.4).timeout
	if dead: return

	# FIRE START
	fire_sprite.visible = true
	_enable_hitbox(fire_hitbox)

	if anim.has_animation("breath_fire"):
		anim.play("breath_fire")

	await get_tree().create_timer(1.0).timeout  # FIRE DURATION
	if dead: return

	# FIRE STOP
	fire_sprite.visible = false
	_disable_hitbox(fire_hitbox)

	# HEAD WEAKSPOT OPENS
	_enable_weakspot(head_weakspot)

	# RECOVER (head rises)
	if anim.has_animation("breath_recover"):
		anim.play("breath_recover")

	await get_tree().create_timer(0.8).timeout

	_disable_weakspot(head_weakspot)


# -------------------------------------------------------------
# DAMAGE SYSTEM
# -------------------------------------------------------------
func take_damage(amount: int) -> void:
	if dead:
		return

	health -= amount
	taking_damage = true

	if anim.has_animation("hurt"):
		anim.play("hurt")

	await get_tree().create_timer(0.3).timeout
	taking_damage = false

	if health <= 0:
		_die()


func _die():
	dead = true
	_disable_all_hitboxes()
	_disable_all_weakspots()
	fire_sprite.visible = false

	if anim.has_animation("die"):
		anim.play("die")

	# OPTIONAL: body rotation collapse
	var fall_time := 0.6
	var t := 0.0
	var start_rot := rotation
	var end_rot := deg_to_rad(90)

	while t < fall_time:
		var alpha := t / fall_time
		rotation = lerp(start_rot, end_rot, alpha)
		t += get_physics_process_delta_time()
		await get_tree().process_frame

	boss_died.emit()


# -------------------------------------------------------------
# HITBOX / WEAKSPOT HELPERS
# -------------------------------------------------------------
func _connect_weakspot(spot: Area2D) -> void:
	if not spot.area_entered.is_connected(_on_weakspot_entered):
		spot.area_entered.connect(_on_weakspot_entered)

func _enable_hitbox(box: Area2D):
	var shape := box.get_node("CollisionShape2D")
	shape.disabled = false

func _disable_hitbox(box: Area2D):
	var shape := box.get_node("CollisionShape2D")
	shape.disabled = true

func _disable_all_hitboxes():
	_disable_hitbox(left_hitbox)
	_disable_hitbox(right_hitbox)
	_disable_hitbox(fire_hitbox)

func _enable_weakspot(ws: Area2D):
	var shape := ws.get_node("CollisionShape2D")
	shape.disabled = false

func _disable_weakspot(ws: Area2D):
	var shape := ws.get_node("CollisionShape2D")
	shape.disabled = true

func _disable_all_weakspots():
	_disable_weakspot(head_weakspot)
	_disable_weakspot(left_weakspot)
	_disable_weakspot(right_weakspot)


func _on_attack_hitbox_body_entered(body):
	if dead: return
	if body.is_in_group("player"):
		body.take_damage(slam_damage)


func _on_weakspot_entered(area):
	if dead: return
	if not area.is_in_group("player_attack"):
		return

	var dmg := 10
	if "damage" in area:
		dmg = area.damage

	take_damage(dmg)
