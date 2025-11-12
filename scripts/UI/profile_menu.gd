# res://scripts/ui/profile_scene.gd
extends CanvasLayer

@onready var player_name_label = $Panel/MainContainer/HBoxContainer/VBoxContainer/PlayerNameLabel
@onready var player_sprite_profile = $Panel/MainContainer/HBoxContainer/PlayerSpriteProfile # Removed form_logo_texture
@onready var kills_label = $Panel/MainContainer/HBoxContainer/VBoxContainer/KillsRow/KillsLabel
@onready var status_label =$Panel/MainContainer/HBoxContainer/VBoxContainer/KillsRow/Status # NEW: Status Label
@onready var affinity_label = $Panel/MainContainer/HBoxContainer/VBoxContainer/AffinityLabel # NEW: Affinity value label
#@onready var affinity_progress_bar = $Panel/MainContainer/HBoxContainer/VBoxContainer/AffinityRow/AffinityProgressBar/AffinityProgressBar # NEW: Affinity progress bar
@onready var inventory_grid = $Panel/MainContainer/HBoxContainer/VBoxContainer/InventoryContainer # Changed to GridContainer
@onready var back_button = $Panel/MainContainer/Button

@onready var magus_label = $Panel/MainContainer/HBoxContainer/VBoxContainer/AffinityRow/Magus
@onready var cyber_label = $Panel/MainContainer/HBoxContainer/VBoxContainer/AffinityRow/Cyber
@onready var negative_affinity_bar = $Panel/MainContainer/HBoxContainer/VBoxContainer/AffinityRow/AffinityProgressBar/NegativeAffinityBar
@onready var positive_affinity_bar = $Panel/MainContainer/HBoxContainer/VBoxContainer/AffinityRow/AffinityProgressBar/PositiveAffinityBar
const MIN_AFFINITY = -10
const MAX_AFFINITY = 10

# --- Exported dictionaries for form-specific assets ---
# Drag your form icon textures here in the inspector (e.g., res://assets/icons/magus_icon.png)
#@export var form_logos: Dictionary = {
#	"Normal": preload("res://assets/player/forms/normal_icon.png") if ResourceLoader.exists("res://assets/player/forms/normal_icon.png") else null,
#	"Magus": preload("res://assets/player/forms/magus_icon.png") if ResourceLoader.exists("res://assets/player/forms/magus_icon.png") else null,
#	"Cyber": preload("res://assets/player/forms/cyber_icon.png") if ResourceLoader.exists("res://assets/player/forms/cyber_icon.png") else null,
#	"UltimateMagus": preload("res://assets/player/forms/ultimate_magus_icon.png") if ResourceLoader.exists("res://assets/player/forms/ultimate_magus_icon.png") else null,
#	"UltimateCyber": preload("res://assets/player/forms/ultimate_cyber_icon.png") if ResourceLoader.exists("res://assets/player/forms/ultimate_cyber_icon.png") else null,
#}
# --- Exported dictionary for full-body player sprite assets ---
# Use a placeholder SVG for all forms as requested.
# MAKE SURE 'res://assets_image/placeholder/icon.svg' EXISTS or replace with a default Godot icon path.
@export var form_full_sprites: Dictionary = {
	"Normal": preload("res://assets_image/Characters/Phina/Normal/Normal_Normal.png") if ResourceLoader.exists("res://assets_image/Characters/Phina/Normal/Normal_Normal.png") else null,
	"Magus": preload("res://assets_image/Characters/Phina/Magus/Magus_Normal.png") if ResourceLoader.exists("res://assets_image/Characters/Phina/Magus/Magus_Normal.png") else null,
	"Cyber": preload("res://assets_image/Characters/Phina/Cyber/1Fini_transparent.png") if ResourceLoader.exists("res://assets_image/Characters/Phina/Cyber/1Fini_transparent.png") else null,
	"UltimateMagus": preload("res://assets_image/Characters/Phina/UltimateMagus/UltimateMagus_Normal.png") if ResourceLoader.exists("res://assets_image/Characters/Phina/UltimateMagus/UltimateMagus_Normal.png") else null,
	"UltimateCyber": preload("res://assets_image/Characters/Phina/UltimateCyber/UltimateCyber_Normal.jpg") if ResourceLoader.exists("res://assets_image/Characters/Phina/UltimateCyber/UltimateCyber_Normal.jpg") else null,
}
# --- End Exported dictionary ---

