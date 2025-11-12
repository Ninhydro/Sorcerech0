# GlobalSky.gd - Fixed version
extends ParallaxBackground

@onready var sky_layers = {
	"Aerendale": $Aerendale_sky,
	"Aerendalev2": $Aerendale_sky2,
	"Ruins": $Aerendale_ruins,
	"Tromarvelia": $Tromarvelia_sky,
	"Tromarveliav2": $Tromarvelia_sky2,
	"Dungeon": $Tromarvelia_dungeon,
	"Exactlyion": $Exactlyion_sky,
	"Exactlyionv2": $Exactlyion_sky2,
	"Tower": $Exactlyion_tower,
	"Restart": $Restart
}

# Local parallax zones - add these as children in your scene
@onready var local_zones = {}

var current_sky_theme: String = "Aerendale"
var active_local_zones: Array = []
var debug_timer: int = 0

func _ready():
	print("🌍 GlobalSky: _ready() called")
	await get_tree().process_frame
	print("🌍 GlobalSky: Player registered: ", Global.player != null)
	
	# Center all sprites at camera height
	center_all_sprites()
	update_sky_theme()
	
	# Initialize local zones
	initialize_local_zones()
	for zone_name in local_zones:
		var zone = local_zones[zone_name]
		if zone and zone is ParallaxBackground:
			# ParallaxBackground doesn't have z_index, set it on layers instead
			for layer in zone.get_children():
				if layer is ParallaxLayer:
					layer.z_index = 100  # High number to render on top
					for sprite in layer.get_children():
						if sprite is Sprite2D:
							sprite.z_index = 100

func initialize_local_zones():
	print("🌍 Initializing local parallax zones...")
	
	# Hide all local zones by default by hiding their sprites
	for zone_name in local_zones:
		var zone = local_zones[zone_name]
		if zone and zone is ParallaxBackground:
			# Hide all sprites in this zone
			for layer in zone.get_children():
				if layer is ParallaxLayer:
					for sprite in layer.get_children():
						if sprite is Sprite2D:
							sprite.modulate.a = 0.0
							print("🌍 Set alpha to 0 for sprite: ", sprite.name, " in zone: ", zone_name)
			#print("🌍 Hidden local zone: ", zone_name)

func center_all_sprites():
	for theme_name in sky_layers:
		var layer = sky_layers[theme_name]
		if layer is ParallaxLayer:
			for child in layer.get_children():
				if child is Sprite2D:
					child.position = Vector2(0, 0)

func _process(delta):
	# Follow camera for global sky
	var camera = Global.get_player_camera()
	if camera:
		scroll_offset = camera.global_position
	
	# Check for area changes
	var current_area = Global.get_current_area()
	var target_theme = get_sky_theme_for_area(current_area)
	
	if target_theme != current_sky_theme:
		set_sky_theme(target_theme)
	
	# Update local zones
	update_local_zones(delta)
	
	# DEBUG: Print zone status occasionally
	#debug_timer += 1
	#if debug_timer % 300 == 0:  # Print every 5 seconds or so
	#	debug_zone_status()

func debug_zone_status():
	print("=== ZONE STATUS DEBUG ===")
	print("Current area: ", Global.get_current_area())
	print("Zones for area: ", get_local_zones_for_area(Global.get_current_area()))
	
	for zone_name in local_zones:
		var zone = local_zones[zone_name]
		if zone and zone is ParallaxBackground:
			var is_visible = false
			for layer in zone.get_children():
				if layer is ParallaxLayer:
					for sprite in layer.get_children():
						if sprite is Sprite2D:
							is_visible = is_visible or (sprite.modulate.a > 0.1)
			print("Zone '", zone_name, "': visible=", is_visible, " alpha=", get_zone_alpha(zone))
	print("========================")

func get_zone_alpha(zone: ParallaxBackground) -> float:
	for layer in zone.get_children():
		if layer is ParallaxLayer:
			for sprite in layer.get_children():
				if sprite is Sprite2D:
					return sprite.modulate.a
	return 0.0

func update_local_zones(delta):
	var player = Global.get_player()
	if not player:
		return
	
	# Define which local zones should be active in current area
	var zones_for_area = get_local_zones_for_area(Global.get_current_area())
	
	# Fade in/out zones based on area
	for zone_name in local_zones:
		var zone = local_zones[zone_name]
		if zone and zone is ParallaxBackground:
			var should_be_active = zone_name in zones_for_area
			update_zone_visibility(zone, should_be_active, delta)
			
			# Update parallax for active zones
			if is_zone_visible(zone):
				update_zone_parallax(zone)

func get_local_zones_for_area(area: String) -> Array:
	match area:
		"Junkyard":
			#print("🌍 Area 'Junkyard' should activate zone: junkyard")
			return ["junkyard"]
		"New Aerendale Town":
			#print("🌍 Area 'New Aerendale Town' - no local zones")
			return []
		_:
			#print("🌍 Area '", area, "' - no local zones")
			return []

func update_zone_visibility(zone: ParallaxBackground, should_be_active: bool, delta: float):
	var target_alpha = 1.0 if should_be_active else 0.0
	
	# Update alpha for all sprites in this zone
	for layer in zone.get_children():
		if layer is ParallaxLayer:
			for sprite in layer.get_children():
				if sprite is Sprite2D:
					var current_alpha = sprite.modulate.a
					var new_alpha = lerp(current_alpha, target_alpha, 5.0 * delta)
					sprite.modulate.a = new_alpha
					
					# Debug when alpha changes significantly
					if abs(current_alpha - new_alpha) > 0.3:
						print("🌍 Zone alpha changing: ", current_alpha, " -> ", new_alpha, " (target: ", target_alpha, ")")

