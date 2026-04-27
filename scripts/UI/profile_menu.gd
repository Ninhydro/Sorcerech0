# res://scripts/ui/profile_scene.gd
extends CanvasLayer

#@onready var player_name_label = $Panel/MainContainer/HBoxContainer/VBoxContainer/PlayerNameLabel
@onready var quest_label_1 = $Panel/MainContainer/HBoxContainer/VBoxContainer/HBoxContainer/VBoxContainer/PlayerNameLabel
@onready var quest_label_2 = $Panel/MainContainer/HBoxContainer/VBoxContainer/HBoxContainer/VBoxContainer/PlayerNameLabel2
@onready var player_sprite_profile = $Panel/MainContainer/HBoxContainer/PlayerSpriteProfile # Removed form_logo_texture
@onready var kills_label = $Panel/MainContainer/HBoxContainer/VBoxContainer/KillsRow/KillsLabel
@onready var status_label =$Panel/MainContainer/HBoxContainer/VBoxContainer/KillsRow/Status 
@onready var affinity_label = $Panel/MainContainer/HBoxContainer/VBoxContainer/AffinityLabel 
#@onready var affinity_progress_bar = $Panel/MainContainer/HBoxContainer/VBoxContainer/AffinityRow/AffinityProgressBar/AffinityProgressBar 
@onready var inventory_grid = $Panel/MainContainer/HBoxContainer/VBoxContainer/InventoryContainer # Changed to GridContainer
@onready var back_button = $Panel/MainContainer/Button

@onready var magus_label = $Panel/MainContainer/HBoxContainer/VBoxContainer/AffinityRow/Magus
@onready var cyber_label = $Panel/MainContainer/HBoxContainer/VBoxContainer/AffinityRow/Cyber
@onready var negative_affinity_bar = $Panel/MainContainer/HBoxContainer/VBoxContainer/AffinityRow/AffinityProgressBar/NegativeAffinityBar
@onready var positive_affinity_bar = $Panel/MainContainer/HBoxContainer/VBoxContainer/AffinityRow/AffinityProgressBar/PositiveAffinityBar
const MIN_AFFINITY = -10
const MAX_AFFINITY = 10

# --- Exported dictionaries for form-specific assets ---
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
	"Normal": preload("res://assets_image/Characters/Phina/Normal/Normal_Happy.png") if ResourceLoader.exists("res://assets_image/Characters/Phina/Normal/Normal_Happy.png") else null,
	"Magus": preload("res://assets_image/Characters/Phina/Magus/Magus_Happy.png") if ResourceLoader.exists("res://assets_image/Characters/Phina/Magus/Magus_Happy.png") else null,
	"Cyber": preload("res://assets_image/Characters/Phina/Cyber/Cyber_Happy.png") if ResourceLoader.exists("res://assets_image/Characters/Phina/Cyber/Cyber_Happy.png") else null,
	"UltimateMagus": preload("res://assets_image/Characters/Phina/UltimateMagus/UltimateMagus_Happy.png") if ResourceLoader.exists("res://assets_image/Characters/Phina/UltimateMagus/UltimateMagus_Happy.png") else null,
	"UltimateCyber": preload("res://assets_image/Characters/Phina/UltimateCyber/UltimateCyber_Happy.png") if ResourceLoader.exists("res://assets_image/Characters/Phina/UltimateCyber/UltimateCyber_Happy.png") else null,
}
# --- End Exported dictionary ---

var _parent_menu_reference: Node = null # To go back to the PauseMenu

# --- Inventory Slot Settings ---
const INVENTORY_SLOT_SIZE = Vector2(20, 20) # Size of each inventory box in pixels
const MAX_INVENTORY_SLOTS = 9 # Total number of inventory slots to display (e.g., 4 rows of 5)
# --- End Inventory Slot Settings ---

