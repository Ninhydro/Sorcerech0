# GameHUD.gd (Modified)
extends Control

@onready var player_face_portrait = $PlayerFacePortrait
@onready var health_bar: ProgressBar = $HealthBarContainer/HealthBar
@onready var minimap_viewport: SubViewport = $MinimapContainer/SubViewportContainer/SubViewport
@onready var minimap_camera: Camera2D = $MinimapContainer/SubViewportContainer/SubViewport/Camera2D

# --- NEW FORM SELECTION UI NODES ---
@onready var form_icon_previous: TextureRect = $"FormSelectionContainer/HBoxContainer/FormIconPrevious"
@onready var form_icon_current: TextureRect = $"FormSelectionContainer/HBoxContainer/FormIconCurrent"
@onready var form_icon_next: TextureRect = $"FormSelectionContainer/HBoxContainer/FormIconNext"

@onready var form_selection_container: Control = $FormSelectionContainer

# Dictionary to hold preloaded form textures (set in Inspector)
@export var form_textures: Dictionary = {
	"Normal": preload("res://assets_image/UI/Form_logo/Normal.png"), 
	"Cyber": preload("res://assets_image/UI/Form_logo/Cyber.png"),
	"UltimateCyber": preload("res://assets_image/UI/Form_logo/UltimateCyber.png"),
	"Magus": preload("res://assets_image/UI/Form_logo/Magus.png"),
	"UltimateMagus": preload("res://assets_image/UI/Form_logo/UltimateMagus.png"),
}


# These should be pre-cropped/zoomed to just the face for each form.
@export var character_face_portraits: Dictionary = {
	"Normal": preload("res://assets_image/Characters/Phina/Normal/Normal_Happy.png"), # Example path
	"Magus": preload("res://assets_image/Characters/Phina/Magus/Magus_Happy.png"),
	"Cyber": preload("res://assets_image/Characters/Phina/Cyber/Cyber_Happy.png"),
	"UltimateMagus": preload("res://assets_image/Characters/Phina/UltimateMagus/UltimateMagus_Happy.png"),
	"UltimateCyber": preload("res://assets_image/Characters/Phina/UltimateCyber/UltimateCyber_Happy.png"),
}

var player_node: Player = null 
var _last_selected_form_index: int = -1 

var _form_icon_display_size: Vector2 = Vector2.ZERO 

var _highlight_color: Color = Color(1.0, 1.0, 1.0, 1.0) # Yellow, opaque
var _highlight_width: float = 1.0 # <-- Change this from 2.0 to 8.0 (or even 10.0 for testing)
var _icon_modulate: Color = Color(1.0, 1.0, 1.0, 0.2)  # Default white (no change)
var _outline_width: float = 0.2  # Changed from _highlight_width

@onready var fps_label: Label = $FPSLabel
var _fps_timer := 0.0

func _ready():
	# Defer initialization to ensure Player node is ready and in group
	call_deferred("initialize_hud")
	if Global.is_dialog_open == true or Global.is_cutscene_active == true:
		visible = false
	elif Global.is_dialog_open == false or Global.is_cutscene_active == false:
		visible = true


