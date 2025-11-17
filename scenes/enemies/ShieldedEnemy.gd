extends BaseEnemy

@export var shield_health := 50
@export var shield_regen_rate := 5.0  # Health per second
@export var shield_regen_delay := 3.0  # Seconds after damage to start regen

var current_shield_health: float
var has_shield := true
var shield_regen_timer: Timer
var last_damage_time := 0.0

@onready var shield_sprite := $ShieldSprite

func _initialize_enemy():
	current_shield_health = shield_health
	base_speed = 25  # Much slower when shielded
	update_shield_visibility()
	
	# Shield regen timer
	shield_regen_timer = Timer.new()
	shield_regen_timer.wait_time = 1.0
	shield_regen_timer.one_shot = false
	add_child(shield_regen_timer)
	shield_regen_timer.timeout.connect(_on_shield_regen_timeout)
	shield_regen_timer.start()

func take_damage(damage):
	last_damage_time = Time.get_ticks_msec()
	
	if has_shield and current_shield_health > 0:
		# Damage shield first
		current_shield_health -= damage
		
		# Shield hit effect
		var tween = create_tween()
		tween.tween_property(shield_sprite, "modulate", Color.CYAN, 0.1)
		tween.tween_property(shield_sprite, "modulate", Color.WHITE, 0.1)
		
		if current_shield_health <= 0:
			has_shield = false
			shield_sprite.visible = false
			base_speed = 50  # Move faster when shield breaks
			print("Shield broken!")
	else:
		# Take normal damage when shield is down
		super.take_damage(damage)

func _on_shield_regen_timeout():
	if has_shield and current_shield_health < shield_health:
		var time_since_damage = (Time.get_ticks_msec() - last_damage_time) / 1000.0
		if time_since_damage >= shield_regen_delay:
			current_shield_health = min(current_shield_health + shield_regen_rate, shield_health)
			print("Shield regenerating: ", current_shield_health)
			
			# If shield was broken and now has health, reactivate
			if not has_shield and current_shield_health > 0:
				has_shield = true
				shield_sprite.visible = true
				base_speed = 25  # Slow down again when shield active
				print("Shield restored!")

func update_shield_visibility():
	shield_sprite.visible = has_shield

func handle_animation():
	var new_animation := ""
	
	if dead:
		new_animation = "death"
	elif taking_damage:
		new_animation = "hurt"
	elif is_dealing_damage:
		new_animation = "attack"
	else:
		new_animation = "walk"  # Different animation for slow movement
		if dir.x == -1:
			sprite.flip_h = true
			if has_shield:
				shield_sprite.flip_h = true
		elif dir.x == 1:
			sprite.flip_h = false
			if has_shield:
				shield_sprite.flip_h = false
	
	if new_animation != current_animation:
		current_animation = new_animation
		animation_player.play(new_animation)
		
		if new_animation == "hurt":
			await get_tree().create_timer(0.5).timeout
			taking_damage = false
		elif new_animation == "death":
			await animation_player.animation_finished
			handle_death()