var _parent_menu_reference: Node = null # To go back to the PauseMenu

# --- Inventory Slot Settings ---
const INVENTORY_SLOT_SIZE = Vector2(20, 20) # Size of each inventory box in pixels
const MAX_INVENTORY_SLOTS = 10 # Total number of inventory slots to display (e.g., 4 rows of 5)
# --- End Inventory Slot Settings ---

var status_text_color_normal : Color = Color.DIM_GRAY # Default to white, you can change this in the Inspector
var status_text_color_bad : Color = Color.RED # Default to white, you can change this in the Inspector
var status_text_color_good : Color = Color.GREEN # Default to white, you can change this in the Inspector
var status_text_color_magus : Color = Color.YELLOW # Default to white, you can change this in the Inspector
var status_text_color_cyber : Color = Color.BLUE # Default to white, you can change this in the Inspector



func _ready():
	back_button.pressed.connect(_on_back_button_pressed)
	
	player_sprite_profile.set_custom_minimum_size(Vector2(80, 100))
	# Allow the image to expand and stretch to fill the set size
	player_sprite_profile.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	player_sprite_profile.stretch_mode = TextureRect.STRETCH_SCALE
	call_deferred("deferred_update_profile_data")
	# Initial update of profile data
	update_profile_data()
	
	# Connect to Global.current_form_changed signal
	Global.current_form_changed.connect(on_global_form_changed)
	
	set_process_unhandled_input(true)
	back_button.grab_focus()

func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("menu") or  event.is_action_pressed("no"):
		_on_back_button_pressed()
		get_viewport().set_input_as_handled()



func deferred_update_profile_data():
	# This function will be called on the next idle frame, after all _ready() calls for the current frame.
	# This gives the Player's _ready() a chance to set Global.playerBody.
	update_profile_data()

func update_profile_data():
	# Assume player name is stored in Global or can be set here
	# For now, let's hardcode a player name or fetch from a Global variable if you add it
	player_name_label.text = "Goal: put Quest here" # You can replace "Hero" with Global.player_name if you add it

	if Global.playerBody:
		# Get data from Global or playerBody directly
		kills_label.text = "Kills: " + str(Global.kills)
		if Global.kills == 0:
			status_label.text = "Pacifist"
			status_label.add_theme_color_override("font_color", status_text_color_good)
			Global.player_status = "Pacifist"
		elif Global.kills > 0 and Global.kills < 50:
			status_label.text = "Neutral"
			status_label.add_theme_color_override("font_color", status_text_color_normal)
			Global.player_status = "Neutral"
		elif Global.kills >= 50:
			status_label.text = "Genocide"
			status_label.add_theme_color_override("font_color", status_text_color_bad)
			Global.player_status = "Genocide"
		#status_label.text = "Status: " + Global.player_status # Update status label
		
		_update_affinity_display(Global.affinity) # Update affinity visual
		
		# Update form-related visuals
		update_form_visuals(Global.get_player_form()) # Use Global.get_player_form()
		
		# Update inventory
		_update_inventory_display(Global.playerBody.inventory) # Inventory is still in Player.gd
	else:
		printerr("ProfileScene: Global.playerBody is not set!")
		kills_label.text = "Kills: N/A"
		status_label.text = " N/A"
		_update_affinity_display(0) # Default affinity
		_update_inventory_display([]) # Show empty inventory

func update_form_visuals(form_id: String):
	# Update full-body sprite (logo removed)
	if form_full_sprites.has(form_id) and form_full_sprites[form_id] != null:
		player_sprite_profile.texture = form_full_sprites[form_id]
	else:
		printerr("ProfileScene: No full body sprite found for form: ", form_id, ". Using default placeholder.")
		# Fallback to a generic placeholder if a specific one is missing
		player_sprite_profile.texture = preload("res://assets_image/placeholder/icon.svg") if ResourceLoader.exists("res://assets_image/placeholder/icon.svg") else null


