# res://scripts/ui/options_menu.gd
extends CanvasLayer

@onready var background_panel = $Panel
@onready var main_container = $Panel/MainContainer
@onready var back_button = $Panel/MainContainer/Button

# Graphics Settings
@onready var fullscreen_checkbox = $Panel/MainContainer/SettingContainer/VBoxContainer1/Fullscreenrow/CheckBox
@onready var vsync_option_button = $"Panel/MainContainer/SettingContainer/VBoxContainer1/V-SyncRow/OptionButton"
@onready var resolution_option_button = $Panel/MainContainer/SettingContainer/VBoxContainer1/ResolutionRow/OptionButton
@onready var brightness_slider = $Panel/MainContainer/SettingContainer/VBoxContainer1/BrightnessRow/HSlider
@onready var brightness_value_label = $Panel/MainContainer/SettingContainer/VBoxContainer1/BrightnessRow/Label2
@onready var fps_limit_slider = $Panel/MainContainer/SettingContainer/VBoxContainer1/FPSLimitRow/HSlider
@onready var fps_limit_value_label = $Panel/MainContainer/SettingContainer/VBoxContainer1/FPSLimitRow/Label2


# Audio Settings
@onready var master_volume_slider = $Panel/MainContainer/SettingContainer/VBoxContainer2/MasterVolRow/HSlider
@onready var master_volume_value_label = $Panel/MainContainer/SettingContainer/VBoxContainer2/MasterVolRow/Label2

@onready var bgm_volume_slider = $Panel/MainContainer/SettingContainer/VBoxContainer2/BGMVolRow/HSlider
@onready var bgm_volume_value_label = $Panel/MainContainer/SettingContainer/VBoxContainer2/BGMVolRow/Label2

@onready var sfx_volume_slider = $Panel/MainContainer/SettingContainer/VBoxContainer2/SFXVolRow/HSlider
@onready var sfx_volume_value_label = $Panel/MainContainer/SettingContainer/VBoxContainer2/SFXVolRow/Label2

@onready var voice_volume_slider = $Panel/MainContainer/SettingContainer/VBoxContainer2/VoiceVolRow/HSlider
@onready var voice_volume_value_label = $Panel/MainContainer/SettingContainer/VBoxContainer2/VoiceVolRow/Label2

var _parent_menu_reference: Node = null

func _ready():
	print("OptionsMenu _ready() called! Current paused state: ", get_tree().paused)
	
	# Connect signals
	back_button.pressed.connect(_on_back_button_pressed)
	
	fullscreen_checkbox.pressed.connect(_on_fullscreen_checkbox_pressed)
	vsync_option_button.item_selected.connect(_on_vsync_option_button_item_selected)
	resolution_option_button.item_selected.connect(_on_resolution_option_button_item_selected)
	brightness_slider.value_changed.connect(_on_brightness_slider_value_changed)
	#pixel_smoothing_checkbox.pressed.connect(_on_pixel_smoothing_checkbox_pressed)
	fps_limit_slider.value_changed.connect(_on_fps_limit_slider_value_changed)
	
	master_volume_slider.value_changed.connect(_on_master_volume_slider_value_changed)
	bgm_volume_slider.value_changed.connect(_on_bgm_volume_slider_value_changed)
	sfx_volume_slider.value_changed.connect(_on_sfx_volume_slider_value_changed)
	voice_volume_slider.value_changed.connect(_on_voice_volume_slider_value_changed) # NEW: Voice volume
	
	resolution_option_button.clear()
	for res in Global.available_resolutions:
		resolution_option_button.add_item("%d x %d" % [res.x, res.y])


	# Initialize UI with current settings from Global
	_load_settings_to_ui()
	
	# Grab focus for initial navigation
	back_button.grab_focus()

	# Ensure this menu consumes input so clicks don't go through to the paused game world
	set_process_unhandled_input(true)
	
	

func _unhandled_input(event: InputEvent):
	# Pressing ESC key closes the pop-up
	if event.is_action_pressed("menu") or event.is_action_pressed("no"):
		print("OptionsMenu: ESC pressed. Current paused state: ", get_tree().paused)
		_on_back_button_pressed() # Calls the back logic
		get_viewport().set_input_as_handled() # Consume the event

func _load_settings_to_ui():
	# Graphics
	fullscreen_checkbox.button_pressed = Global.fullscreen_on
	
	# Set V-Sync OptionButton based on Global.vsync_mode
	var vsync_idx = 0 # Default to Disabled
	match Global.vsync_on:
		0: vsync_idx = 0  # VSYNC_DISABLED
		1: vsync_idx = 1  # VSYNC_ENABLED
		2: vsync_idx = 2  # VSYNC_ADAPTIVE
		#3: vsync_idx = 3  # VSYNC_MAILBOX
	
	resolution_option_button.select(Global.resolution_index)

	vsync_option_button.select(vsync_idx)
	
	
	brightness_slider.value = Global.brightness
	#pixel_smoothing_checkbox.button_pressed = Global.pixel_smoothing
	fps_limit_slider.value = Global.fps_limit
	
	# Audio
	master_volume_slider.value = Global.master_vol
	bgm_volume_slider.value = Global.bgm_vol
	sfx_volume_slider.value = Global.sfx_vol
	voice_volume_slider.value = Global.voice_vol # NEW: Voice volume
	
	_update_labels() # Update all labels after setting slider values
	
	