func is_zone_visible(zone: ParallaxBackground) -> bool:
	# Check if any sprite in the zone is visible
	for layer in zone.get_children():
		if layer is ParallaxLayer:
			for sprite in layer.get_children():
				if sprite is Sprite2D and sprite.modulate.a > 0.1:
					return true
	return false

func update_zone_parallax(zone: ParallaxBackground):
	var camera = Global.get_player_camera()
	if camera:
		# Different parallax scales for different zone types
		var parallax_scale = get_zone_parallax_scale(zone.name)
		zone.scroll_offset = camera.global_position * parallax_scale

func get_zone_parallax_scale(zone_name: String) -> Vector2:
	match zone_name:
		"junkyard":
			return Vector2(0.3, 0.2)  # Medium movement
		_:
			return Vector2(0.2, 0.1)

# === YOUR EXISTING CODE ===

func check_sprite_visibility():
	var camera = Global.get_player_camera()
	if camera:
		print("🌍 Camera viewport size: ", camera.get_viewport().get_visible_rect().size)
	
	var current_layer = sky_layers[current_sky_theme]
	if current_layer is ParallaxLayer:
		for child in current_layer.get_children():
			if child is Sprite2D:
				print("🌍 Sprite '", child.name, "' visibility check:")
				print("   - Is visible in tree: ", child.is_visible_in_tree())
				print("   - Modulate: ", child.modulate)
				if child.texture:
					print("   - Texture loaded: YES")

func get_sky_theme_for_area(area: String) -> String:
	match area:
		"Junkyard": return "Aerendale"
		"Home": return "Aerendale"
		"New Aerendale Town": return "Aerendale"
		"New Aerendale Capital": return "Aerendale"
		"New Aerendale Capital Throne": return "Aerendale"
		"Battlefield": return "Aerendale"
		"Ruins": return "Ruins"
		"Ruins Temple": return "Ruins"
		"Forest": return "Tromarvelia"
		"Nora House": return "Tromarvelia"
		"Tromarvelia Town": return "Tromarvelia"
		"Tromarvelia Castle": return "Tromarvelia"
		"Tromarvelia Castle Throne": return "Tromarvelia"
		"Tromarvelia Dungeon": return "Dungeon"
		"Tromarvelia Dungeon Boss": return "Dungeon"
		"Factory": return "Exactlyion"
		"Valentina Laboratory": return "Exactlyion"
		"Exactlyion Town": return "Exactlyion"
		"Exactlyion Tower Lower Level": return "Exactlyion"
		"Exactlyion Central Room": return "Exactlyion"
		"Exactlyion Tower Upper Level": return "Tower"
		"Exactlyion Mainframe": return "Tower"
		"Unknown": return "Restart"
		_: return "Aerendale"

func set_sky_theme(theme: String):
	# Hide all skies
	for theme_name in sky_layers:
		var layer = sky_layers[theme_name]
		layer.visible = false
	
	# Show current sky
	if sky_layers.has(theme):
		sky_layers[theme].visible = true
		current_sky_theme = theme
		print("GlobalSky: Changed to ", theme, " theme")

func update_sky_theme():
	var current_area = Global.get_current_area()
	var target_theme = get_sky_theme_for_area(current_area)
	set_sky_theme(target_theme)

# === TEST FUNCTION ===
# Call this manually to test if your zone works
func test_junkyard_zone():
	print("🧪 TEST: Manually activating junkyard zone")
	activate_specific_zone("junkyard")

func activate_specific_zone(zone_name: String):
	if local_zones.has(zone_name) and local_zones[zone_name]:
		var zone = local_zones[zone_name]
		# Set all sprites in zone to visible
		for layer in zone.get_children():
			if layer is ParallaxLayer:
				for sprite in layer.get_children():
					if sprite is Sprite2D:
						sprite.modulate.a = 1.0
						print("🧪 Set sprite ", sprite.name, " alpha to 1.0")
		print("🌍 Activated zone: ", zone_name)

func deactivate_specific_zone(zone_name: String):
	if local_zones.has(zone_name) and local_zones[zone_name]:
		var zone = local_zones[zone_name]
		# Set all sprites in zone to invisible
		for layer in zone.get_children():
			if layer is ParallaxLayer:
				for sprite in layer.get_children():
					if sprite is Sprite2D:
						sprite.modulate.a = 0.0
		print("🌍 Deactivated zone: ", zone_name)

func debug_sprite_positions():
	#print("=== SPRITE POSITION DEBUG ===")
	var camera = Global.get_player_camera()
	if camera:
		print("Camera position: ", camera.global_position)
		print("Camera viewport size: ", get_viewport().get_visible_rect().size)
	
	for zone_name in local_zones:
		var zone = local_zones[zone_name]
		if zone and zone is ParallaxBackground:
			for layer in zone.get_children():
				if layer is ParallaxLayer:
					for sprite in layer.get_children():
						if sprite is Sprite2D:
							print("Sprite '", sprite.name, "' position: ", sprite.position)
							print("Sprite global position: ", sprite.global_position)
							print("Sprite texture size: ", sprite.texture.get_size() if sprite.texture else "No texture")
	#print("=============================")
	
func test_visibility():
	#print("🧪 RUNNING VISIBILITY TEST")
	for zone_name in local_zones:
		var zone = local_zones[zone_name]
		if zone and zone is ParallaxBackground:
			for layer in zone.get_children():
				if layer is ParallaxLayer:
					for sprite in layer.get_children():
						if sprite is Sprite2D:
							# Force bright red color to test visibility
							sprite.modulate = Color(1, 0, 0, 1)  # Bright red
							sprite.position = Vector2.ZERO  # Center on camera
							#print("🧪 Set sprite ", sprite.name, " to BRIGHT RED at position (0, 0)")