func _update_inventory_display(inventory_list: Array):
	for child in inventory_grid.get_children():
		child.queue_free()
	
	var test_inventory_list = inventory_list.duplicate()
	#if not test_inventory_list.has("PH"):
	#	test_inventory_list.append("PH")
	#if not test_inventory_list.has("PH2"):
	#	test_inventory_list.append("PH2")

	for i in range(test_inventory_list.size()):
		var item_id = test_inventory_list[i]
		
		# --- MODIFIED: Change item_slot to VBoxContainer for automatic vertical layout ---
		var item_slot = VBoxContainer.new()
		item_slot.set_custom_minimum_size(INVENTORY_SLOT_SIZE)
		item_slot.mouse_filter = Control.MOUSE_FILTER_PASS
		
		# Apply a StyleBoxFlat to make the VBoxContainer look like a panel
		var slot_style = StyleBoxFlat.new()
		slot_style.bg_color = Color(0.15, 0.15, 0.15, 1.0) # Dark gray background for the slot
		slot_style.border_width_left = 1 # Corrected: Individual border widths
		slot_style.border_width_right = 1
		slot_style.border_width_top = 1
		slot_style.border_width_bottom = 1
		slot_style.border_color = Color(0.3, 0.3, 0.3, 1.0) # Border color
		# --- MODIFIED: Use individual corner radius properties ---
		slot_style.corner_radius_top_left = 4
		slot_style.corner_radius_top_right = 4
		slot_style.corner_radius_bottom_left = 4
		slot_style.corner_radius_bottom_right = 4
		# --- END MODIFIED ---
		item_slot.add_theme_stylebox_override("panel", slot_style) # Apply to "panel" style type
		
		# Add padding inside the VBoxContainer
		item_slot.add_theme_constant_override("separation", 0) # No default separation between children
		item_slot.add_theme_constant_override("margin_left", 2)
		item_slot.add_theme_constant_override("margin_right", 2)
		item_slot.add_theme_constant_override("margin_top", 2)
		item_slot.add_theme_constant_override("margin_bottom", 2)

		inventory_grid.add_child(item_slot)

		var item_texture_rect = TextureRect.new()
		item_texture_rect.set_custom_minimum_size(Vector2(24, 24))
		item_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		item_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		# Make image expand to fill most of the VBoxContainer's height
		item_texture_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
		item_texture_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		if item_id == "PH":
			item_texture_rect.texture = preload("res://assets_image/placeholder/icon.svg")
		elif item_id == "PH2":
			item_texture_rect.texture = preload("res://assets_image/placeholder/icon.svg")
		else:
			item_texture_rect.texture = preload("res://assets_image/placeholder/icon.svg")
		item_slot.add_child(item_texture_rect)

		var item_label = Label.new()
		item_label.text = item_id
		item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER # Center vertically within its own allocated space
		item_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		item_label.clip_text = true
		# Make label shrink to its content and stick to the bottom of VBoxContainer's remaining space
		item_label.size_flags_vertical = Control.SIZE_SHRINK_END
		item_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL # Expand horizontally to center text

		var item_font_size = 8
		var default_font: Font = inventory_grid.get_theme_font("font")
		if default_font:
			var item_font_theme = Theme.new()
			item_font_theme.set_font("font", "Label", default_font)
			item_font_theme.set_font_size("font_size", "Label", item_font_size)
			item_label.theme = item_font_theme
		
		item_slot.add_child(item_label)
	
	for i in range(test_inventory_list.size(), MAX_INVENTORY_SLOTS):
		var empty_slot = VBoxContainer.new() # Also change empty slots to VBoxContainer
		empty_slot.set_custom_minimum_size(INVENTORY_SLOT_SIZE)
		empty_slot.mouse_filter = Control.MOUSE_FILTER_PASS
		# Apply the same style to empty slots for consistency
		var empty_slot_style = StyleBoxFlat.new()
		empty_slot_style.bg_color = Color(0.1, 0.1, 0.1, 1.0) # Slightly darker for empty
		empty_slot_style.border_width_left = 1 # Corrected: Individual border widths
		empty_slot_style.border_width_right = 1
		empty_slot_style.border_width_top = 1
		empty_slot_style.border_width_bottom = 1
		empty_slot_style.border_color = Color(0.2, 0.2, 0.2, 1.0)
		# --- MODIFIED: Use individual corner radius properties for empty slots ---
		empty_slot_style.corner_radius_top_left = 4
		empty_slot_style.corner_radius_top_right = 4
		empty_slot_style.corner_radius_bottom_left = 4
		empty_slot_style.corner_radius_bottom_right = 4
		# --- END MODIFIED ---
		empty_slot.add_theme_stylebox_override("panel", empty_slot_style)
		inventory_grid.add_child(empty_slot)


