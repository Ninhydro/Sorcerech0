# PlayerPortrait.gd
extends Node2D

@onready var portrait_sprite: Sprite2D = $PortraitSprite

# Remove the `@export` from these lines.
# We will populate these dictionaries manually in code.
var normal_portraits: Dictionary = {}
var cyber_portraits: Dictionary = {}
var magus_portraits: Dictionary = {}
var ultimatemagus_portraits: Dictionary = {}
var ultimatecyber_portraits: Dictionary = {}

var portraits_initialized: bool = false

func _ready():
	if not is_instance_valid(portrait_sprite):
		portrait_sprite = $PortraitSprite
		if not is_instance_valid(portrait_sprite):
			push_error("PlayerPortrait: PortraitSprite node not found in _ready. Check scene setup.")

	# --- Call the new function to set up portraits ---
	set_all_portraits()
	portraits_initialized = true  # Set the flag after initialization

	print("--- PlayerPortrait _ready() State (After set_all_portraits) ---")
	print("Normal Portraits in _ready(): ", normal_portraits)
	print("Cyber Portraits in _ready(): ", cyber_portraits)
	print("Magus Portraits in _ready(): ", magus_portraits)
	print("UltimateMagus Portraits in _ready(): ", ultimatemagus_portraits)
	print("UltimateCyber Portraits in _ready(): ", ultimatecyber_portraits)
	print("--------------------------------------------------")


# --- NEW FUNCTION TO MANUALLY POPULATE DICTIONARIES ---
# Call this once when the scene is ready, or if you need to re-initialize portraits.
func set_all_portraits():
	# Normal Portraits
	normal_portraits = {
		"Angry": preload("res://assets_image/Characters/Phina/Normal/Normal_Angry.png"), #Normal_Angry
		"Happy": preload("res://assets_image/Characters/Phina/Normal/Normal_Happy.png"),
		"Normal": preload("res://assets_image/Characters/Phina/Normal/Normal_Normal.png"),
		"Sad": preload("res://assets_image/Characters/Phina/Normal/Normal_Sad.png")
		# Add "Unique" if you have it for Normal form, it's in your log for Cyber
	}
	# Cyber Portraits
	cyber_portraits = {
		"Angry": preload("res://assets_image/Characters/Phina/Cyber/Cyber_Angry.png"),
		"Happy": preload("res://assets_image/Characters/Phina/Cyber/Cyber_Happy.png"),
		"Normal": preload("res://assets_image/Characters/Phina/Cyber/1Fini_transparent.png"),
		"Sad": preload("res://assets_image/Characters/Phina/Cyber/Cyber_Sad.png")
		# Add "Unique" if you have it for Cyber form
	}
	# Magus Portraits
	magus_portraits = {
		"Angry": preload("res://assets_image/Characters/Phina/Magus/Magus_Angry.png"),
		"Happy": preload("res://assets_image/Characters/Phina/Magus/Magus_Happy.png"),
		"Normal": preload("res://assets_image/Characters/Phina/Magus/Magus_Normal.png"),
		"Sad": preload("res://assets_image/Characters/Phina/Magus/Magus_Sad.png")
	}
	# Ultimate Magus Portraits (Fix the typo: UltimateMagus_Angrt.png should be UltimateMagus_Angry.png)
	ultimatemagus_portraits = {
		"Angry": preload("res://assets_image/Characters/Phina/UltimateMagus/UltimateMagus_Angry.png"), # FIX FILENAME HERE
		"Happy": preload("res://assets_image/Characters/Phina/UltimateMagus/UltimateMagus_Happy.png"),
		"Normal": preload("res://assets_image/Characters/Phina/UltimateMagus/UltimateMagus_Normal.png"),
		"Sad": preload("res://assets_image/Characters/Phina/UltimateMagus/UltimateMagus_Sad.png")
	}
	# Ultimate Cyber Portraits
	ultimatecyber_portraits = {
		"Angry": preload("res://assets_image/Characters/Phina/UltimateCyber/UltimateCyber_Angry.png"),
		"Happy": preload("res://assets_image/Characters/Phina/UltimateCyber/UltimateCyber_Happy.png"),
		"Normal": preload("res://assets_image/Characters/Phina/UltimateCyber/UltimateCyber_Normal.jpg"),
		"Sad": preload("res://assets_image/Characters/Phina/UltimateCyber/UltimateCyber_Sad.png")
	}
	# Add any other missing textures/keys if they exist in your file system
	# Example: If your Cyber form also has a "Unique" texture:
	# cyber_portraits["Unique"] = preload("res://assets_image/Characters/Phina/Cyber/Cyber_Unique.png")


