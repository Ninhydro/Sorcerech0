extends CombatState
class_name SaveState

func enter():
	#player.play_anim("idle")
	#print("idle")
	var form = player.get_current_form_id()
	
	match form:
		"Magus":
			#player.anim_sprite.play("magus_attack")
			# You could also spawn a fireball or magic effect here
			#print("Magus idle")
			player.still_animation = true
			player.velocity.x = 0
			player.anim_state.travel("save_magus")
		"Cyber":
			#player.anim_sprite.play("cyber_slash")
			# Maybe activate grapple or combo effects
			#print("Cyber idle")
			player.still_animation = true
			player.velocity.x = 0
			player.anim_state.travel("save_cyber")
		"UltimateMagus":
			#player.anim_sprite.play("ultimate_magus_blast")
			# Big AoE logic here
			#print("Ultimate Magus idle")
			player.still_animation = true
			player.velocity.x = 0
			player.anim_state.travel("save_ult_magus")
		"UltimateCyber":
			#player.anim_sprite.play("ultimate_cyber_strike")
			# Laser or time freeze here
			#print("Ultimate Cyber idle")
			player.still_animation = true
			player.velocity.x = 0
			player.anim_state.travel("save_ult_cyber")
		"Normal":
			#player.anim_sprite.play("normal_attack")
			#print("Normal idle")
			player.still_animation = true
			player.velocity.x = 0
			player.anim_state.travel("save_normal")

func physics_update(delta):
	if player.still_animation == false:
		Global.saving = false
		get_parent().change_state(LoadState.new(player))

	#elif Input.is_action_pressed("no"): #hurt hp loss this is later
	#	print("IdleState: Detected movement input → switching to HurtState")
	#	get_parent().change_state(HurtState.new(player))