var status_text_color_normal : Color = Color.DIM_GRAY
var status_text_color_bad : Color = Color.RED 
var status_text_color_good : Color = Color.GREEN 
var status_text_color_magus : Color = Color.YELLOW 
var status_text_color_cyber : Color = Color.BLUE

@export var item_icons: Dictionary = {
	"Microchip": preload("res://assets_image/Objects/collect_objects7.png"),
	"MagicStone": preload("res://assets_image/Objects/collect_objects6.png"),
	"Tape_A": preload("res://assets_image/Objects/collect_objects8.png"),
	"Tape_B": preload("res://assets_image/Objects/collect_objects9.png"),
	"Tape_C": preload("res://assets_image/Objects/collect_objects10.png"),
	"Glasses": preload("res://assets_image/Objects/Objects2.png"),   # change path
	"Screwdriver": preload("res://assets_image/Objects/Objects3.png"),
	"Sword": preload("res://assets_image/Objects/Objects4.png"),

}

@export var item_display_names: Dictionary = {
	"Microchip": "Microchip",
	"MagicStone": "Magic Stone",
	"Tape_A": "Video Tape: Past",
	"Tape_B": "Video Tape: Present",
	"Tape_C": "Video Tape: Future",
	"Glasses": "Glasses",
	"Screwdriver": "Screwdriver",
	"Sword": "Sword",
	
}

var _current_popup: Control = null

@export var item_descriptions: Dictionary = {
	"Microchip": "A small processing unit chip, maybe it will be useful in the future.",
	"MagicStone": "A glowing crystal, maybe it will be useful in the future",
	"Tape_A": "Recording of past events. It said: gssor://vvv.xntstad.bnl/vzsbg?u=Vl4niha_ZDZ",
	"Tape_B": "Video about Ceaser cipher decode. Past is -1 and Future is +1? What does it means?",
	"Tape_C": "Recording of the future? It said: iuuqt://xxx.xfcuppot.dpn/fo/dbowbt/bopnbmpvt-dpoofdujpo/mjtu?ujumf_op=73091",
	"Glasses": "Glasses, that the old merchant looking for",
	"Screwdriver": "Screwdriver, maybe that kid can use it",
	"Sword": "A sturdy blade, maybe that boy can use it",
}

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
	var quests := Global.active_quests  # Array of quest names
	
	if quests.size() == 0:
		quest_label_1.text = " None "
		quest_label_2.text = ""
		quest_label_2.visible = false
	elif quests.size() == 1:
		quest_label_1.text = " " + str(quests[0])
		quest_label_2.text = ""
		quest_label_2.visible = false
	else:
		# If 2 or more quests, show first two only
		quest_label_1.text = " " + str(quests[0])
		quest_label_2.visible = true
		quest_label_2.text = " " + str(quests[1])
		
	if Global.playerBody:
		# Get data from Global or playerBody directly
		kills_label.text = "Kills: " + str(Global.kills)
		if Global.kills == 0:
			status_label.text = "Pacifist"
			status_label.add_theme_color_override("font_color", status_text_color_good)
			#Global.player_status = "Pacifist"
		elif Global.kills > 0 and Global.kills < 50:
			status_label.text = "Neutral"
			status_label.add_theme_color_override("font_color", status_text_color_normal)
			#Global.player_status = "Neutral"
		elif Global.kills >= 50:
			status_label.text = "Genocide"
			status_label.add_theme_color_override("font_color", status_text_color_bad)
			#Global.player_status = "Genocide"
		#status_label.text = "Status: " + Global.player_status # Update status label
		
		_update_affinity_display(Global.affinity) # Update affinity visual
		
		# Update form-related visuals
		update_form_visuals(Global.get_player_form()) # Use Global.get_player_form()
		
		# Build a list from persistent data instead of Player inventory
		var inventory_list: Array = []

		# 1) Microchips (stackable)
		for i in range(Global.persistent_microchips):
			inventory_list.append("Microchip")

		# 2) Magic Stones (stackable)
		for i in range(Global.persistent_magic_stones):
			inventory_list.append("MagicStone")

		# 3) Video tapes (unique each)
		if Global.persistent_video_tape_1_collected:
			inventory_list.append("Tape_A")   # Past
		if Global.persistent_video_tape_2_collected:
			inventory_list.append("Tape_B")   # Present
		if Global.persistent_video_tape_3_collected:
			inventory_list.append("Tape_C")   # Future
		
		if Global.has_glasses:
			inventory_list.append("Glasses")
		if Global.has_screwdriver:
			inventory_list.append("Screwdriver")
		if Global.has_sword:
			inventory_list.append("Sword")
	
		_update_inventory_display(inventory_list)
	else:
		printerr("ProfileScene: Global.playerBody is not set!")
		kills_label.text = "Kills: N/A"
		status_label.text = " N/A"
		_update_affinity_display(0) # Default affinity
		 # Still show persistent collection even if playerBody is missing
		var inventory_list: Array = []

		for i in range(Global.persistent_microchips):
			inventory_list.append("Microchip")
		for i in range(Global.persistent_magic_stones):
			inventory_list.append("MagicStone")
		if Global.persistent_video_tape_1_collected:
			inventory_list.append("Tape_A")
		if Global.persistent_video_tape_2_collected:
			inventory_list.append("Tape_B")
		if Global.persistent_video_tape_3_collected:
			inventory_list.append("Tape_C")

		_update_inventory_display(inventory_list)

