# SpeechBubble.gd
extends Control

@onready var panel_background: Panel = $Panel
@onready var rich_text_label: RichTextLabel = $Panel/RichTextLabel
@onready var timer: Timer = $Timer

const CHAR_TIME = 0.05      # Time each character stays on screen (Increase for slower text)

# NEW: Constants for dynamic margin offsets
const MARGIN_OFFSET_FEW_WORDS = 20
const MARGIN_OFFSET_MANY_WORDS = 50
const CHARACTER_THRESHOLD_FOR_LARGE_MARGIN = 20 # If text is 20 chars or less, use small margin

const PANEL_SPEED_MULTIPLIER = 0.2 # Adjust if you want panel faster/slower than text
const Y_OFFSET_POPUP = 20   # How many pixels the bubble will pop up vertically

# CRITICAL FIX: Adjusted MAX_TEXT_DISPLAY_WIDTH to a practical value.
# This is the maximum width your text content will try to occupy before wrapping.
const MAX_TEXT_DISPLAY_WIDTH = 400.0 # <--- THIS IS THE MOST IMPORTANT CHANGE!

var current_wait_time: float = 0.0
var current_tween: Tween = null

func _ready():
	visible = false
	if timer:
		timer.timeout.connect(_on_Timer_timeout)
	else:
		push_error("Timer node not found! Please add a Timer node as a child of SpeechBubble.")

	# Test with various lengths of text:
	#set_text("Short. gw  owicnefowf uwyenxfowy nexfwiy xefoinw weoef w8xbeo ofye ", 5.0) # Should have 20 margin
	# set_text("Hello there! This bubble has more space and will pop up! Test with a medium-length sentence.", 3.0) # Should have 50 margin
	# set_text("This is a very long sentence that should definitely wrap within the maximum width, allowing the panel to adjust its height accordingly and avoid text spilling out.", 3.0) # Should have 50 margin


func set_text(text_content: String, wait_time: float = 3.0):
	visible = true
	current_wait_time = wait_time

	if current_tween and current_tween.is_valid():
		current_tween.kill()
	timer.stop()

	# Set the full text content first
	rich_text_label.bbcode_text = text_content
	rich_text_label.visible_characters = 0

	# --- Determine the current margin offset based on text length ---
	var clean_text_length = rich_text_label.text.length() # Use this for threshold check
	var current_margin_offset: float
	if clean_text_length <= CHARACTER_THRESHOLD_FOR_LARGE_MARGIN:
		current_margin_offset = MARGIN_OFFSET_FEW_WORDS
	else:
		current_margin_offset = MARGIN_OFFSET_MANY_WORDS

	# --- Apply the dynamic margin offset to RichTextLabel's layout ---
	# This ensures the RichTextLabel's padding is correct before calculating its size.
	rich_text_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT) # Sets anchors to stretch
	rich_text_label.set_offset(SIDE_LEFT, current_margin_offset)
	rich_text_label.set_offset(SIDE_TOP, current_margin_offset)
	rich_text_label.set_offset(SIDE_RIGHT, -current_margin_offset) # Negative for right/bottom offsets
	rich_text_label.set_offset(SIDE_BOTTOM, -current_margin_offset)

	# --- CRITICAL FOR DYNAMIC SIZING ---
	# Temporarily set RichTextLabel's width to MAX_TEXT_DISPLAY_WIDTH.
	# With Autowrap Mode 'Word', this tells it to calculate its content height
	# if forced to this width.
	rich_text_label.size.x = MAX_TEXT_DISPLAY_WIDTH
	# If Autowrap Mode is 'Off', you'd set size.x = 99999 here instead to get full single-line width.

	# Yield for one physics frame to allow RichTextLabel to calculate its content size
	await get_tree().physics_frame

	# Now get the actual size the RichTextLabel content takes after layout.
	# If Autowrap Mode is 'Word', required_text_width will be <= MAX_TEXT_DISPLAY_WIDTH.
	var required_text_width = rich_text_label.get_content_width()
	var required_text_height = rich_text_label.get_content_height()

	# Debugging prints - uncomment these to see the calculated values!
	# print("Text Content: ", text_content)
	# print("Clean Text Length: ", clean_text_length)
	# print("Current Margin Offset: ", current_margin_offset)
	# print("RichTextLabel Calculated Size (pre-panel adjust): ", required_text_width, required_text_height)


	# Calculate animation durations
	var text_animation_duration = float(clean_text_length) * CHAR_TIME
	var panel_animation_duration = text_animation_duration * PANEL_SPEED_MULTIPLIER

	# Calculate target size for the Panel using the current_margin_offset.
	var min_panel_width = 100.0 # Base minimum width
	var min_panel_height = 50.0 # Base minimum height

	# Target width for the panel: required text width + 2x margin (left and right)
	# We cap the target width to prevent it from becoming excessively wide
	var target_width = max(min_panel_width, required_text_width + (current_margin_offset * 4))
	target_width = min(target_width, MAX_TEXT_DISPLAY_WIDTH + (current_margin_offset * 4))

	# Target height for the panel: required text height + 2x margin (top and bottom)
	var target_height = max(min_panel_height, required_text_height + (current_margin_offset * 2))

	var target_size = Vector2(target_width, target_height)

	# Debugging prints - uncomment these to see the final panel target size!
	# print("Target Panel Size: ", target_size)

	# --- Final recalculation for RichTextLabel (important for wrapping) ---
	# After the panel's target_size is determined, the RichTextLabel's size.x needs
	# to reflect the *final* width it will have inside the panel. This ensures
	# correct height calculation if text wraps.
	rich_text_label.size.x = target_width - (current_margin_offset * 4)
	rich_text_label.size.y = target_height - (current_margin_offset * 2) # Ensure Y also matches final bounds

	# Another await to allow the RichTextLabel to finish its layout based on final size
	# and ensures it's ready before the tweens start.
	await get_tree().physics_frame

	# --- Calculate new position for the "pop-up" effect ---
	var initial_panel_position = panel_background.position
	var target_panel_position = initial_panel_position - Vector2(0, Y_OFFSET_POPUP)


	# --- Create and configure the new Tween ---
	current_tween = create_tween()
	current_tween.finished.connect(_on_Tween_finished)

	# =========================================================================
	# All tweens within this block will run in parallel.
	# =========================================================================

	# Animate the typewriter effect using 'visible_characters'
	current_tween.parallel().tween_property(
		rich_text_label,
		"visible_characters",
		clean_text_length,
		text_animation_duration
	).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)

	# Animate the background SIZE. RichTextLabel will automatically resize with it due to layout!
	var initial_panel_size = panel_background.size
	if initial_panel_size.x == 0.0:
		initial_panel_size.x = 1.0

	current_tween.parallel().tween_property(
		panel_background,
		"size",
		target_size,
		panel_animation_duration
	).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)

	# Animate the background POSITION to create a pop-up effect
	current_tween.parallel().tween_property(
		panel_background,
		"position",
		target_panel_position,
		panel_animation_duration
	).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)

	current_tween.play()


func _on_Tween_finished():
	timer.start()

func _on_Timer_timeout():
	visible = false

# Example of how to use this script from another script (e.g., your Player script)
# func _on_Player_interacted_with_NPC():
#     $Path/To/SpeechBubbleNode.set_text("Hello there! How are you?", 5.0)
