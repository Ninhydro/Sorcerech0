extends Node2D

const section_time := 2.0
const line_time := 0.4
const base_speed := 60
const speed_up_multiplier := 10.0
const title_color := Color.SKY_BLUE
const title_color0 := Color.WHITE
const title_color2 := Color.HOT_PINK

# var scroll_speed := base_speed
var speed_up := false

@onready var line := $CreditsContainer/Line
var started := false
var finished := false

var section
var section_next := true
var section_timer := 0.0
var line_timer := 0.0
var curr_line := 0
var lines := []

var credits = [
	[
		"-CREDITS-",
		"SORCERECH",
		"By Ninhydro Studio"
	],[
		"-Story & Programming-",
		"Nino Sanjaya",
	],[
		"-Pixel Art-",
		"Nino Sanjaya",
		"Tubajao"
	],[	
		"-Character Portrait Art-",
		"Queenevere"
		
	],[
		"-Illustration CG Art-",
		"Imperial Cat Circus",
		"Nur sandi",
		"Mommy Clara"

	],[
		"-BGM-",
		"Nanahime_music",
		"Rhyme costa",
		"Rhezaanj",
		"DOVA SYNDROME",
		"-Placeholder FREE LOYALTY"
	],[
		"-SFX-",
		"Pixabay",
		"-Placeholder FREE LOYALTY"
	],[
		"-UI & VFX-",
		"Nino Sanjaya"
	],[
		"-Trailer-",
		"-",
		"-Steam Asset Redraw-",
		"-"
	],[
		"Developed with Godot Engine 4.2",
		"https://godotengine.org/license"
	],[
		"Thank you for Playing!"

	]
]


func _process(delta):
	var scroll_speed = base_speed * delta
	
	if section_next:
		section_timer += delta * speed_up_multiplier if speed_up else delta
		if section_timer >= section_time:
			section_timer -= section_time
			
			if credits.size() > 0:
				started = true
				section = credits.pop_front()
				curr_line = 0
				add_line()
	
	else:
		line_timer += delta * speed_up_multiplier if speed_up else delta
		if line_timer >= line_time:
			line_timer -= line_time
			add_line()
	
	if speed_up:
		scroll_speed *= speed_up_multiplier
	
	if lines.size() > 0:
		for l in lines:
			l.position.y -= scroll_speed
			if l.position.y < -l.get_line_height():
				lines.erase(l)
				l.queue_free()
	elif started:
		finish()


func finish():
	if not finished:
		finished = true
		# This is called when the credits finish and returns to the main menu
		get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")

var one = false

func add_line():
	var new_line = line.duplicate()
	new_line.text = section.pop_front()
	lines.append(new_line)
	if curr_line == 0:
		#new_line.add_color_override("font_color", title_color0)
		new_line.set("theme_override_colors/font_color", title_color0)
		#if one == true:
			
			#new_line.set("theme_override_colors/font_color", title_color)
			#one = !one
		#elif one == false:
			#new_line.set("theme_override_colors/font_color", title_color2)
			#one = !one
	$CreditsContainer.add_child(new_line)
	
	if section.size() > 0:
		curr_line += 1
		section_next = false
	else:
		section_next = true


func _unhandled_input(event):
#	if event.is_action_pressed("ui_cancel"):
#		finish()
	if event.is_action_pressed("ui_down") and !event.is_echo():
		speed_up = true
	if event.is_action_released("ui_down") and !event.is_echo():
		speed_up = false