func update_form_visuals(form_id: String):
	# Update full-body sprite (logo removed)
	if form_full_sprites.has(form_id) and form_full_sprites[form_id] != null:
		player_sprite_profile.texture = form_full_sprites[form_id]
	else:
		printerr("ProfileScene: No full body sprite found for form: ", form_id, ". Using default placeholder.")
		# Fallback to a generic placeholder if a specific one is missing
		player_sprite_profile.texture = preload("res://assets_image/placeholder/icon.svg") if ResourceLoader.exists("res://assets_image/placeholder/icon.svg") else null


func _update_inventory_display(inventory_list: Array):
	# Clear old slots
	for child in inventory_grid.get_children():
		child.queue_free()
	
	# 1) Build a dictionary: { item_id: count }
	var counts: Dictionary = {}
	for item_id in inventory_list:
		if counts.has(item_id):
			counts[item_id] += 1
		else:
			counts[item_id] = 1

	var unique_ids: Array = []
	for item_id in inventory_list:
		if not unique_ids.has(item_id):
			unique_ids.append(item_id)
	
	# 2) Create a slot per unique item
	for item_id in unique_ids:
		var count: int = counts.get(item_id, 1)
		
		var item_slot = VBoxContainer.new()
		item_slot.set_custom_minimum_size(INVENTORY_SLOT_SIZE)
		#item_slot.mouse_filter = Control.MOUSE_FILTER_PASS
		item_slot.mouse_filter = Control.MOUSE_FILTER_STOP 
		item_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL

		var slot_style = StyleBoxFlat.new()
		slot_style.bg_color = Color(0.15, 0.15, 0.15, 1.0)
		slot_style.border_width_left = 1
		slot_style.border_width_right = 1
		slot_style.border_width_top = 1
		slot_style.border_width_bottom = 1
		slot_style.border_color = Color(0.3, 0.3, 0.3, 1.0)
		slot_style.corner_radius_top_left = 4
		slot_style.corner_radius_top_right = 4
		slot_style.corner_radius_bottom_left = 4
		slot_style.corner_radius_bottom_right = 4
		item_slot.add_theme_stylebox_override("panel", slot_style)
		
		item_slot.add_theme_constant_override("separation", 0)
		item_slot.add_theme_constant_override("margin_left", 2)
		item_slot.add_theme_constant_override("margin_right", 2)
		item_slot.add_theme_constant_override("margin_top", 2)
		item_slot.add_theme_constant_override("margin_bottom", 2)

		#inventory_grid.add_child(item_slot)

		# --- ICON ---
		var item_texture_rect = TextureRect.new()
		item_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item_texture_rect.set_custom_minimum_size(Vector2(24, 24))
		item_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		item_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		item_texture_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
		item_texture_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		if item_icons.has(item_id) and item_icons[item_id] != null:
			item_texture_rect.texture = item_icons[item_id]
		else:
			item_texture_rect.texture = preload("res://assets_image/placeholder/icon.svg")
		
		item_slot.add_child(item_texture_rect)

		# --- COUNT BADGE ON TOP OF ICON (for stacked items) ---
		# Only show for Microchip & MagicStone and only if count > 1
		if (item_id == "Microchip" or item_id == "MagicStone") and count > 1:
			var count_label = Label.new()
			count_label.text = str(count)
			
			# Make it small and bold-ish
			var default_font: Font = inventory_grid.get_theme_font("font")
			if default_font:
				var badge_theme = Theme.new()
				badge_theme.set_font("font", "Label", default_font)
				badge_theme.set_font_size("font_size", "Label", 8)
				count_label.theme = badge_theme
			
			count_label.add_theme_color_override("font_color", Color.WHITE)
			count_label.add_theme_color_override("font_outline_color", Color.BLACK)
			count_label.add_theme_constant_override("outline_size", 2)
			
			# Overlay in bottom-right of the icon
			item_texture_rect.add_child(count_label)
			count_label.anchor_left = 1.0
			count_label.anchor_top = 1.0
			count_label.anchor_right = 1.0
			count_label.anchor_bottom = 1.0
			# Offsets relative to the bottom-right corner
			count_label.offset_left = -12
			count_label.offset_top = -10
			count_label.offset_right = 0
			count_label.offset_bottom = 0
			count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			count_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM

		# --- NAME LABEL UNDER ICON ---
		var base_name: String
		if item_display_names.has(item_id):
			base_name = item_display_names[item_id]
		else:
			base_name = item_id

		var item_label = Label.new()
		item_label.mouse_filter = Control.MOUSE_FILTER_IGNORE 
		item_label.text = base_name
		item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		item_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		item_label.clip_text = true
		item_label.size_flags_vertical = Control.SIZE_SHRINK_END
		item_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var item_font_size = 8
		var default_font2: Font = inventory_grid.get_theme_font("font")
		if default_font2:
			var item_font_theme = Theme.new()
			item_font_theme.set_font("font", "Label", default_font2)
			item_font_theme.set_font_size("font_size", "Label", item_font_size)
			item_label.theme = item_font_theme
		
		item_slot.add_child(item_label)
		item_slot.gui_input.connect(_on_item_slot_gui_input.bind(item_id))
		inventory_grid.add_child(item_slot)
		#inventory_grid.add_child(item_slot) get error E 0:00:23:0050   profile_menu.gd:343 @ _update_inventory_display(): Can't add child '@VBoxContainer@294' to 'InventoryContainer', already has a parent 'InventoryContainer'.


		
	# 3) Fill remaining slots as empty
	var used_slots := unique_ids.size()
	for i in range(used_slots, MAX_INVENTORY_SLOTS):
		var empty_slot = VBoxContainer.new()
		empty_slot.set_custom_minimum_size(INVENTORY_SLOT_SIZE)
		empty_slot.mouse_filter = Control.MOUSE_FILTER_PASS
		empty_slot.alignment = BoxContainer.ALIGNMENT_CENTER  # center children
		
		var empty_slot_style = StyleBoxFlat.new()
		empty_slot_style.bg_color = Color(0.05, 0.05, 0.05, 1.0)   # very dark
		empty_slot_style.border_width_left = 2
		empty_slot_style.border_width_right = 2
		empty_slot_style.border_width_top = 2
		empty_slot_style.border_width_bottom = 2
		empty_slot_style.border_color = Color(0.9, 0.9, 0.9, 1.0)   # bright light grey (almost white)
		empty_slot_style.corner_radius_top_left = 4
		empty_slot_style.corner_radius_top_right = 4
		empty_slot_style.corner_radius_bottom_left = 4
		empty_slot_style.corner_radius_bottom_right = 4
		empty_slot.add_theme_stylebox_override("panel", empty_slot_style)
		
		# Add a simple "Empty" label so it's clearly an empty slot
		var empty_label = Label.new()
		empty_label.text = ""
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		empty_label.add_theme_color_override("font_outline_color", Color.BLACK)
		empty_label.add_theme_constant_override("outline_size", 1)
		
		# Small font for empty text
		var empty_font = inventory_grid.get_theme_font("font")
		if empty_font:
			var empty_theme = Theme.new()
			empty_theme.set_font("font", "Label", empty_font)
			empty_theme.set_font_size("font_size", "Label", 6)
			empty_label.theme = empty_theme
		
		empty_slot.add_child(empty_label)
		inventory_grid.add_child(empty_slot)