func _update_affinity_display(affinity_value: int):
	# Update the ProgressBar value
	#affinity_progress_bar.value = affinity_value
	
	# Ensure the value is within the defined range for safety
	var clamped_affinity = clampi(affinity_value, MIN_AFFINITY, MAX_AFFINITY)
	#print(f"Clamped affinity: {clamped_affinity}")

	if clamped_affinity < 0:
		print("Affinity is negative. Setting yellow bar.")
		negative_affinity_bar.value = clamped_affinity
		positive_affinity_bar.value = 0 # Reset positive bar
		magus_label.add_theme_color_override("font_color", status_text_color_magus)
		#negative_affinity_bar.visible = true
		#positive_affinity_bar.visible = false
		#affinity_value_label.add_theme_color_override("font_color", Color.YELLOW)
		#print(f"Negative bar value: {negative_affinity_bar.value}, visible: {negative_affinity_bar.visible}")
		#print(f"Positive bar value: {positive_affinity_bar.value}, visible: {positive_affinity_bar.visible}")
	elif clamped_affinity > 0:
		print("Affinity is positive. Setting blue bar.")
		positive_affinity_bar.value = clamped_affinity
		negative_affinity_bar.value = 0 # Reset negative bar
		cyber_label.add_theme_color_override("font_color", status_text_color_cyber)
		
		#negative_affinity_bar.visible = false
		#positive_affinity_bar.visible = true
		#affinity_value_label.add_theme_color_override("font_color", Color.BLUE)
		#print(f"Negative bar value: {negative_affinity_bar.value}, visible: {negative_affinity_bar.visible}")
		#print(f"Positive bar value: {positive_affinity_bar.value}, visible: {positive_affinity_bar.visible}")
	else: # affinity_value == 0
		print("Affinity is zero. Hiding both bars.")
		negative_affinity_bar.value = 0
		positive_affinity_bar.value = 0
		
		#negative_affinity_bar.visible = false
		#positive_affinity_bar.visible = false
		#affinity_value_label.add_theme_color_override("font_color", Color.GRAY)
		#print(f"Negative bar value: {negative_affinity_bar.value}, visible: {negative_affinity_bar.visible}")
		#print(f"Positive bar value: {positive_affinity_bar.value}, visible: {positive_affinity_bar.visible}")
	print("--- Affinity Display Update Finished ---")

# Callback for Global.current_form_changed signal
func on_global_form_changed(new_form_id: String):
	print("ProfileScene: Global form changed to: ", new_form_id)
	update_form_visuals(new_form_id)

func _on_back_button_pressed():
	print("ProfileScene: Closing Profile Scene.")
	if is_instance_valid(_parent_menu_reference):
		if _parent_menu_reference.has_method("show_pause_menu"):
			_parent_menu_reference.show_pause_menu()
			print("ProfileScene: Returned to PauseMenu.")
		else:
			printerr("ProfileScene: Parent menu has no 'show_pause_menu' method.")
	else:
		get_tree().paused = false # Fallback if no specific parent
		print("ProfileScene: No parent reference, unpausing game directly.")
	queue_free()

func set_parent_menu_reference(node: Node):
	_parent_menu_reference = node
	if is_instance_valid(node):
		print("ProfileScene: Parent menu reference set to: " + node.name)
	else:
		printerr("ProfileScene: set_parent_menu_reference called with an invalid node!")
