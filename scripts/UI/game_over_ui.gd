extends CanvasLayer

@export var load_scene_path: String ="res://scenes/ui/load_game_menu.tscn"# !!! IMPORTANT: Set this in the Inspector (this is the path to the LoadGameMenu scene) !!!
@export var title_scene_path: String = "res://scenes/ui/MainMenu.tscn"# !!! IMPORTANT: Set this in the Inspector !!!


@export var load_game_menu_packed_scene: PackedScene = preload("res://scenes/ui/load_game_menu.tscn") # Make sure this path is correct!

@onready var retry_button = $Panel/VBoxContainer/HBoxContainer/RetryButton
@onready var back_to_title_button = $Panel/VBoxContainer/HBoxContainer/ExitButton

@onready var confirmation_dialog_back_to_title = $ConfirmationDialog # Reference to the dialog

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	retry_button.pressed.connect(_on_retry_button_pressed)
	back_to_title_button.pressed.connect(_on_exit_button_pressed)
	
	confirmation_dialog_back_to_title.confirmed.connect(_on_confirmation_dialog_back_to_title_confirmed)
	
	get_tree().paused = true

func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("menu"):
		print("GameOverUI: 'menu' action pressed. Current paused state: ", get_tree().paused)
		if confirmation_dialog_back_to_title.visible:
			confirmation_dialog_back_to_title.hide()
			if confirmation_dialog_back_to_title.canceled.is_connected(_on_confirmation_dialog_back_to_title_canceled):
				confirmation_dialog_back_to_title.canceled.disconnect(_on_confirmation_dialog_back_to_title_canceled)
			back_to_title_button.grab_focus()
		get_viewport().set_input_as_handled()

	
func _on_retry_button_pressed():
	print("GameOverUI: Retry button pressed! Opening Load Game Menu as a pop-up.")
	get_tree().paused = false # Unpause the game before opening the load menu
	Global.playerAlive = true # Reset player alive flag


	var load_menu_instance = load_game_menu_packed_scene.instantiate()
	

	get_tree().current_scene.add_child(load_menu_instance)
	

	print("GameOverUI: Load Game Menu pop-up instantiated and added.")



func _on_exit_button_pressed():
	print("GameOverUI: 'Back to Title' button pressed. Showing confirmation dialog...")
	if not confirmation_dialog_back_to_title.canceled.is_connected(_on_confirmation_dialog_back_to_title_canceled):
		confirmation_dialog_back_to_title.canceled.connect(_on_confirmation_dialog_back_to_title_canceled)
	confirmation_dialog_back_to_title.popup_centered()


func _on_confirmation_dialog_back_to_title_confirmed():
	print("GameOverUI: Player confirmed returning to title.")
	# Dialogic.clear() # Uncomment if needed
	Global.camouflage = false
	Global.time_freeze = false
	Global.playerAlive = true
	get_tree().paused = false
	print("GameOverUI: Game unpaused. Paused state now: ", get_tree().paused)

	get_tree().change_scene_to_file(title_scene_path)
	queue_free() # This queue_free() is correct when changing to MainMenu (a different root scene)
	print("GameOverUI: Scene change initiated to MainMenu, self-freed.")

func _on_confirmation_dialog_back_to_title_canceled():
	print("GameOverUI: Player canceled returning to title.")
	back_to_title_button.grab_focus()
	if confirmation_dialog_back_to_title.canceled.is_connected(_on_confirmation_dialog_back_to_title_canceled):
		confirmation_dialog_back_to_title.canceled.disconnect(_on_confirmation_dialog_back_to_title_canceled)


func _exit_tree():
	# This ensures the game is unpaused if GameOverUI is removed for any reason (e.g., scene change)
	get_tree().paused = false
