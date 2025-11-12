extends Node

var highlight_material: ShaderMaterial
var camouflage_material: ShaderMaterial

var shader_materials_created = 0
var shader_materials_freed = 0

var tracked_materials: Array = []
var active_materials = {}

func _ready():
	print("Memory Manager loaded")
	OS.set_low_processor_usage_mode(true)
	Engine.set_max_fps(60)

func _notification(what):
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST:
			# Called when user clicks X button (desktop)
			print("WM_CLOSE_REQUEST received - cleaning up before exit")
			cleanup_before_exit()
			get_tree().quit()
		
		NOTIFICATION_CRASH:
			# Called on crash (if supported)
			print("CRASH DETECTED! Saving crash info...")
			save_crash_report()
		
		NOTIFICATION_PREDELETE:
			# Called when node is about to be deleted - scene tree may be gone
			print("Memory Manager predestroy - final cleanup")
			safe_force_cleanup()  # Use safe version that doesn't rely on scene tree

func safe_force_cleanup():
	"""Ultra-safe cleanup that doesn't rely on scene tree"""
	print("SAFE FORCE CLEANUP - No scene tree operations")
	
	# 1. Clear all arrays and references
	tracked_materials.clear()
	active_materials.clear()
	
	# 2. Null all material references
	highlight_material = null
	camouflage_material = null
	
	# 3. Don't try to access scene tree - it's already gone
	print("Safe cleanup completed - arrays cleared, references nulled")

func cleanup_before_exit():
	"""Called when game is about to exit normally - scene tree still exists"""
	print("=== GAME EXIT CLEANUP STARTED ===")
	
	# 1. FIRST: Call player emergency cleanup to reset sprite materials
	if Global.playerBody and is_instance_valid(Global.playerBody):
		if Global.playerBody.has_method("emergency_cleanup_shaders"):
			Global.playerBody.emergency_cleanup_shaders()
	
	# 2. THEN: Reset all other sprite materials (backup)
	if get_tree() and is_instance_valid(get_tree()):
		reset_all_sprite_materials()
	else:
		print("Scene tree not available for sprite cleanup")
	
	# 3. Clear our internal data
	cleanup_all_materials()
	
	print("=== GAME EXIT CLEANUP COMPLETED ===")

func reset_all_sprite_materials():
	"""Quick reset of all sprite materials - only call when scene tree exists"""
	print("Resetting all sprite materials...")
	
	# Safety check - only proceed if scene tree exists
	if not get_tree() or not is_instance_valid(get_tree()):
		print("Cannot reset sprite materials - scene tree unavailable")
		return
	
	var all_sprites = get_tree().get_nodes_in_group("")  # Empty group gets all nodes
	var reset_count = 0
	
	for node in all_sprites:
		if node is Sprite2D and is_instance_valid(node):
			# If sprite has a shader material, reset it
			if node.material is ShaderMaterial:
				node.material = null
				reset_count += 1
	
	print("Reset ", reset_count, " sprite materials")

func cleanup_all_materials():
	"""Quick material cleanup - don't free, just reset"""
	print("Cleaning up ", tracked_materials.size(), " tracked materials")
	
	# Clear tracked materials array
	tracked_materials.clear()
	
	# Clean active materials dictionary
	active_materials.clear()

func save_crash_report():
	var file = FileAccess.open("user://crash_report.txt", FileAccess.WRITE)
	if file:
		file.store_string("Crash time: " + str(Time.get_time_string_from_system()))
		file.store_string("\nObject count: " + str(Performance.get_monitor(Performance.OBJECT_COUNT)))
		file.close()

# Rest of your existing functions...
func get_highlight_material() -> ShaderMaterial:
	if highlight_material:
		return highlight_material.duplicate()
	return null

func track_material(material: ShaderMaterial):
	if material and not material in tracked_materials:
		tracked_materials.append(material)

func register_material(node: Node, material: ShaderMaterial):
	var node_path = node.get_path()
	active_materials[node_path] = material

func unregister_material(node: Node):
	var node_path = node.get_path()
	active_materials.erase(node_path)

# Remove or comment out the problematic functions that rely on scene tree during cleanup:
# func force_cleanup(): 
# func _deferred_force_cleanup():
# func find_orphaned_nodes():
# func cleanup_node_materials(node: Node):
# func cleanup_dialogic_resources():

func _process(_delta):
	# Optional: Periodic cleanup (every 10 seconds) - only if scene tree exists
	if get_tree() and Engine.get_frames_drawn() % 600 == 0:
		gentle_cleanup()
	if Engine.get_frames_drawn() % 300 == 0:
		var leak_count = shader_materials_created - shader_materials_freed
		if leak_count > 0:
			print("SHADER LEAK DETECTED: ", leak_count, " materials not freed!")

func gentle_cleanup():
	"""Safe cleanup during gameplay - only call when scene tree exists"""
	if get_tree() and is_instance_valid(get_tree()):
		call_deferred("_deferred_gentle_cleanup")

func _deferred_gentle_cleanup():
	"""Safe deferred cleanup - only operates when scene tree exists"""
	if not get_tree() or not is_instance_valid(get_tree()):
		return
	
	# Your gentle cleanup logic here...
	pass


	