func _update_portrait(_character: DialogicCharacter, portrait_name_with_parens: String) -> void:
	if not portraits_initialized:
		print("PlayerPortrait: Portraits not initialized yet. Initializing now...")
		set_all_portraits()
		portraits_initialized = true
	
	# Rest of your _update_portrait function remains the same...
	if not is_instance_valid(portrait_sprite):
		portrait_sprite = find_child("PortraitSprite") # Or $PortraitSprite if direct child
		if not is_instance_valid(portrait_sprite):
			push_error("PlayerPortrait: portrait_sprite node STILL not found after re-attempt. Check scene path: $PortraitSprite")
			return

	var cleaned_portrait_name: String = portrait_name_with_parens.replace("(", "").replace(")", "").strip_edges()
	
	# Debug: Print all available portraits
	print("--- Available Portraits ---")
	print("Normal: ", normal_portraits.keys())
	print("Cyber: ", cyber_portraits.keys())
	print("Magus: ", magus_portraits.keys())
	print("UltimateMagus: ", ultimatemagus_portraits.keys())
	print("UltimateCyber: ", ultimatecyber_portraits.keys())
	print("---------------------------")
	
	var current_form = Dialogic.VAR.get_variable("player_current_form", "Normal")
	print("PlayerPortrait: Attempting to update portrait.")
	print("  - Requested Portrait: '", cleaned_portrait_name, "'")
	print("  - Current Form: '", current_form, "'")

	var portraits_to_use: Dictionary = {}
	var selected_form_name: String = "Unknown"

	match current_form:
		"Normal":
			portraits_to_use = normal_portraits
			selected_form_name = "Normal"
		"Cyber":
			portraits_to_use = cyber_portraits
			selected_form_name = "Cyber"
		"Magus":
			portraits_to_use = magus_portraits
			selected_form_name = "Magus"
		"UltimateMagus":
			portraits_to_use = ultimatemagus_portraits
			selected_form_name = "UltimateMagus"
		"UltimateCyber":
			portraits_to_use = ultimatecyber_portraits
			selected_form_name = "UltimateCyber"
		_:
			push_warning("PlayerPortrait: Unknown player form: '" + str(current_form) + "'. Using Normal portraits as fallback.")
			portraits_to_use = normal_portraits
			selected_form_name = "Normal (Fallback)"

	print("  - Using portraits from form: '", selected_form_name, "'")
	print("  - Available expressions: ", portraits_to_use.keys())

	# Try to find the portrait with case-insensitive matching
	var found_key = null
	for key in portraits_to_use.keys():
		if key.to_lower() == cleaned_portrait_name.to_lower():
			found_key = key
			break

	if found_key:
		portrait_sprite.texture = portraits_to_use[found_key]
		print("PlayerPortrait: Successfully set portrait to: ", found_key, " for form ", selected_form_name)
	else:
		push_warning("PlayerPortrait: Portrait texture NOT found for expression '" + cleaned_portrait_name + "' in form '" + selected_form_name + "'.")
		
		# Try to find a fallback
		var fallback_keys = ["Normal", "normal", "Neutral", "neutral"]
		var fallback_found = false
		
		for fallback_key in fallback_keys:
			if portraits_to_use.has(fallback_key):
				portrait_sprite.texture = portraits_to_use[fallback_key]
				print("PlayerPortrait: Falling back to '", fallback_key, "' expression for form '", selected_form_name, "'.")
				fallback_found = true
				break
		
		if not fallback_found and portraits_to_use.size() > 0:
			# Use the first available portrait as a last resort
			var first_key = portraits_to_use.keys()[0]
			portrait_sprite.texture = portraits_to_use[first_key]
			print("PlayerPortrait: Falling back to first available expression '", first_key, "' for form '", selected_form_name, "'.")
		else:
			push_warning("PlayerPortrait: No fallback expression found for form '", selected_form_name + "'. Portrait will be empty.")
			portrait_sprite.texture = null
			
func _get_covered_rect() -> Rect2:
	if is_instance_valid(portrait_sprite) and portrait_sprite.texture != null:
		var texture_size = portrait_sprite.texture.get_size()
		var sprite_offset = portrait_sprite.position
		var sprite_scale = portrait_sprite.scale

		var rect_position = sprite_offset - (texture_size * sprite_scale * portrait_sprite.offset) / texture_size
		var rect_size = texture_size * sprite_scale

		return Rect2(rect_position, rect_size)
	else:
		return Rect2(0, 0, 0, 0)

func _should_do_portrait_update(_character: DialogicCharacter, _portrait_name: String) -> bool:
	return true

func _highlight() -> void:
	if is_instance_valid(portrait_sprite):
		if portrait_sprite.has_meta("highlight_tween"):
			var existing_tween = portrait_sprite.get_meta("highlight_tween")
			if is_instance_valid(existing_tween) and existing_tween.is_running():
				existing_tween.stop()
		
		var highlight_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		highlight_tween.tween_property(portrait_sprite, "modulate", Color(1.2, 1.2, 1.2, 1), 0.2)
		highlight_tween.tween_property(portrait_sprite, "scale", Vector2(1.05, 1.05), 0.2)
		portrait_sprite.set_meta("highlight_tween", highlight_tween)

func _unhighlight() -> void:
	if is_instance_valid(portrait_sprite):
		if portrait_sprite.has_meta("highlight_tween"):
			var existing_tween = portrait_sprite.get_meta("highlight_tween")
			if is_instance_valid(existing_tween) and existing_tween.is_running():
				existing_tween.stop()
		
		var unhighlight_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		unhighlight_tween.tween_property(portrait_sprite, "modulate", Color(1, 1, 1, 1), 0.2)
		unhighlight_tween.tween_property(portrait_sprite, "scale", Vector2(1, 1), 0.2)
		portrait_sprite.set_meta("highlight_tween", unhighlight_tween)