func initialize_hud():
	# Get player reference. Using Global.playerBody is generally the most reliable
	if Global.playerBody and is_instance_valid(Global.playerBody):
		player_node = Global.playerBody
		print("GameHUD: Found Player node via Global.playerBody.")
		player_node.health_changed.connect(update_health_bar_from_signal)
		player_node.form_changed.connect(update_ui_on_form_change) 
		
		# --- Set up UI element sizes and stretch modes in code ---
		player_face_portrait.custom_minimum_size = Vector2(30, 30)
		player_face_portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH
		player_face_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		var form_icon_size = Vector2(10, 10) 
		_form_icon_display_size = form_icon_size 
		form_icon_previous.custom_minimum_size = form_icon_size
		form_icon_current.custom_minimum_size = form_icon_size
		form_icon_next.custom_minimum_size = form_icon_size
		

		form_icon_previous.expand_mode = TextureRect.EXPAND_FIT_WIDTH
		form_icon_current.expand_mode = TextureRect.EXPAND_FIT_WIDTH
		form_icon_next.expand_mode = TextureRect.EXPAND_FIT_WIDTH
		
		form_icon_previous.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		form_icon_current.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		form_icon_next.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		# Assign initial (non-highlighted) shader materials
		# This is crucial so the icons always use the shader.
		_set_icon_highlight(form_icon_previous, false)
		_set_icon_highlight(form_icon_current, false)
		_set_icon_highlight(form_icon_next, false)
		
		health_bar.custom_minimum_size = Vector2(80, 10)
		
		# --- NEW MINIMAP SETUP ---
		if is_instance_valid(minimap_viewport):
			# Assign the main scene's 2D world to the minimap's viewport
			minimap_viewport.world_2d = get_tree().root.world_2d
			print("minimap_viewport",minimap_viewport.world_2d)
			# Ensure the minimap camera is not the 'current' camera for the main viewport
			# Create material for circular mask
			var circle_material = Global.create_circle_material()
			#circle_material.shader = load("res://shaders/circle.gdshader")
			
			# Apply to viewport container
			var viewport_container = $MinimapContainer/SubViewportContainer
			viewport_container.material = circle_material
			
			# Optional: Add a circular border texture
			var border_texture = preload("res://shaders/circle.gdshader")
			var border = TextureRect.new()
			border.texture = border_texture
			border.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			border.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			$MinimapContainer.add_child(border)
			border.z_index = 1  # Make sure it's above the viewport
		
			if is_instance_valid(minimap_camera):
				#minimap_camera.current = false # Make sure it doesn't try to be the primary camera
				minimap_camera.zoom = Vector2(0.1, 0.1) # Adjust zoom for minimap view
			else:
				printerr("GameHUD: Minimap camera not valid.")
		else:
			printerr("GameHUD: Minimap viewport not valid.")
		# --- END NEW MINIMAP SETUP ---
		# Initial UI updates
		update_health_bar_from_signal(Global.health, Global.health_max) # Ensure this is .max_health, not .health_max
		
		_last_selected_form_index = Global.selected_form_index
		update_form_selection_display()
		# Initial call to update UI based on player's starting form
		update_ui_on_form_change(player_node.get_current_form_id()) 
		
		

		
	else:
		# Fallback if Global.playerBody isn't set, try finding it by group "player"
		player_node = get_tree().get_first_node_in_group("player")
		if player_node and is_instance_valid(player_node):
			print("GameHUD: Found Player node via group 'player' as a fallback.")
			# ... (copy the rest of the initialization from above here, or refactor)
			player_node.health_changed.connect(update_health_bar_from_signal)
			player_node.form_changed.connect(update_ui_on_form_change) 
			
			player_face_portrait.custom_minimum_size = Vector2(30, 30)
			player_face_portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH
			player_face_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			
			var form_icon_size = Vector2(10, 10)
			form_icon_previous.custom_minimum_size = form_icon_size
			form_icon_current.custom_minimum_size = form_icon_size
			form_icon_next.custom_minimum_size = form_icon_size
			

			form_icon_previous.expand_mode = TextureRect.EXPAND_FIT_WIDTH
			form_icon_current.expand_mode = TextureRect.EXPAND_FIT_WIDTH
			form_icon_next.expand_mode = TextureRect.EXPAND_FIT_WIDTH
			
			form_icon_previous.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			form_icon_current.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			form_icon_next.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			
			# Assign initial (non-highlighted) shader materials
		# This is crucial so the icons always use the shader.
			_set_icon_highlight(form_icon_previous, false)
			_set_icon_highlight(form_icon_current, false)
			_set_icon_highlight(form_icon_next, false)
		
			health_bar.custom_minimum_size = Vector2(80, 10)
			
			# --- NEW MINIMAP SETUP (Fallback Branch) ---
			if is_instance_valid(minimap_viewport):
				minimap_viewport.world_2d = get_tree().root.world_2d
				print("minimap_viewport",minimap_viewport.world_2d)
				
				var circle_material = ShaderMaterial.new()
				circle_material.shader = load("res://shaders/circle.gdshader")
				
				# Apply to viewport container
				var viewport_container = $MinimapContainer/SubViewportContainer
				viewport_container.material = circle_material
				# Optional: Add a circular border texture
				var border_texture = preload("res://shaders/circle.gdshader")
				var border = TextureRect.new()
				border.texture = border_texture
				border.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				border.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				$MinimapContainer.add_child(border)
				border.z_index = 1  # Make sure it's above the viewport
			
				if is_instance_valid(minimap_camera):
					#minimap_camera.current = false
					minimap_camera.zoom = Vector2(0.1, 0.1)
				else:
					printerr("GameHUD: Minimap camera not valid in fallback.")
			else:
				printerr("GameHUD: Minimap viewport not valid in fallback.")
			# --- END NEW MINIMAP SETUP (Fallback Branch) ---

			update_health_bar_from_signal(Global.health, Global.max_health)
			
			_last_selected_form_index = Global.selected_form_index
			update_form_selection_display()
			update_ui_on_form_change(player_node.get_current_form_id())
		else:
			printerr("GameHUD: Player node still not found after deferred initialization (via Global or group 'player')! UI will not function.")

