extends CanvasLayer

@onready var fade_rect = $FadeRect

func _ready():
	if fade_rect == null:
		push_error("FadeRect not found! Check TransitionManager scene!")
	fade_rect.modulate.a = 0.0
	fade_rect.visible = false
	fade_rect.anchors_preset = Control.PRESET_FULL_RECT

func travel_to(player: Node2D, target_room_name: String, target_spawn_name: String) -> void:
	# 0. Check if we're in a cutscene - if so, wait for it to end
	if Global.is_cutscene_active:
		print("TransitionManager: Waiting for cutscene to end before traveling...")
		await get_tree().create_timer(0.1).timeout  # Small delay
		if Global.is_cutscene_active:  # Check again
			print("TransitionManager: Cutscene still active, cannot travel")
			return
	
	print("TransitionManager: Starting travel to ", target_room_name)
	
	# 1. Force-cancel grappling / skills
	if player.has_method("force_release_grapple"):
		player.force_release_grapple()
	else:
		# Fallback
		if "is_grappling_active" in player:
			player.is_grappling_active = false
		if "still_animation" in player:
			player.still_animation = false
		if player.has_node("GrappleLine"):
			var gl := player.get_node("GrappleLine")
			if gl is Line2D:
				gl.clear_points()
	
	# 2. Stop player physics and movement
	player.velocity = Vector2.ZERO
	player.set_physics_process(false)
	
	# 3. Fade out
	fade_rect.visible = true
	fade_rect.color = Color(0, 0, 0, 1)
	
	var tween_out = get_tree().create_tween()
	tween_out.tween_property(fade_rect, "modulate:a", 1.0, 0.25).set_ease(Tween.EASE_OUT)
	await tween_out.finished
	await get_tree().create_timer(0.4).timeout
	
	# 4. Teleport the player (while screen is black)
	var world = get_tree().get_current_scene()
	if world:
		var target_room = world.get_node_or_null(target_room_name)
		if target_room:
			var spawn_points = target_room.get_node_or_null("SpawnPoints")
			if spawn_points:
				var spawn_marker = spawn_points.get_node_or_null(target_spawn_name) as Marker2D
				if spawn_marker:
					player.global_position = spawn_marker.global_position
					print("TransitionManager: Teleported player to ", target_spawn_name)
				else:
					print("TransitionManager: Warning: Spawn marker not found: ", target_spawn_name)
			else:
				print("TransitionManager: Warning: SpawnPoints node not found in ", target_room_name)
		else:
			print("TransitionManager: Warning: Target room not found: ", target_room_name)
	
	# Reset velocity after teleport
	player.velocity = Vector2.ZERO
	
	# 5. Fade back in
	await get_tree().create_timer(0.4).timeout
	var tween_in = get_tree().create_tween()
	tween_in.tween_property(fade_rect, "modulate:a", 0.0, 0.25).set_ease(Tween.EASE_IN)
	await tween_in.finished
	
	
	# 6. Hide rect and restore player physics
	fade_rect.visible = false
	player.set_physics_process(true)
	
	print("TransitionManager: Travel complete")
