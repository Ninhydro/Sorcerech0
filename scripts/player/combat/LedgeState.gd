extends CombatState
class_name LedgeState

# Called when the node enters the scene tree for the first time.
func enter():
	#print("jump")
	var form = player.get_current_form_id()
	#player.global_position = player.next_ledge_position
	#player.camera_pivot.position = Vector2.ZERO

	match form:
		"Magus":
			#player.anim_sprite.play("magus_attack")
			# You could also spawn a fireball or magic effect here
			#print("Magus ledge")
			player.still_animation = true
			player.anim_state.travel("ledge_magus")
		"Cyber":
			#player.anim_sprite.play("cyber_slash")
			# Maybe activate grapple or combo effects
			#print("Cyber ledge")
			player.still_animation = true
			player.anim_state.travel("ledge_cyber")
			
		"UltimateMagus":
			#player.anim_sprite.play("ultimate_magus_blast")
			# Big AoE logic here
			#print("Ultimate Magus ledge")
			player.still_animation = true
			player.anim_state.travel("ledge_ult_magus")
		"UltimateCyber":
			#player.anim_sprite.play("ultimate_cyber_strike")
			# Laser or time freeze here
			#print("Ultimate Cyber ledge")
			player.still_animation = true
			player.anim_state.travel("ledge_ult_cyber")
		"Normal":
			#player.anim_sprite.play("normal_attack")
			#print("Normal jump")
			#player.anim_state.travel("jump_normal")
			pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func physics_update(delta):
	#print(player.still_animation)
	if player.still_animation == false:
				
				player.is_grabbing_ledge = false
				#player.camera.position_smoothing_enabled = false
				#player.NormalColl.disabled = false
				print("ledge off")
			#velocity = Vector2(LedgeDirection.x * move_speed, -jump_force)
				# Play a "climb" animation
			#print("Player is climbing the ledge.")
				#player.NormalColl.disabled = false
				#print("IdleState: Detected movement input → switching to IdleState")
				get_parent().change_state(IdleState.new(player))
				
	#elif Input.is_action_pressed("no"): #hurt hp loss this is later
	#	print("IdleState: Detected movement input → switching to HurtState")
	#	get_parent().change_state(HurtState.new(player))
