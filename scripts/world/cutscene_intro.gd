extends Node2D  

@onready var black_overlay = $BlackOverlay
@onready var timer = $Timer

signal cutscene_finished


const INTRO_TIMELINE_PATH := "res://dialogic/timeline/timeline1.dtl"

func _ready():
	black_overlay.modulate.a = 1.0
	black_overlay.visible = false


func start_cutscene():
	print("CutsceneManager: Cutscene started. Setting overlay to semi-opaque.")
	black_overlay.visible = true
	black_overlay.modulate.a = 1.0

	# Clean old connections
	if Dialogic.timeline_ended.is_connected(_on_dialogic_finished):
		Dialogic.timeline_ended.disconnect(_on_dialogic_finished)
	Dialogic.timeline_ended.connect(_on_dialogic_finished)

	# 🔹 Load timeline resource directly by PATH (more reliable)
	var tl_res: Resource = load(INTRO_TIMELINE_PATH)
	if tl_res == null:
		push_error("CutsceneManager: Could not load Dialogic timeline at path: " + INTRO_TIMELINE_PATH)
		_on_cutscene_end()
		return

	# 🔹 Start Dialogic using the resource
	var layout = Dialogic.start(tl_res)
	print("CutsceneManager: Dialogic.start() layout: ", layout)

	# If layout is null, then Dialogic really failed to start
	if layout == null:
		push_error("CutsceneManager: Dialogic.start() returned null layout. Check Dialogic settings/layout.")
		_on_cutscene_end()
		return




func _on_dialogic_finished(_timeline_name = ""):
	print("CutsceneManager: Dialogic timeline finished. Initiating fade out.")
	#black_overlay.visible = false
	#black_overlay.modulate.a = 1.0
	LoadingScreen.show_and_load("")
	
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	#tween.tween_property(black_overlay, "modulate:a", 1.0, 0.1)
	tween.tween_callback(Callable(self, "_on_cutscene_end"))

	Dialogic.clear(Dialogic.ClearFlags.FULL_CLEAR)

	if Dialogic.timeline_ended.is_connected(_on_dialogic_finished):
		Dialogic.timeline_ended.disconnect(_on_dialogic_finished)

func _on_cutscene_end():
	print("CutsceneManager: Cutscene finished → starting loading transition")
	#LoadingScreen.show_and_load("")
	await get_tree().process_frame
	# 🔥 KEEP SCREEN BLACK
	await get_tree().create_timer(1.0).timeout
	black_overlay.visible = false
	black_overlay.modulate.a = 1.0
	
	# Force it to be on top of everything
	#black_overlay.z_index = 9999  # Add this line
	#black_overlay.mouse_filter = Control.MOUSE_FILTER_STOP  # Add this line
	
	#await get_tree().create_timer(5.0).timeout
	#await get_tree().process_frame
	#LoadingScreen.hide_after_ready()
	
	emit_signal("cutscene_finished")
	Global.timeline = 1
	
	
	