func _update_labels():
	# Graphics Labels
	brightness_value_label.text = str(snapped(brightness_slider.value, 0.01))
	fps_limit_value_label.text = str(int(fps_limit_slider.value)) + " FPS"

	# Audio Labels
	master_volume_value_label.text = str(snapped(master_volume_slider.value, 0.1)) + "dB"
	bgm_volume_value_label.text = str(snapped(bgm_volume_slider.value, 0.1)) + "dB"
	sfx_volume_value_label.text = str(snapped(sfx_volume_slider.value, 0.1)) + "dB"
	voice_volume_value_label.text = str(snapped(voice_volume_slider.value, 0.1)) + "dB" # NEW: Voice volume

# --- Signal Callbacks for Settings ---

func _on_fullscreen_checkbox_pressed():
	Global.fullscreen_on = fullscreen_checkbox.button_pressed
	Global.apply_graphics_settings()
	print("Options: Fullscreen set to: " + str(Global.fullscreen_on))

func _on_vsync_option_button_item_selected(index: int):
	Global.vsync_on = index  # Just use the index directly (0-3)
	Global.apply_graphics_settings()
	print("Options: VSync mode set to: " + str(Global.vsync_on))

func _on_resolution_option_button_item_selected(index: int):
	Global.resolution_index  = index  # Just use the index directly (0-3)
	Global.apply_graphics_settings()
	print("Options: VSync mode set to: " + str(index))
	
func _on_brightness_slider_value_changed(value: float):
	Global.brightness = value
	Global.apply_graphics_settings()
	_update_labels()
	print("Options: Brightness set to: " + str(value))

func _on_pixel_smoothing_checkbox_pressed():
	#Global.pixel_smoothing = pixel_smoothing_checkbox.button_pressed
	Global.apply_graphics_settings()
	print("Options: Pixel Smoothing set to: " + str(Global.pixel_smoothing))

func _on_fps_limit_slider_value_changed(value: float): # Slider value is float, convert to int for FPS
	Global.fps_limit = int(value)
	Global.apply_graphics_settings()
	_update_labels()
	print("Options: FPS Limit set to: " + str(Global.fps_limit))

func _on_master_volume_slider_value_changed(value: float):
	Global.master_vol = value
	Global.apply_audio_settings()
	_update_labels()
	print("Options: Master Volume set to: " + str(value) + "dB")

func _on_bgm_volume_slider_value_changed(value: float):
	Global.bgm_vol = value
	Global.apply_audio_settings()
	_update_labels()
	print("Options: BGM Volume set to: " + str(value) + "dB")

func _on_sfx_volume_slider_value_changed(value: float):
	Global.sfx_vol = value
	Global.apply_audio_settings()
	_update_labels()
	print("Options: SFX Volume set to: " + str(value) + "dB")

func _on_voice_volume_slider_value_changed(value: float): # NEW: Voice volume
	Global.voice_vol = value
	Global.apply_audio_settings()
	_update_labels()
	print("Options: Voice Volume set to: " + str(value) + "dB")

# --- Back Button Logic ---
func _on_back_button_pressed():
	print("OptionsMenu: Closing Options Menu pop-up.")
	
	var handled_return = false
	
	# Prioritize the explicitly set parent reference if available and valid
	if is_instance_valid(_parent_menu_reference):
		if _parent_menu_reference.has_method("show_pause_menu"):
			_parent_menu_reference.show_pause_menu()
			print("OptionsMenu: Returned to PauseMenu (via _parent_menu_reference).")
			handled_return = true
		elif _parent_menu_reference.has_method("_set_main_menu_buttons_enabled"):
			_parent_menu_reference._set_main_menu_buttons_enabled(true)
			print("OptionsMenu: Returned to MainMenu (via _parent_menu_reference).")
			handled_return = true
		else:
			printerr("OptionsMenu: _parent_menu_reference has no known method to re-enable itself. Reference name: " + _parent_menu_reference.name)
	
	# Fallback to get_parent() if _parent_menu_reference was not set or didn't handle it
	if not handled_return:
		var parent_candidate = get_parent() # This will be PauseMenu or Viewport (root)
		if is_instance_valid(parent_candidate):
			if parent_candidate.has_method("show_pause_menu"):
				parent_candidate.show_pause_menu()
				print("OptionsMenu: Returned to PauseMenu (via get_parent() fallback).")
				handled_return = true
			elif parent_candidate.has_method("_set_main_menu_buttons_enabled"):
				# This case would only happen if MainMenu is the direct parent (less common for OptionsMenu)
				parent_candidate._set_main_menu_buttons_enabled(true)
				print("OptionsMenu: Returned to MainMenu (via get_parent() fallback).")
				handled_return = true
			else:
				printerr("OptionsMenu: get_parent() candidate has no known method to re-enable itself. Candidate name: " + parent_candidate.name)
		else:
			printerr("OptionsMenu: No valid parent candidate found (get_parent() is invalid).")
	
	if not handled_return:
		printerr("OptionsMenu: Could not return to parent menu. No valid method found. _parent_menu_reference: " + str(_parent_menu_reference) + ", get_parent(): " + str(get_parent()))
		# Final fallback: If nothing else worked, just unpause if the game is paused
		if get_tree().paused:
			get_tree().paused = false
	
	queue_free()
	# --- END MODIFIED ---
func set_parent_menu_reference(node: Node):
	_parent_menu_reference = node
	if is_instance_valid(node):
		print("OptionsMenu: Parent menu reference set to: " + node.name)
	else:
		printerr("OptionsMenu: set_parent_menu_reference called with an invalid node!")
# --- END NEW ---
