extends CombatState
class_name HurtState

var animation_finished := false
# Called when the node enters the scene tree for the first time.
func enter():
	#print("hurt")
	print("=== HURT STATE DEBUG ===")
	print("Current animation: ", player.animation_player.current_animation)
	print("Is playing: ", player.animation_player.is_playing())
	
	var form = player.get_current_form_id()
	print("Playing hurt animation for: ", form)


	match form:
		
		"Magus":
			#player.anim_sprite.play("magus_attack")

			#print("Magus hurt")
			player.anim_state.travel("hurt_magus")
			player.still_animation = true
			#player.still_animation = true
		"Cyber":
			#player.anim_sprite.play("cyber_slash")
			# Maybe activate grapple or combo effects
			#print("Cyber hurt")
			player.anim_state.travel("hurt_cyber")
			player.still_animation = true
			#player.still_animation = true
		"UltimateMagus":
			#player.anim_sprite.play("ultimate_magus_blast")
			# Big AoE logic here
			#print("Ultimate Magus hurt")
			player.anim_state.travel("hurt_ult_magus")
			player.still_animation = true
			#player.still_animation = true
		"UltimateCyber":
			#player.anim_sprite.play("ultimate_cyber_strike")
			# Laser or time freeze here
			#print("Ultimate Cyber hurt")
			player.anim_state.travel("hurt_ult_cyber")
			player.still_animation = true
			#player.still_animation = true
		"Normal":
			#player.anim_sprite.play("normal_attack")
			#print("Normal hurt")
			player.anim_state.travel("hurt_normal")
			player.still_animation = true
			#player.still_animation = true
	# Set still_animation to true while animation plays
	
	#await player.animation_player.animation_finished
	#print("HURT STATE: Animation finished, ready to transition")
	#animation_finished = true
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func physics_update(delta):
	#print("Hurt")
	#if player.still_animation == false:
	if player.still_animation == false:
		if Global.playerAlive:
			if player.is_on_floor():
					if Input.is_action_pressed("move_left") or Input.is_action_pressed("move_right"):
						#print("IdleState: Detected movement input → switching to RunState")
						get_parent().change_state(RunState.new(player))
					else:
						#print("IdleState: Detected movement input → switching to IdleState")
						get_parent().change_state(IdleState.new(player))

			else:
				#print("IdleState: Detected movement input → switching to JumpState")
				get_parent().change_state(JumpState.new(player))
		elif !Global.playerAlive:
			#print("IdleState: Detected movement input → switching to DieState")
			get_parent().change_state(DieState.new(player))
