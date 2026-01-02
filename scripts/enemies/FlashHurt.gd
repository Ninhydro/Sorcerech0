extends Node
class_name FlashHurt

@export var flash_down_time := 0.1
@export var brightness_boost := 0.01
@export var root_path: NodePath   # where to collect sprites from

var _targets: Array[CanvasItem] = []
var _materials: Array[ShaderMaterial] = []
var _tween: Tween

func _ready() -> void:
	if root_path.is_empty():
		push_error("FlashHurt: root_path not set")
		return

	var root := get_node(root_path)
	if root == null:
		push_error("FlashHurt: invalid root_path")
		return

	_collect_canvas_items(root)
	_setup_materials()

func play(time_scale := 1.0) -> void:
	if _materials.is_empty():
		return

	if _tween and _tween.is_running():
		_tween.kill()

	for m in _materials:
		m.set_shader_parameter("flash_strength", 1.0)

	_tween = create_tween()
	_tween.tween_method(
		func(v):
			for m in _materials:
				m.set_shader_parameter("flash_strength", v),
		1.0, 0.0,
		flash_down_time / max(time_scale, 0.05)
	)

# ------------------------

func _setup_materials() -> void:
	var shader := load("res://shaders/flash_white.gdshader") as Shader
	if shader == null:
		push_error("FlashHurt: shader missing")
		return

	for ci in _targets:
		var original := ci.material

		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("brightness_boost", brightness_boost)
		mat.next_pass = original

		ci.use_parent_material = false
		ci.material = mat
		_materials.append(mat)

func _collect_canvas_items(node: Node) -> void:
	if node is CanvasItem:
		_targets.append(node)

	for c in node.get_children():
		_collect_canvas_items(c)
