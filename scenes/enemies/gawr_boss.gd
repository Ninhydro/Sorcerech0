extends BaseEnemy
class_name GawrBoss

signal boss_died

@export var slam_damage: int = 20
@export var fire_damage: int = 10

@onready var anim: AnimationPlayer = $AnimationPlayer

@onready var body_light: Node2D = $Sprite_Body_Light
@onready var body_dark: Node2D = $Sprite_Body_Dark

@onready var head_light_closed: Node2D = $Sprite_Head_Light
@onready var head_light_open: Node2D = $Sprite_Head_LightOpen
@onready var head_dark: Node2D = $Sprite_Head_Dark

@onready var slam_left: Area2D = $LeftArmRoot/SlamHitbox_Left
@onready var slam_right: Area2D = $RightArmRoot/SlamHitbox_Right

@onready var fire_breath: Area2D = $FireOrigin/FireBreath

var pattern_running: bool = false

func _ready() -> void:
	super._ready()

	# Gawr is stationary
	is_enemy_chase = false
	is_roaming = false
	use_edge_detection = false
	can_jump_chase = false

	# Initial visuals
	body_light.visible = true
	body_dark.visible = false
	head_light_closed.visible = true
	head_light_open.visible = false
	head_dark.visible = false

	# disable hitboxes at start
	slam_left.monitoring = false
	slam_right.monitoring = false
	fire_breath.monitoring = false

	if not slam_left.body_entered.is_connected(_on_slam_body_entered):
		slam_left.body_entered.connect(_on_slam_body_entered)
	if not slam_right.body_entered.is_connected(_on_slam_body_entered):
		slam_right.body_entered.connect(_on_slam_body_entered)
	if not fire_breath.body_entered.is_connected(_on_fire_body_entered):
		fire_breath.body_entered.connect(_on_fire_body_entered)

	_run_pattern()


func reset_for_battle() -> void:
	health = health_max
	dead = false
	pattern_running = false

	body_light.visible = true
	body_dark.visible = false
	head_light_closed.visible = true
	head_light_open.visible = false
	head_dark.visible = false

	slam_left.monitoring = false
	slam_right.monitoring = false
	fire_breath.monitoring = false

	_run_pattern()

func _run_pattern() -> void:
	if pattern_running:
		return
	pattern_running = true

	while not dead:
		await _phase_idle_roar()
		if dead: break

		await _phase_slam_attack()
		if dead: break

		await _phase_fire_breath()
		if dead: break

func _phase_idle_roar() -> void:
	if dead:
		return

	velocity = Vector2.ZERO

	if anim.has_animation("idle"):
		anim.play("idle")

	await get_tree().create_timer(1.5 / Global.global_time_scale).timeout

	# Roar anim (open mouth)
	if anim.has_animation("roar"):
		anim.play("roar")

		# Example: open head sprite for the roar
		head_light_closed.visible = false
		head_light_open.visible = true

		await anim.animation_finished

		head_light_closed.visible = true
		head_light_open.visible = false

func _phase_slam_attack() -> void:
	if dead:
		return

	velocity = Vector2.ZERO

	# AnimationPlayer controls arm movement + hand open/close + camera shake if any
	if anim.has_animation("slam_left"):
		anim.play("slam_left")

		# Enable hitbox at impact moment.
		# If you don't want to manually tween timings, you can:
		await get_tree().create_timer(0.3 / Global.global_time_scale).timeout
		slam_left.monitoring = true

		# active window
		await get_tree().create_timer(0.25 / Global.global_time_scale).timeout
		slam_left.monitoring = false

		await anim.animation_finished

	# Optional: slam right arm after a delay
	if dead:
		return

	if anim.has_animation("slam_right"):
		anim.play("slam_right")

		await get_tree().create_timer(0.3 / Global.global_time_scale).timeout
		slam_right.monitoring = true
		await get_tree().create_timer(0.25 / Global.global_time_scale).timeout
		slam_right.monitoring = false

		await anim.animation_finished


func _phase_fire_breath() -> void:
	if dead:
		return

	velocity = Vector2.ZERO

	# Animation opening mouth + flame start
	if anim.has_animation("fire_start"):
		anim.play("fire_start")
		await anim.animation_finished

	# Activate fire hitbox and loop flame
	fire_breath.monitoring = true

	if anim.has_animation("fire_loop"):
		anim.play("fire_loop")

	# Keep breathing for some time
	await get_tree().create_timer(2.0 / Global.global_time_scale).timeout

	fire_breath.monitoring = false

	if anim.has_animation("fire_end"):
		anim.play("fire_end")
		await anim.animation_finished

func _on_slam_body_entered(body: Node) -> void:
	if dead:
		return
	if body.is_in_group("player"):
		body.take_damage(slam_damage)  # uses your Player.gd take_damage()


func _on_fire_body_entered(body: Node) -> void:
	if dead:
		return
	if body.is_in_group("player"):
		body.take_damage(fire_damage)

func take_damage(dmg: int) -> void:
	if dead:
		return

	super.take_damage(dmg)
	print("Gawr took damage: ", dmg, " -> HP: ", health, "/", health_max)

	if health <= 0:
		_handle_boss_death()


func _handle_boss_death() -> void:
	if dead:
		return

	dead = true
	pattern_running = false

	slam_left.monitoring = false
	slam_right.monitoring = false
	fire_breath.monitoring = false

	if anim and anim.has_animation("death"):
		anim.play("death")
		await anim.animation_finished

	# Swap to dark body/head
	body_light.visible = false
	head_light_closed.visible = false
	head_light_open.visible = false

	body_dark.visible = true
	head_dark.visible = true

	emit_signal("boss_died")
