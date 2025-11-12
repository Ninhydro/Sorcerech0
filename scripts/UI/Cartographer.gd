extends Node

#var revealed_chunks = {}
var master_map_texture: ImageTexture
var master_map_image: Image 

func _ready():
	# Create a blank master map (same size as your map texture)
	var map_size = Vector2(1280, 720)  # Your map size
	master_map_image = Image.create(map_size.x, map_size.y, false, Image.FORMAT_RGBA8)
	master_map_image.fill(Color.TRANSPARENT)
	master_map_texture = ImageTexture.create_from_image(master_map_image)

func reveal_chunk(chunk_name: String):
	Global.revealed_chunks[chunk_name] = true
	print("Revealed chunk: ", chunk_name)
	
	# Add this chunk to the master map
	add_chunk_to_master_map(chunk_name)

func is_chunk_discovered(chunk_name: String) -> bool:
	return Global.revealed_chunks.has(chunk_name)
	
func add_chunk_to_master_map(chunk_name: String):
	if chunk_name == "":  # Skip empty names
		return
		
	var chunk_texture = load("res://shaders/map_chunks/" + chunk_name + ".tres")
	if chunk_texture:
		# Get the chunk image
		var chunk_image = chunk_texture.get_image()
		
		# Define where this chunk goes on the master map
		var chunk_position = get_chunk_position(chunk_name)
		
		# Blend the chunk onto the master map
		master_map_image.blend_rect(chunk_image, Rect2(Vector2.ZERO, chunk_image.get_size()), chunk_position)
		
		# Update the texture
		master_map_texture.update(master_map_image)
		print("Added chunk to master map: ", chunk_name)
	else:
		print("ERROR: Could not load chunk: ", chunk_name)

func get_chunk_position(chunk_name: String) -> Vector2:
	# Define where each chunk is positioned on your master map
	match chunk_name:
		"Junkyard":
			return Vector2(319.242, 415.76)      # 
		"New Aerendale Town":
			return Vector2(478.611, 402.347)    
		"New Aerendale Capital":
			return Vector2(286.296, 326.44)    
		"Battlefield":
			return Vector2(427.695, 228.657)    
		"Ruins":
			return Vector2(568.935, 438.843)   
		"Ruins Temple":
			return Vector2(983.026, 483.336)   
		"Tromarvelia Town":
			return Vector2(141.674, 222.124)   
		"Tromarvelia Castle":
			return Vector2(28.125, 278.079)   
		"Tromarvelia Castle Throne":
			return Vector2(511.372, 522.227)   
		"Tromarvelia Dungeon Boss":
			return Vector2(37.058, 588.187)   
		"Exactlyion Town":
			return Vector2(840.974, 202.771)   
		"Exactlyion Tower Lower Level":
			return Vector2(880.109,141.254)   
		"Exactlyion Tower Upper Level":
			return Vector2(1038.08,87.754)   
		"Exactlyion Central Room":
			return Vector2(1075.929,155.736)   
		"Exactlyion Mainframe":
			return Vector2(932.771,56.713)   
		_:
			return Vector2.ZERO

func get_master_map_texture() -> ImageTexture:
	print("🔴 Cartographer: get_master_map_texture called")
	print("🔴 Revealed chunks: ", Global.revealed_chunks.size())
	print("🔴 Master texture valid: ", master_map_texture != null)
	
	# TEMPORARY FIX: If no texture exists, create a default one
	if master_map_texture == null:
		print("🔴 WARNING: No master texture! Creating fallback...")
		var map_size = Vector2(1280, 720)
		master_map_image = Image.create(map_size.x, map_size.y, false, Image.FORMAT_RGBA8)
		master_map_image.fill(Color(0.1, 0.1, 0.3))  # Dark blue background
		master_map_texture = ImageTexture.create_from_image(master_map_image)
	
	if master_map_texture:
		print("🔴 Master texture size: ", master_map_texture.get_size())
	return master_map_texture

func get_discovered_chunks() -> Array:
	return Global.revealed_chunks.keys()

func rebuild_master_map_from_save():
	# Clear the master map
	var map_size = Vector2(1280, 720)
	master_map_image = Image.create(map_size.x, map_size.y, false, Image.FORMAT_RGBA8)
	master_map_image.fill(Color.TRANSPARENT)
	master_map_texture = ImageTexture.create_from_image(master_map_image)
	
	# Add all discovered chunks back
	for chunk_name in Global.revealed_chunks:
		add_chunk_to_master_map(chunk_name)
	
	print("Cartographer: Rebuilt master map with ", Global.revealed_chunks.size(), " chunks")
	