func _process(delta):

	if Global.is_dialog_open == true or Global.is_cutscene_active == true:
		visible = false
	elif Global.is_dialog_open == false or Global.is_cutscene_active == false:
		visible = true

	if player_node:
		update_minimap_camera_position()
		
		if Global.selected_form_index != _last_selected_form_index:
			update_form_selection_display()
			_last_selected_form_index = Global.selected_form_index
	
	_fps_timer += delta
	if _fps_timer >= 0.5: # update twice per second (lighter than every frame)
		if is_instance_valid(fps_label):
			fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
		_fps_timer = 0.0
		
func _set_icon_highlight(icon_rect: TextureRect, highlight: bool):
	if not is_instance_valid(icon_rect): return

	var material: ShaderMaterial = icon_rect.material as ShaderMaterial
	if material:
		material.set_shader_parameter("is_highlighted", highlight)
		material.set_shader_parameter("highlight_color", _highlight_color)
		material.set_shader_parameter("outline_width", _outline_width)
		
		# Always apply modulate to previous/next icons, even when highlighted
		if icon_rect == form_icon_previous || icon_rect == form_icon_next:
			material.set_shader_parameter("modulate", _icon_modulate)
			material.set_shader_parameter("apply_modulate", true)
		else:
			material.set_shader_parameter("modulate", Color(1.0, 1.0, 1.0, 1.0))
			material.set_shader_parameter("apply_modulate", false)
					
func set_icon_modulate(color: Color):
	_icon_modulate = color
	# Only update previous and next icons
	_set_icon_highlight(form_icon_previous, form_icon_previous.material.get_shader_parameter("is_highlighted"))
	_set_icon_highlight(form_icon_next, form_icon_next.material.get_shader_parameter("is_highlighted"))
# Helper to get the form name from an index, handling wraparound

func get_form_name_at_index(index: int, unlocked_forms: Array[String]) -> String:
	if unlocked_forms.is_empty():
		return "Normal"
	
	var actual_index = (index % unlocked_forms.size() + unlocked_forms.size()) % unlocked_forms.size()
	return unlocked_forms[actual_index]