func _on_item_slot_gui_input(event: InputEvent, item_id: String):
	print("DEBUG: Slot clicked for item: ", item_id)   # <-- ADD THIS
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_show_item_description(item_id, event.global_position)

func _show_item_description(item_id: String, global_pos: Vector2):
	# Remove any existing popup
	if _current_popup and is_instance_valid(_current_popup):
		_current_popup.queue_free()
	
	var desc_text = item_descriptions.get(item_id, "No description available.")
	
	# Create a PanelContainer
	var popup_panel = PanelContainer.new()
	var popup_label = Label.new()
	popup_label.text = desc_text
	popup_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	popup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Grey styling
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.2, 0.95)   # dark grey background
	style.set_border_width_all(2)
	style.border_color = Color(0.6, 0.6, 0.6)      # light grey border
	style.set_corner_radius_all(5)
	style.set_content_margin_all(8)
	popup_panel.add_theme_stylebox_override("panel", style)
	
	popup_panel.add_child(popup_label)
	popup_panel.set_custom_minimum_size(Vector2(150, 40))
	popup_panel.size = Vector2(200, 60)   # fixed size
	
	# Center on screen
	var viewport_size = get_viewport().get_visible_rect().size
	var popup_position = (viewport_size - popup_panel.size) / 2
	popup_panel.position = popup_position
	
	add_child(popup_panel)
	_current_popup = popup_panel
	
	# Timer to auto‑remove
	var timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = 2.0
	timer.timeout.connect(_on_popup_timer_timeout)
	add_child(timer)
	timer.start()
	
func _on_popup_timer_timeout():
	if _current_popup and is_instance_valid(_current_popup):
		_current_popup.queue_free()
		_current_popup = null
	
func _update_affinity_display(affinity_value: int):
	# Update the ProgressBar value
	#affinity_progress_bar.value = affinity_value
	
	# Ensure the value is within the defined range for safety
	var clamped_affinity = clampi(affinity_value, MIN_AFFINITY, MAX_AFFINITY)
	#print(f"Clamped affinity: {clamped_affinity}")

	if clamped_affinity < 0: #negative magus
		print("Affinity is negative. Setting yellow bar.")
		negative_affinity_bar.value = clamped_affinity
		positive_affinity_bar.value = 0 # Reset positive bar
		magus_label.add_theme_color_override("font_color", status_text_color_magus)
		#negative_affinity_bar.visible = true
		#positive_affinity_bar.visible = false
		#affinity_value_label.add_theme_color_override("font_color", Color.YELLOW)
		#print(f"Negative bar value: {negative_affinity_bar.value}, visible: {negative_affinity_bar.visible}")
		#print(f"Positive bar value: {positive_affinity_bar.value}, visible: {positive_affinity_bar.visible}")
	elif clamped_affinity > 0: #positive cyber
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