# Updates the three form icons displayed (previous, current selection, next)
func update_form_selection_display():
	if not is_instance_valid(player_node): return

	var unlocked_forms = player_node.unlocked_states
	var current_selection_index = Global.selected_form_index
	
	if unlocked_forms.is_empty():
		form_icon_previous.texture = null
		form_icon_current.texture = null
		form_icon_next.texture = null
		_update_applied_form_highlight("") # Clear highlight

		return

	var prev_idx = (current_selection_index - 1 + unlocked_forms.size()) % unlocked_forms.size()
	var next_idx = (current_selection_index + 1) % unlocked_forms.size()

	var prev_form_name = get_form_name_at_index(prev_idx, unlocked_forms)
	var current_form_name = get_form_name_at_index(current_selection_index, unlocked_forms)
	var next_form_name = get_form_name_at_index(next_idx, unlocked_forms)
	
	form_icon_previous.texture = form_textures.get(prev_form_name)
	form_icon_current.texture = form_textures.get(current_form_name)
	form_icon_next.texture = form_textures.get(next_form_name)
	
	_update_applied_form_highlight(player_node.get_current_form_id())

# Handles all UI updates when the player's *applied* form changes
func update_ui_on_form_change(new_form_name: String):
	#print("DEBUG: update_ui_on_form_change called with: ", new_form_name)

	_update_applied_form_highlight(new_form_name)
	update_character_face_portrait(new_form_name)

func _update_applied_form_highlight(applied_form_name: String):
	#print("DEBUG: Entering _update_applied_form_highlight for form: '", applied_form_name, "'")

	var active_form_texture = form_textures.get(applied_form_name)
	if not active_form_texture:
		#printerr("DEBUG: ERROR: No texture found in form_textures for applied_form_name: '", applied_form_name, "'. Cannot highlight.")
		# Ensure all icons are unhighlighted if active form texture is missing
		_set_icon_highlight(form_icon_previous, false)
		_set_icon_highlight(form_icon_current, false)
		_set_icon_highlight(form_icon_next, false)
		return

	# Unhighlight all icons first
	_set_icon_highlight(form_icon_previous, false)
	_set_icon_highlight(form_icon_current, false)
	_set_icon_highlight(form_icon_next, false)

	# Check which displayed icon matches the applied form's texture and highlight it
	if is_instance_valid(form_icon_previous) and form_icon_previous.texture == active_form_texture:
		_set_icon_highlight(form_icon_previous, true)
		#print("DEBUG: Highlight applied to: Previous Icon")
	elif is_instance_valid(form_icon_current) and form_icon_current.texture == active_form_texture:
		_set_icon_highlight(form_icon_current, true)
		#print("DEBUG: Highlight applied to: Current Icon")
	elif is_instance_valid(form_icon_next) and form_icon_next.texture == active_form_texture:
		_set_icon_highlight(form_icon_next, true)
		#print("DEBUG: Highlight applied to: Next Icon")
	else:
		print("DEBUG: Active form texture does NOT match any displayed icon textures. No highlight visible.")


# This function updates the highlight to show the *currently applied* form
# This function updates the highlight to show the *currently applied* form
# This function updates the highlight to show the *currently applied* form
# GameHUD.gd (The updated update_applied_form_highlight function)
#to update the character's face portrait
func update_character_face_portrait(form_id: String):
	if is_instance_valid(player_face_portrait) and character_face_portraits.has(form_id):
		player_face_portrait.texture = character_face_portraits[form_id]
	else:
		printerr("GameHUD: No face portrait found for form: ", form_id, ". Using null texture.")
		player_face_portrait.texture = null


func update_health_bar_from_signal(current_health: int, max_health: int):
	if is_instance_valid(health_bar):
		health_bar.max_value = 100
		health_bar.value = current_health

func update_minimap_camera_position():
	if player_node and is_instance_valid(minimap_camera):
		minimap_camera.global_position = player_node.global_position
		#print(minimap_camera.global_position)

func _exit_tree():
	# Clean up minimap material
	var viewport_container = $MinimapContainer/SubViewportContainer
	if viewport_container and viewport_container.material:
		viewport_container.material = null
		
